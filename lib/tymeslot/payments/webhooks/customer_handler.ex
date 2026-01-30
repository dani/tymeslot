defmodule Tymeslot.Payments.Webhooks.CustomerHandler do
  @moduledoc """
  Handler for customer webhook events.
  """

  @behaviour Tymeslot.Payments.Behaviours.WebhookHandler

  require Logger

  @impl true
  def can_handle?(event_type), do: event_type in ["customer.created", "customer.updated"]

  @impl true
  def validate(customer) do
    # Check for id field with both string and atom keys
    case Map.get(customer, "id") || Map.get(customer, :id) do
      nil ->
        {:error, :missing_field, "Required field missing: id"}

      _ ->
        :ok
    end
  end

  @impl true
  def process(%{type: "customer.created"}, customer) do
    Logger.info("Processing customer.created", customer_id: Map.get(customer, "id"))
    {:ok, :customer_created}
  end

  @impl true
  def process(%{type: "customer.updated"}, customer) do
    Logger.info("Processing customer.updated", customer_id: Map.get(customer, "id"))
    {:ok, :customer_updated}
  end
end
