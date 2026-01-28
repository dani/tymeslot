defmodule Tymeslot.Payments.Webhooks.RefundHandler do
  @moduledoc """
  Handles Stripe refund webhook events.

  CRITICAL: This handler protects revenue by revoking Pro access when refunds are issued.
  Without this handler, users could receive refunds while keeping Pro access indefinitely.

  Events handled:
  - charge.refunded: Refund has been issued
  - charge.refund.updated: Refund status changed
  """

  @behaviour Tymeslot.Payments.Behaviours.WebhookHandler

  require Logger

  alias Tymeslot.Infrastructure.AdminAlerts
  alias Tymeslot.Payments.Webhooks.WebhookUtils

  @impl true
  def can_handle?(event_type) when event_type in ["charge.refunded", "charge.refund.updated"] do
    true
  end

  def can_handle?(_), do: false

  @impl true
  def process(%{"type" => "charge.refunded"} = event, charge) do
    handle_refunded(event, charge)
  end

  def process(%{"type" => "charge.refund.updated"} = event, refund) do
    handle_refund_updated(event, refund)
  end

  @impl true
  def validate(%{"type" => type, "data" => %{"object" => object}})
      when type in ["charge.refunded", "charge.refund.updated"] do
    required_fields = ["id"]

    case Enum.all?(required_fields, &Map.has_key?(object, &1)) do
      true -> :ok
      false -> {:error, :missing_fields, "Missing required fields in #{type} event"}
    end
  end

  def validate(_event), do: {:error, :invalid_structure, "Invalid event structure"}

  # Private functions

  defp handle_refunded(event, charge) do
    charge_id = charge["id"]
    refund_amount = get_refund_amount(charge)
    customer_id = charge["customer"]

    Logger.info("REFUND RECEIVED - Processing refund for charge: #{charge_id}, amount: #{refund_amount}",
      charge_id: charge_id,
      customer_id: customer_id,
      amount: refund_amount,
      stripe_event_id: event["id"]
    )

    # Broadcast event for SaaS to handle subscription revocation
    Tymeslot.Payments.PubSub.broadcast_payment_event(:charge_refunded, %{
      event_id: event["id"],
      charge_id: charge_id,
      customer_id: customer_id,
      refund_amount: refund_amount
    })

    # Find the subscription by Stripe customer ID for local notifications
    case find_subscription_by_customer(customer_id) do
      nil ->
        Logger.warning("REFUND UNLINKED - No subscription found for customer #{customer_id}",
          charge_id: charge_id,
          customer_id: customer_id
        )

        # Alert admin about unlinked refund
        AdminAlerts.send_alert(:unlinked_refund, %{
          charge_id: charge_id,
          customer_id: customer_id,
          amount: refund_amount
        })

        {:ok, :refund_logged}

      subscription ->
        with :ok <- ensure_revoked_access(subscription, charge_id, customer_id) do
          # Alert admin about processed refund
          AdminAlerts.send_alert(
            :refund_processed,
            %{
              user_id: subscription.user_id,
              charge_id: charge_id,
              amount: refund_amount
            },
            level: :info
          )

          # Send email notification to user
          send_refund_email(subscription, refund_amount)

          # Broadcast event for real-time UI updates
          broadcast_refund_event(subscription.user_id, event["id"])

          {:ok, :refund_processed}
        end
    end
  end

  defp handle_refund_updated(_event, refund) do
    refund_id = refund["id"]
    status = refund["status"]

    Logger.info("Refund #{refund_id} status updated to: #{status}")

    # Track refund status changes (succeeded, failed, pending)
    # This is mainly for logging/auditing purposes
    {:ok, :refund_status_updated}
  end

  defp find_subscription_by_customer(stripe_customer_id) do
    # This is a bit of a leak, but we're just checking existence/user_id
    # We use the repo directly if available, otherwise we skip
    repo = Application.get_env(:tymeslot, :repo, Tymeslot.Repo)
    subscription_schema = Application.get_env(:tymeslot, :subscription_schema)

    if subscription_schema && Code.ensure_loaded?(subscription_schema) do
      repo.get_by(subscription_schema, stripe_customer_id: stripe_customer_id)
    else
      nil
    end
  end

  defp get_refund_amount(charge) do
    refunds = get_in(charge, ["refunds", "data"]) || get_in(charge, [:refunds, :data])

    case refunds do
      [refund | _] -> refund["amount"] || refund[:amount]
      _ -> Map.get(charge, "amount_refunded") || Map.get(charge, :amount_refunded) || 0
    end
  end

  defp broadcast_refund_event(user_id, event_id) do
    Phoenix.PubSub.broadcast(
      Tymeslot.PubSub,
      "user:#{user_id}",
      {:refund_processed, %{event_id: event_id}}
    )
  end

  defp send_refund_email(subscription, refund_amount_cents) do
    WebhookUtils.deliver_user_email(
      subscription.user_id,
      :refund_processed_template,
      :refund_processed_email,
      [refund_amount_cents],
      success_msg: "Refund notification sent to user #{subscription.user_id}",
      error_msg: "Failed to send refund notification: ",
      standalone_msg: "Refund processed template not configured (Standalone mode)"
    )
  end

  defp revoke_subscription_access(stripe_customer_id) do
    manager = subscription_manager()

    if manager && Code.ensure_loaded?(manager) do
      manager.update_subscription_status(stripe_customer_id, "canceled", DateTime.utc_now())
    else
      {:error, :subscription_manager_unavailable}
    end
  end

  defp subscription_manager do
    Application.get_env(:tymeslot, :subscription_manager)
  end

  defp ensure_revoked_access(subscription, charge_id, customer_id) do
    case revoke_subscription_access(customer_id) do
      {:ok, _} ->
        Logger.info("REFUND PROCESSED - Revoked Pro access for user #{subscription.user_id}",
          user_id: subscription.user_id,
          charge_id: charge_id,
          customer_id: customer_id
        )

        :ok

      {:error, :subscription_manager_unavailable} ->
        Logger.info("REFUND SKIPPED - Subscription manager not configured",
          charge_id: charge_id,
          customer_id: customer_id
        )

        :ok

      {:error, reason} ->
        Logger.error("REFUND ERROR - Failed to revoke access for user #{subscription.user_id}: #{inspect(reason)}",
          user_id: subscription.user_id,
          charge_id: charge_id,
          error: reason
        )

        {:error, :retry_later, "Subscription revocation failed"}
    end
  end

end
