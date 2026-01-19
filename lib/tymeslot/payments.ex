defmodule Tymeslot.Payments do
  @moduledoc """
  Main entry point for payment operations.
  Provides a high-level interface for executing payment transactions.
  """

  require Logger

  alias Tymeslot.DatabaseQueries.PaymentQueries
  alias Tymeslot.DatabaseSchemas.PaymentTransactionSchema, as: PaymentTransaction
  alias Tymeslot.Payments.DatabaseOperations

  @type transaction :: PaymentTransaction.t()
  @type stripe_id :: String.t()

  @doc """
  Initiates a payment transaction for a user.

  This function only handles the payment processing and creates a transaction record.
  The calling application is responsible for any business logic such as updating
  user access levels, sending notifications, etc.

  ## Behavior for existing transactions
  - If a pending transaction exists for the user, it will be updated
    with the new amount, product_identifier, and metadata, and a new Stripe session
    will be created
  - If only completed or failed transactions exist, a new transaction will be created
  - This allows users to retry payments or change their selection without being blocked

  ## Parameters
    * amount - The amount to charge in cents
    * product_identifier - Generic identifier for what is being purchased (plan name, course ID, etc.)
    * user_id - The ID of the user making the payment
    * email - The user's email address
    * success_url - URL to redirect to after successful payment (required)
    * cancel_url - URL to redirect to if payment is cancelled (required)
    * metadata - Additional metadata for the transaction (app-specific data)

  ## Returns
    * `{:ok, session_url}` - URL for the Stripe checkout session
    * `{:error, reason}` - If the transaction creation fails
  """
  @spec initiate_payment(
          amount :: pos_integer(),
          product_identifier :: String.t(),
          user_id :: pos_integer(),
          email :: String.t(),
          success_url :: String.t(),
          cancel_url :: String.t(),
          metadata :: map()
        ) :: {:ok, String.t()} | {:error, term()}
  def initiate_payment(
        amount,
        product_identifier,
        user_id,
        email,
        success_url,
        cancel_url,
        metadata \\ %{}
      ) do
    # Check for existing pending transaction for this user
    case get_pending_transaction_for_user(user_id) do
      nil ->
        # No pending transaction, create a new one
        create_new_payment_transaction(
          amount,
          product_identifier,
          user_id,
          email,
          success_url,
          cancel_url,
          metadata
        )

      existing_transaction ->
        # Pending transaction exists, supersede it and create a new checkout session
        Logger.info(
          "Superseding existing pending transaction #{existing_transaction.id} for user #{user_id}"
        )

        with :ok <- supersede_pending_transaction(existing_transaction) do
          create_new_payment_transaction(
            amount,
            product_identifier,
            user_id,
            email,
            success_url,
            cancel_url,
            metadata
          )
        end
    end
  end

  # Gets an existing pending transaction for the user.
  # Returns the transaction or nil if none exists.
  @spec get_pending_transaction_for_user(pos_integer()) :: transaction() | nil
  defp get_pending_transaction_for_user(user_id) do
    case PaymentQueries.get_transactions_by_status("pending", user_id) do
      {:ok, [transaction | _]} -> transaction
      _ -> nil
    end
  end

  # Creates a new payment transaction
  @spec create_new_payment_transaction(
          pos_integer(),
          String.t(),
          pos_integer(),
          String.t(),
          String.t(),
          String.t(),
          map()
        ) :: {:ok, String.t()} | {:error, term()}
  defp create_new_payment_transaction(
         amount,
         product_identifier,
         user_id,
         email,
         success_url,
         cancel_url,
         metadata
       ) do
    attrs = %{
      user_id: user_id,
      amount: amount,
      product_identifier: product_identifier,
      status: "pending",
      metadata: metadata
    }

    with {:ok, transaction} <- DatabaseOperations.create_payment_transaction(attrs),
         {:ok, customer} <- stripe_provider().create_customer(email),
         {:ok, session} <-
           stripe_provider().create_session(
             customer,
             amount,
             transaction,
             success_url,
             cancel_url
           ),
         {:ok, _updated} <- DatabaseOperations.update_transaction_session(transaction, session) do
      Logger.info("Payment initiated for user #{user_id}, transaction created")
      {:ok, session.url}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        # Handle unique constraint violation (race condition where two processes try to create pending transaction)
        if changeset.errors[:user_id] &&
             Enum.any?(changeset.errors[:user_id], fn {msg, _} ->
               String.contains?(msg, "has already been taken")
             end) do
          Logger.info(
            "Race condition detected for user #{user_id} in create_new_payment_transaction, retrying..."
          )

          # Retry initiation - this will now find the existing transaction created by the other process
          initiate_payment(
            amount,
            product_identifier,
            user_id,
            email,
            success_url,
            cancel_url,
            metadata
          )
        else
          Logger.error("Failed to create transaction: #{inspect(changeset.errors)}")
          {:error, :transaction_creation_failed}
        end

      {:error, error} ->
        Logger.error("Payment initiation failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Supersedes an existing pending transaction to avoid losing old session IDs.
  @spec supersede_pending_transaction(transaction()) :: :ok | {:error, term()}
  defp supersede_pending_transaction(transaction) do
    update_attrs = %{
      status: "failed",
      metadata:
        Map.merge(transaction.metadata, %{
          "superseded" => true,
          "superseded_at" => DateTime.to_iso8601(DateTime.utc_now())
        })
    }

    case PaymentQueries.update_transaction(transaction, update_attrs) do
      {:ok, _updated_transaction} ->
        :ok

      {:error, error} ->
        Logger.error("Failed to supersede pending transaction: #{inspect(error)}")
        {:error, :transaction_update_failed}
    end
  end

  @doc """
  Processes a successful payment.

  This function only updates the transaction status and tax information.
  The calling application should handle any business logic such as updating
  user permissions, sending confirmation emails, etc.

  ## Parameters
    * stripe_id - The Stripe session ID
    * tax_info - Tax information for the transaction
    * discount_amount - Any discount applied to the transaction (in cents)

  ## Returns
    * `{:ok, :payment_processed}` - If the payment is processed successfully
    * `{:error, reason}` - If the payment processing fails
  """
  @spec process_successful_payment(stripe_id(), map(), non_neg_integer()) ::
          {:ok, :payment_processed} | {:error, term()}
  def process_successful_payment(stripe_id, tax_info, discount_amount \\ 0) do
    Logger.info("Processing successful payment for stripe_id: #{stripe_id}")

    with {:ok, _session} <- stripe_provider().verify_session(stripe_id),
         {:ok, :payment_processed} <-
           DatabaseOperations.process_successful_payment(stripe_id, tax_info, discount_amount) do
      {:ok, :payment_processed}
    else
      {:error, :transaction_not_found} ->
        Logger.error("Transaction not found for successful payment: #{stripe_id}")
        {:error, :transaction_not_found}

      {:error, reason} ->
        Logger.error("Failed to process payment: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Processes a failed payment.

  ## Parameters
    * stripe_id - The Stripe session ID

  ## Returns
    * `{:ok, :payment_failed}` - If the payment failure is recorded successfully
    * `{:error, reason}` - If recording the payment failure fails
  """
  @spec process_failed_payment(stripe_id()) ::
          {:ok, :payment_failed | :transaction_not_found} | {:error, String.t()}
  def process_failed_payment(stripe_id) do
    Logger.info("Processing failed payment for stripe_id: #{stripe_id}")
    DatabaseOperations.process_failed_payment(stripe_id)
  end

  @doc """
  Retrieves a transaction by its Stripe ID.

  ## Parameters
    * stripe_id - The Stripe session ID

  ## Returns
    * `{:ok, transaction}` - If the transaction is found
    * `{:error, :transaction_not_found}` - If no transaction is found
  """
  @spec get_transaction(stripe_id()) :: {:ok, transaction()} | {:error, :transaction_not_found}
  def get_transaction(stripe_id) do
    DatabaseOperations.get_transaction_by_stripe_id(stripe_id)
  end

  @doc """
  Initiates a subscription with the provided payment details.

  This function creates a Stripe checkout session for recurring payments.
  The calling application is responsible for plan validation and providing
  the concrete payment details (stripe_price_id, amount, product_identifier).

  ## Parameters
    * stripe_price_id - The Stripe price ID for the subscription
    * product_identifier - Generic identifier for what is being purchased (plan name, etc.)
    * amount - The subscription amount in cents (for transaction tracking)
    * user_id - The ID of the user purchasing the subscription
    * email - The user's email address
    * success_url - URL to redirect to after successful subscription (required)
    * cancel_url - URL to redirect to if subscription is cancelled (required)
    * metadata - Additional metadata for the subscription (app-specific data)

  ## Returns
    * `{:ok, %{checkout_url: url}}` - URL for the Stripe checkout session
    * `{:error, reason}` - If the subscription creation fails
  """
  @spec initiate_subscription(
          stripe_price_id :: String.t(),
          product_identifier :: String.t(),
          amount :: pos_integer(),
          user_id :: pos_integer(),
          email :: String.t(),
          urls :: %{success: String.t(), cancel: String.t()},
          metadata :: map()
        ) :: {:ok, %{checkout_url: String.t()}} | {:error, term()}
  def initiate_subscription(
        stripe_price_id,
        product_identifier,
        amount,
        user_id,
        email,
        urls,
        metadata \\ %{}
      ) do
    manager = subscription_manager()
    subscription_metadata = Map.put(metadata, "payment_type", "subscription")

    if manager do
      case manager.create_subscription_checkout(
             stripe_price_id,
             product_identifier,
             amount,
             user_id,
             email,
             urls,
             subscription_metadata
           ) do
        {:ok, checkout_session} ->
          transaction_attrs = %{
            user_id: user_id,
            amount: amount,
            product_identifier: product_identifier,
            status: "pending",
            metadata: subscription_metadata,
            stripe_id: checkout_session["id"],
            subscription_id: checkout_session["subscription"]
          }

          with {:ok, _transaction} <-
                 DatabaseOperations.create_payment_transaction(transaction_attrs) do
            {:ok, %{checkout_url: checkout_session["url"]}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      Logger.error("Subscription manager not configured")
      {:error, :subscriptions_not_supported}
    end
  end

  @doc """
  Cancels an active subscription.

  ## Parameters
    * subscription_id - The Stripe subscription ID
    * user_id - The ID of the user canceling the subscription
    * opts - Options for cancellation (at_period_end: true/false)

  ## Returns
    * `{:ok, subscription}` - If the subscription is canceled successfully
    * `{:error, reason}` - If the cancellation fails
  """
  @spec cancel_subscription(String.t(), pos_integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def cancel_subscription(subscription_id, user_id, opts \\ []) do
    manager = subscription_manager()

    if manager do
      manager.cancel_subscription(subscription_id, user_id, opts)
    else
      Logger.error("Subscription manager not configured")
      {:error, :subscriptions_not_supported}
    end
  end

  @doc """
  Updates a subscription to a new Stripe price.

  ## Parameters
    * subscription_id - The Stripe subscription ID
    * new_stripe_price_id - The new Stripe price ID
    * user_id - The ID of the user updating the subscription
    * metadata - Additional metadata

  ## Returns
    * `{:ok, subscription}` - If the subscription is updated successfully
    * `{:error, reason}` - If the update fails
  """
  @spec update_subscription(String.t(), String.t(), pos_integer(), map()) ::
          {:ok, map()} | {:error, term()}
  def update_subscription(
        subscription_id,
        new_stripe_price_id,
        user_id,
        metadata \\ %{}
      ) do
    manager = subscription_manager()

    if manager do
      manager.update_subscription(
        subscription_id,
        new_stripe_price_id,
        user_id,
        metadata
      )
    else
      Logger.error("Subscription manager not configured")
      {:error, :subscriptions_not_supported}
    end
  end

  # Private helper functions

  defp subscription_manager do
    Application.get_env(:tymeslot, :subscription_manager)
  end

  defp stripe_provider do
    Application.get_env(:tymeslot, :stripe_provider, Tymeslot.Payments.Stripe)
  end
end
