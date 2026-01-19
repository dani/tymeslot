defmodule Tymeslot.Payments.Webhooks.InvoiceHandler do
  @moduledoc """
  Handler for invoice.* webhook events.
  """
  @behaviour Tymeslot.Payments.Behaviours.WebhookHandler

  require Logger
  alias Tymeslot.Payments.DatabaseOperations

  @impl true
  def can_handle?(event_type) do
    event_type in ["invoice.payment_succeeded", "invoice.payment_failed"]
  end

  @impl true
  def validate(invoice) do
    case Map.get(invoice, "id") do
      nil -> {:error, :missing_field, "Invoice ID missing"}
      "" -> {:error, :missing_field, "Invoice ID empty"}
      _id -> :ok
    end
  end

  @impl true
  def process(event, invoice) do
    event_type = event["type"] || event[:type]
    subscription_id = invoice["subscription"]

    Logger.info("Processing invoice event",
      event_type: event_type,
      subscription_id: subscription_id
    )

    case event_type do
      "invoice.payment_succeeded" ->
        handle_payment_succeeded(subscription_id, invoice)

      "invoice.payment_failed" ->
        handle_payment_failed(subscription_id, invoice)

      _ ->
        {:ok, :ignored}
    end
  end

  defp handle_payment_succeeded(nil, _invoice), do: {:ok, :no_subscription}

  defp handle_payment_succeeded(subscription_id, invoice) do
    case DatabaseOperations.process_subscription_renewal(subscription_id, invoice) do
      {:ok, _} ->
        {:ok, :invoice_processed}

      {:error, :subscription_not_found} ->
        Logger.warning("Subscription not found for invoice, might be a race condition",
          subscription_id: subscription_id
        )

        {:error, :retry_later,
         "Subscription not found for #{subscription_id}, retrying via Stripe"}

      {:error, reason} ->
        Logger.error("Failed to process invoice success",
          subscription_id: subscription_id,
          error: inspect(reason)
        )

        {:error, :processing_failed, "Failed to process invoice success: #{inspect(reason)}"}
    end
  end

  defp handle_payment_failed(nil, _invoice), do: {:ok, :no_subscription}

  defp handle_payment_failed(subscription_id, invoice) do
    case DatabaseOperations.process_subscription_failure(subscription_id, invoice) do
      {:ok, _} ->
        {:ok, :invoice_processed}

      {:error, :subscription_not_found} ->
        Logger.warning("Subscription not found for invoice failure, might be a race condition",
          subscription_id: subscription_id
        )

        {:error, :retry_later,
         "Subscription not found for #{subscription_id}, retrying via Stripe"}

      {:error, reason} ->
        Logger.error("Failed to process invoice failure",
          subscription_id: subscription_id,
          error: inspect(reason)
        )

        {:error, :processing_failed, "Failed to process invoice failure: #{inspect(reason)}"}
    end
  end
end
