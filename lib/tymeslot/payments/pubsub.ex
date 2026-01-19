defmodule Tymeslot.Payments.PubSub do
  @moduledoc """
  Handles PubSub broadcasting for payment-related events.

  This module provides a centralized way to broadcast payment events
  to apps, allowing them to handle app-specific logic (like confirmation emails)
  without coupling the payment library to specific app implementations.
  """
  require Logger

  alias Phoenix.PubSub

  @doc """
  Broadcasts a payment success event via PubSub.

  Apps can subscribe to "payment:payment_successful" topic to handle app-specific
  post-payment logic.

  ## Parameters
  - `transaction`: The completed transaction struct

  ## Example
      Tymeslot.Payments.PubSub.broadcast_payment_successful(transaction)
  """
  @spec broadcast_payment_successful(struct()) :: :ok
  def broadcast_payment_successful(transaction) do
    pubsub_server = get_pubsub_server()

    if pubsub_server do
      message =
        {:payment_successful,
         %{
           user_id: transaction.user_id,
           transaction: transaction
         }}

      # Phoenix.PubSub.broadcast/3 returns :ok
      _ = PubSub.broadcast(pubsub_server, "payment:payment_successful", message)

      Logger.info("Broadcasted payment_successful event for user_id=#{transaction.user_id}")
    else
      Logger.warning("No PubSub server found, skipping payment_successful broadcast")
    end

    :ok
  end

  @doc """
  General broadcast function to send any event to PubSub.
  """
  @spec broadcast(String.t(), any()) :: :ok | {:error, any()}
  def broadcast(topic, message) do
    pubsub_server = get_pubsub_server()

    if pubsub_server do
      PubSub.broadcast(pubsub_server, topic, message)
    else
      Logger.warning("No PubSub server found, skipping broadcast")
      {:error, :no_pubsub_server}
    end
  end

  @doc """
  Broadcasts a subscription event.
  Used for events like :subscription_created, :subscription_canceled, :subscription_updated.
  """
  @spec broadcast_subscription_event(map()) :: :ok
  def broadcast_subscription_event(event_data) do
    topic = "payment_events:tymeslot"
    _ = broadcast(topic, event_data)
    :ok
  end

  @doc """
  Gets the PubSub server name.

  ## Parameters
  ## Returns
  - The PubSub module atom if found and running
  - `nil` if the PubSub server doesn't exist or isn't running
  """
  @spec get_pubsub_server() :: module() | nil
  def get_pubsub_server do
    force_app_pubsub? = Application.get_env(:tymeslot, :force_app_pubsub_in_test, false)

    # Use test PubSub server in test unless explicitly forced to use app PubSub
    if !force_app_pubsub? and
         (Application.get_env(:tymeslot, :test_mode, false) or test_env?()) do
      Tymeslot.TestPubSub
    else
      pubsub_module_name = "Tymeslot.PubSub"

      try do
        # Convert string to existing atom (will raise if module doesn't exist)
        pubsub_module = String.to_existing_atom("Elixir.#{pubsub_module_name}")

        # Check if the process is actually running
        if Process.whereis(pubsub_module) do
          pubsub_module
        else
          Logger.warning("PubSub server #{pubsub_module_name} not running")
          nil
        end
      rescue
        ArgumentError ->
          Logger.warning("PubSub module #{pubsub_module_name} does not exist")
          nil
      end
    end
  end

  defp test_env? do
    Application.get_env(:tymeslot, :env, :prod) == :test or
      System.get_env("MIX_ENV") == "test"
  end

  @doc """
  Broadcasts a subscription success event via PubSub.

  Apps can subscribe to "payment:subscription_successful" topic to handle app-specific
  post-subscription logic.

  ## Parameters
  - `transaction`: The completed subscription transaction struct

  ## Example
      Tymeslot.Payments.PubSub.broadcast_subscription_successful(transaction)
  """
  @spec broadcast_subscription_successful(struct()) :: :ok
  def broadcast_subscription_successful(transaction) do
    pubsub_server = get_pubsub_server()

    if pubsub_server do
      message =
        {:subscription_successful,
         %{
           user_id: transaction.user_id,
           subscription_id: transaction.subscription_id,
           transaction: transaction
         }}

      _ = PubSub.broadcast(pubsub_server, "payment:subscription_successful", message)

      Logger.info("Broadcasted subscription_successful event for user_id=#{transaction.user_id}")
    else
      Logger.warning("No PubSub server found, skipping subscription_successful broadcast")
    end

    :ok
  end

  @doc """
  Broadcasts a subscription failure event via PubSub.

  Apps can subscribe to "payment:subscription_failed" topic to handle app-specific
  post-subscription failure logic.

  ## Parameters
  - `transaction`: The failed subscription transaction struct

  ## Example
      Tymeslot.Payments.PubSub.broadcast_subscription_failed(transaction)
  """
  @spec broadcast_subscription_failed(struct()) :: :ok
  def broadcast_subscription_failed(transaction) do
    pubsub_server = get_pubsub_server()

    if pubsub_server do
      message =
        {:subscription_failed,
         %{
           user_id: transaction.user_id,
           subscription_id: transaction.subscription_id,
           transaction: transaction
         }}

      _ = PubSub.broadcast(pubsub_server, "payment:subscription_failed", message)

      Logger.info("Broadcasted subscription_failed event for user_id=#{transaction.user_id}")
    else
      Logger.warning("No PubSub server found, skipping subscription_failed broadcast")
    end

    :ok
  end
end
