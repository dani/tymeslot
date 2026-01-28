defmodule Tymeslot.Payments.Webhooks.DisputeHandler do
  @moduledoc """
  Handles Stripe dispute (chargeback) webhook events.

  This handler tracks payment disputes and alerts administrators.
  Per user configuration: logs and alerts only - does NOT automatically suspend access.

  Events handled:
  - charge.dispute.created: Customer filed a dispute/chargeback
  - charge.dispute.updated: Dispute status changed
  - charge.dispute.closed: Dispute resolved (won or lost)
  """

  @behaviour Tymeslot.Payments.Behaviours.WebhookHandler

  require Logger

  alias Tymeslot.Mailer

  @impl true
  def can_handle?(event_type)
      when event_type in [
             "charge.dispute.created",
             "charge.dispute.updated",
             "charge.dispute.closed"
           ] do
    true
  end

  def can_handle?(_), do: false

  @impl true
  def process(%{"type" => "charge.dispute.created"} = event, dispute) do
    handle_created(event, dispute)
  end

  def process(%{"type" => "charge.dispute.updated"} = event, dispute) do
    handle_updated(event, dispute)
  end

  def process(%{"type" => "charge.dispute.closed"} = event, dispute) do
    handle_closed(event, dispute)
  end

  @impl true
  def validate(%{"type" => type, "data" => %{"object" => object}})
      when type in ["charge.dispute.created", "charge.dispute.updated", "charge.dispute.closed"] do
    required_fields = ["id", "charge", "amount", "status"]

    case Enum.all?(required_fields, &Map.has_key?(object, &1)) do
      true -> :ok
      false -> {:error, :missing_fields, "Missing required fields in #{type} event"}
    end
  end

  def validate(_event), do: {:error, :invalid_structure, "Invalid event structure"}

  # Private functions

  defp handle_created(_event, dispute) do
    dispute_id = dispute["id"]
    charge_id = dispute["charge"]
    amount = dispute["amount"]
    reason = dispute["reason"]
    status = dispute["status"]

    Logger.warning("DISPUTE CREATED - Chargeback filed",
      dispute_id: dispute_id,
      charge_id: charge_id,
      amount: amount,
      reason: reason,
      status: status
    )

    # Find user by charge ID
    case find_user_by_charge(charge_id) do
      {:error, :stripe_api_error} ->
        # If Stripe is down, we should fail so the webhook can be retried
        {:error, :retry_later, "Stripe API unavailable"}

      nil ->
        Logger.warning("DISPUTE UNLINKED - Could not find user for dispute on charge: #{charge_id}",
          dispute_id: dispute_id,
          charge_id: charge_id
        )

        # Alert admin about unlinked dispute
        alert_admin_dispute_created(dispute_id, nil, amount, reason)

        {:ok, :dispute_logged}

      user_id ->
        # Create dispute record in database
        case create_dispute_record(dispute, user_id) do
          {:ok, result} when result in [:skipped, :ok] or is_map(result) ->
            Logger.info("DISPUTE RECORDED - Created dispute record for user #{user_id}",
              user_id: user_id,
              dispute_id: dispute_id,
              charge_id: charge_id
            )

            # Alert admin (log and potentially other notifications)
            alert_admin_dispute_created(dispute_id, user_id, amount, reason)

            # Send email to admin
            send_dispute_created_alert(dispute)

            # Broadcast event
            broadcast_dispute_event(user_id, :dispute_created, dispute_id)

            {:ok, :dispute_created}

          {:error, %Ecto.Changeset{errors: [stripe_dispute_id: {_, [constraint: :unique, constraint_name: _]}]}} ->
            Logger.error("DISPUTE ERROR - Failed to create dispute record: #{inspect(reason)}",
              user_id: user_id,
              dispute_id: dispute_id,
              error: reason
            )

            # Do NOT alert admin here to avoid duplicates on retry
            # The error return will trigger a retry
            {:error, reason}
        end
    end
  end

  defp handle_updated(_event, dispute) do
    dispute_id = dispute["id"]
    status = dispute["status"]

    Logger.info("Dispute #{dispute_id} status updated to: #{status}")

    # Update dispute record
    case update_dispute_status_in_db(dispute_id, status) do
      {:ok, result} when result in [:skipped, :ok] or is_map(result) ->
        Logger.info("Updated dispute #{dispute_id} status to #{status}")
        {:ok, :dispute_updated}

      {:error, :not_found} ->
        Logger.warning("Dispute #{dispute_id} not found in database")
        {:ok, :dispute_not_tracked}

      {:error, reason} ->
        Logger.error("Failed to update dispute: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp handle_closed(_event, dispute) do
    dispute_id = dispute["id"]
    status = dispute["status"]

    Logger.info("DISPUTE CLOSED - Dispute #{dispute_id} closed with status: #{status}",
      dispute_id: dispute_id,
      status: status
    )

    # Update dispute record
    case update_dispute_status_in_db(dispute_id, status) do
      {:ok, result} when result in [:skipped, :ok] or is_map(result) ->
        handle_dispute_outcome(status, dispute_id, result)

      {:error, :already_in_state} ->
        Logger.warning("DISPUTE NOT FOUND - Dispute #{dispute_id} not found in database",
          dispute_id: dispute_id,
          status: status
        )

        {:ok, :dispute_not_tracked}

      {:error, reason} ->
        Logger.error("DISPUTE UPDATE ERROR - Failed to update dispute: #{inspect(reason)}",
          dispute_id: dispute_id,
          error: reason
        )

        {:error, reason}
    end
  end

  defp handle_dispute_outcome("lost", dispute_id, result) do
    user_id = (is_map(result) && Map.get(result, :user_id)) || "unknown"
    amount = (is_map(result) && Map.get(result, :amount)) || "unknown"

    # Dispute lost - funds returned to customer
    Logger.warning("DISPUTE LOST - Funds returned to customer",
      dispute_id: dispute_id,
      user_id: user_id,
      amount: amount
    )

    # Alert admin (manual review required per user request)
    alert_admin_dispute_lost(dispute_id, (is_map(result) && Map.get(result, :user_id)))

    # Send admin alert email
    if is_map(result), do: send_dispute_lost_alert(result)

    {:ok, :dispute_lost}
  end

  defp handle_dispute_outcome("won", dispute_id, result) do
    user_id = (is_map(result) && Map.get(result, :user_id)) || "unknown"
    amount = (is_map(result) && Map.get(result, :amount)) || "unknown"

    # Dispute won - funds kept
    Logger.info("DISPUTE WON - Funds retained",
      dispute_id: dispute_id,
      user_id: user_id,
      amount: amount
    )

    # Send admin notification email
    if is_map(result), do: send_dispute_won_notification(result)

    {:ok, :dispute_won}
  end

  defp handle_dispute_outcome(_status, _dispute_id, _result) do
    {:ok, :dispute_closed}
  end

  defp find_user_by_charge(charge_id) do
    # Look up user by charge ID through subscription
    # This requires finding the subscription by customer ID from the charge
    # For now, we'll need to expand the Stripe charge to get customer ID
    case stripe_provider().get_charge(charge_id) do
      {:ok, charge} ->
        customer_id = Map.get(charge, "customer") || Map.get(charge, :customer)
        subscription_schema = Application.get_env(:tymeslot, :subscription_schema)

        if subscription_schema && Code.ensure_loaded?(subscription_schema) do
          repo = Application.get_env(:tymeslot, :repo, Tymeslot.Repo)

          case repo.get_by(subscription_schema,
                 stripe_customer_id: customer_id
               ) do
            nil -> nil
            subscription -> subscription.user_id
          end
        else
          nil
        end

      {:error, reason} ->
        Logger.error("DISPUTE LINK ERROR - Failed to fetch charge from Stripe: #{inspect(reason)}",
          charge_id: charge_id
        )

        # Return a special error tuple to allow the caller to decide on retries
        {:error, :stripe_api_error}
    end
  end

  defp create_dispute_record(dispute, user_id) do
    evidence_due_by =
      case get_in(dispute, ["evidence_details", "due_by"]) do
        ts when is_integer(ts) ->
          case DateTime.from_unix(ts) do
            {:ok, datetime} -> datetime
            {:error, _} -> nil
          end

        _ ->
          nil
      end

    attrs = %{
      stripe_dispute_id: dispute["id"],
      user_id: user_id,
      charge_id: dispute["charge"],
      amount: dispute["amount"],
      currency: dispute["currency"],
      reason: dispute["reason"],
      status: dispute["status"],
      evidence_due_by: evidence_due_by,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    manager = saas_subscription_manager()

    if manager && Code.ensure_loaded?(manager) do
      manager.record_dispute(attrs)
    else
      {:ok, :skipped}
    end
  end

  defp update_dispute_status_in_db(stripe_dispute_id, status) do
    manager = saas_subscription_manager()

    if manager && Code.ensure_loaded?(manager) do
      manager.update_dispute_status(stripe_dispute_id, status)
    else
      {:ok, :skipped}
    end
  end

  defp alert_admin_dispute_created(dispute_id, user_id, amount, reason) do
    Tymeslot.Infrastructure.AdminAlerts.send_alert(:dispute_created, %{
      dispute_id: dispute_id,
      user_id: user_id,
      amount: amount,
      reason: reason
    })
  end

  defp alert_admin_dispute_lost(dispute_id, user_id) do
    Tymeslot.Infrastructure.AdminAlerts.send_alert(:dispute_lost, %{
      dispute_id: dispute_id,
      user_id: user_id
    })
  end

  defp broadcast_dispute_event(user_id, event_type, dispute_id) do
    Phoenix.PubSub.broadcast(
      Tymeslot.PubSub,
      "user:#{user_id}",
      {event_type, %{dispute_id: dispute_id}}
    )
  end

  defp send_dispute_created_alert(dispute_data) do
    deliver_dispute_email(:dispute_created_alert, dispute_data)
  end

  defp send_dispute_lost_alert(dispute_record) do
    deliver_dispute_email(:dispute_lost_alert, dispute_record)
  end

  defp send_dispute_won_notification(dispute_record) do
    deliver_dispute_email(:dispute_won_notification, dispute_record)
  end

  defp deliver_dispute_email(template_fun, data) do
    admin_email = get_admin_email()

    case admin_email do
      nil ->
        Logger.warning("No admin email configured for dispute alerts")
        :ok

      email ->
        template = Application.get_env(:tymeslot, :dispute_alert_template)

        if template && Code.ensure_loaded?(template) do
          email_struct = apply(template, template_fun, [email, data])

          case Mailer.deliver(email_struct) do
            {:ok, _} ->
              Logger.info("Dispute email (#{template_fun}) sent to #{email}")
              :ok

            {:error, reason} ->
              Logger.error("Failed to send dispute email (#{template_fun}): #{inspect(reason)}")
              :ok
          end
        else
          Logger.debug("Dispute alert template not configured (Standalone mode)")
          :ok
        end
    end
  end

  defp get_admin_email do
    # Get admin email from configuration
    # Default to support@tymeslot.app if not configured
    Application.get_env(:tymeslot, :admin_email) || "support@tymeslot.app"
  end

  defp saas_subscription_manager do
    Application.get_env(:tymeslot, :saas_subscription_manager)
  end

  defp stripe_provider do
    Application.get_env(:tymeslot, :stripe_provider, Tymeslot.Payments.Stripe)
  end
end
