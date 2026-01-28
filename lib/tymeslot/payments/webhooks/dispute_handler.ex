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

  alias Tymeslot.Infrastructure.AdminAlerts
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

  defp handle_created(event, dispute) do
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
        # Broadcast event for SaaS to record dispute
        Tymeslot.Payments.PubSub.broadcast_payment_event(:dispute_created, %{
          event_id: event["id"],
          user_id: user_id,
          dispute: dispute
        })

        Logger.info("DISPUTE BROADCASTED - Sent dispute_created event for user #{user_id}",
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
    end
  end

  defp handle_updated(event, dispute) do
    dispute_id = dispute["id"]
    status = dispute["status"]

    Logger.info("Dispute #{dispute_id} status updated to: #{status}")

    # Broadcast event for SaaS to update dispute status
    Tymeslot.Payments.PubSub.broadcast_payment_event(:dispute_updated, %{
      event_id: event["id"],
      stripe_dispute_id: dispute_id,
      status: status
    })

    {:ok, :dispute_updated}
  end

  defp handle_closed(event, dispute) do
    dispute_id = dispute["id"]
    status = dispute["status"]

    Logger.info("DISPUTE CLOSED - Dispute #{dispute_id} closed with status: #{status}",
      dispute_id: dispute_id,
      status: status
    )

    # Broadcast event for SaaS to update dispute status and handle outcome
    Tymeslot.Payments.PubSub.broadcast_payment_event(:dispute_closed, %{
      event_id: event["id"],
      stripe_dispute_id: dispute_id,
      status: status,
      dispute: dispute
    })

    # We still alert admin in Core for visibility
    if status == "lost" do
      alert_admin_dispute_lost(dispute_id, nil)
      send_dispute_lost_alert(dispute)
    end

    if status == "won" do
      send_dispute_won_notification(dispute)
    end

    {:ok, :dispute_closed}
  end

  defp alert_admin_dispute_lost(dispute_id, user_id) do
    AdminAlerts.send_alert(:dispute_lost, %{
      dispute_id: dispute_id,
      user_id: user_id
    })
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

  defp alert_admin_dispute_created(dispute_id, user_id, amount, reason) do
    AdminAlerts.send_alert(:dispute_created, %{
      dispute_id: dispute_id,
      user_id: user_id,
      amount: amount,
      reason: reason
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

  defp stripe_provider do
    Application.get_env(:tymeslot, :stripe_provider, Tymeslot.Payments.Stripe)
  end
end
