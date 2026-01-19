defmodule Tymeslot.Payments.Webhooks.WebhookRegistry do
  @moduledoc """
  Registry for webhook event handlers.
  """

  require Logger

  @webhook_handlers [
    Tymeslot.Payments.Webhooks.CheckoutSessionHandler,
    Tymeslot.Payments.Webhooks.CheckoutSessionExpiredHandler,
    Tymeslot.Payments.Webhooks.ChargeHandler,
    Tymeslot.Payments.Webhooks.PaymentIntentHandler,
    Tymeslot.Payments.Webhooks.CustomerHandler,
    Tymeslot.Payments.Webhooks.SubscriptionHandler,
    Tymeslot.Payments.Webhooks.InvoiceHandler
  ]

  # Map of handler modules to their supported event types
  @event_types %{
    Tymeslot.Payments.Webhooks.CheckoutSessionHandler => ["checkout.session.completed"],
    Tymeslot.Payments.Webhooks.CheckoutSessionExpiredHandler => ["checkout.session.expired"],
    Tymeslot.Payments.Webhooks.ChargeHandler => ["charge.succeeded", "charge.failed"],
    Tymeslot.Payments.Webhooks.PaymentIntentHandler => [
      "payment_intent.succeeded",
      "payment_intent.created"
    ],
    Tymeslot.Payments.Webhooks.CustomerHandler => ["customer.created"],
    Tymeslot.Payments.Webhooks.SubscriptionHandler => [
      "customer.subscription.created",
      "customer.subscription.updated",
      "customer.subscription.deleted"
    ],
    Tymeslot.Payments.Webhooks.InvoiceHandler => [
      "invoice.payment_succeeded",
      "invoice.payment_failed"
    ]
  }

  @doc """
  Finds a handler for the given event type.

  Returns {:ok, handler_module} if a handler is found,
  or {:error, :no_handler} if no handler exists for the event type.
  """
  @spec find_handler(String.t()) :: {:ok, module()} | {:error, :no_handler}
  def find_handler(event_type) do
    handler =
      Enum.find(@webhook_handlers, fn handler ->
        handler.can_handle?(event_type)
      end)

    case handler do
      nil -> {:error, :no_handler}
      module -> {:ok, module}
    end
  end

  @doc """
  Returns a list of all event types handled by registered handlers.
  """
  @spec handled_event_types() :: [String.t()]
  def handled_event_types do
    Enum.flat_map(@webhook_handlers, fn handler ->
      Map.get(@event_types, handler, [])
    end)
  end

  @doc """
  Validates an object using the appropriate handler.

  Returns :ok if valid, or {:error, reason, message} if validation fails.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, atom(), String.t()}
  def validate(event_type, object) do
    with {:ok, handler} <- find_handler(event_type),
         :ok <- apply_validation(handler, object) do
      :ok
    else
      {:error, reason, message} -> {:error, reason, message}
      # No validation if no handler
      {:error, :no_handler} -> :ok
    end
  end

  defp apply_validation(handler, object) do
    if function_exported?(handler, :validate, 1) do
      handler.validate(object)
    else
      :ok
    end
  end
end
