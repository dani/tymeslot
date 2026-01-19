defmodule Tymeslot.DatabaseQueries.PaymentQueries do
  @moduledoc """
  Database queries for payment transactions.
  """
  import Ecto.Query

  alias Tymeslot.DatabaseSchemas.PaymentTransactionSchema, as: PaymentTransaction
  alias Tymeslot.Repo

  @doc """
  Creates a new payment transaction.
  """
  @spec create_transaction(map()) :: {:ok, PaymentTransaction.t()} | {:error, Ecto.Changeset.t()}
  def create_transaction(attrs) do
    %PaymentTransaction{}
    |> PaymentTransaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a transaction by Stripe ID.
  """
  @spec get_transaction_by_stripe_id(String.t()) ::
          {:ok, PaymentTransaction.t()} | {:error, :not_found}
  def get_transaction_by_stripe_id(stripe_id) do
    case Repo.get_by(PaymentTransaction, stripe_id: stripe_id) do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Gets a transaction by Subscription ID.
  """
  @spec get_active_subscription_transaction_by_subscription_id(String.t()) ::
          {:ok, PaymentTransaction.t()} | {:error, :not_found}
  def get_active_subscription_transaction_by_subscription_id(subscription_id) do
    query =
      from(t in PaymentTransaction,
        where: t.subscription_id == ^subscription_id,
        where: t.status == "completed",
        order_by: [desc: t.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Gets the active subscription transaction for a user.
  """
  @spec get_active_subscription_transaction(pos_integer()) ::
          {:ok, PaymentTransaction.t()} | {:error, :not_found}
  def get_active_subscription_transaction(user_id) do
    query =
      from(t in PaymentTransaction,
        where: t.user_id == ^user_id,
        where: t.status == "completed",
        order_by: [desc: t.inserted_at],
        limit: 1
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      transaction -> {:ok, transaction}
    end
  end

  @doc """
  Coordinates successful subscription renewal payment by creating a new transaction record.
  """
  @spec coordinate_subscription_renewal(String.t(), map()) ::
          {:ok, PaymentTransaction.t()} | {:error, any()}
  def coordinate_subscription_renewal(subscription_id, invoice_data) do
    with {:ok, transaction} <-
           get_active_subscription_transaction_by_subscription_id(subscription_id) do
      # Create a NEW transaction record for the renewal instead of updating the old one
      renewal_attrs = %{
        user_id: transaction.user_id,
        amount: invoice_data["amount_paid"] || transaction.amount,
        status: "completed",
        # Use the invoice ID as the stripe_id for this transaction
        stripe_id: invoice_data["id"],
        stripe_customer_id: transaction.stripe_customer_id,
        product_identifier: transaction.product_identifier,
        subscription_id: subscription_id,
        metadata:
          Map.merge(transaction.metadata, %{
            renewal_invoice_id: invoice_data["id"],
            renewal_date: invoice_data["created"],
            original_transaction_id: transaction.id
          })
      }

      create_transaction(renewal_attrs)
    end
  end

  @doc """
  Updates a transaction.
  """
  @spec update_transaction(PaymentTransaction.t(), map()) ::
          {:ok, PaymentTransaction.t()} | {:error, Ecto.Changeset.t()}
  def update_transaction(transaction, attrs) do
    transaction
    |> PaymentTransaction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates transaction status.
  """
  @spec update_transaction_status(PaymentTransaction.t(), String.t()) ::
          {:ok, PaymentTransaction.t()} | {:error, Ecto.Changeset.t()}
  def update_transaction_status(transaction, status) do
    update_transaction(transaction, %{status: status})
  end

  @doc """
  Gets transactions by status for a specific user.
  """
  @spec get_transactions_by_status(String.t(), pos_integer()) ::
          {:ok, [PaymentTransaction.t()]}
  def get_transactions_by_status(status, user_id) do
    query =
      from(t in PaymentTransaction,
        where: t.status == ^status,
        where: t.user_id == ^user_id
      )

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets transactions by status.
  """
  @spec get_transactions_by_status(String.t()) :: {:ok, [PaymentTransaction.t()]}
  def get_transactions_by_status(status) do
    query = from(t in PaymentTransaction, where: t.status == ^status)
    {:ok, Repo.all(query)}
  end

  @doc """
  Coordinates successful payment update with tax information.
  """
  @spec coordinate_successful_payment(String.t(), map(), integer()) ::
          {:ok, PaymentTransaction.t()} | {:error, any()}
  def coordinate_successful_payment(stripe_id, tax_info \\ %{}, discount_amount \\ 0) do
    with {:ok, transaction} <- get_transaction_by_stripe_id(stripe_id) do
      update_attrs = %{
        status: "completed",
        tax_amount: Map.get(tax_info, :tax_amount),
        tax_rate: Map.get(tax_info, :tax_rate),
        tax_id: Map.get(tax_info, :tax_id),
        is_eu_business: Map.get(tax_info, :is_eu_business, false),
        country_code: Map.get(tax_info, :country_code),
        billing_address: Map.get(tax_info, :billing_address),
        discount_amount: discount_amount
      }

      update_transaction(transaction, update_attrs)
    end
  end

  @doc """
  Gets abandoned transaction candidates for email reminders.
  Returns list of {user_id, count} tuples for users with pending transactions
  older than 10 minutes that haven't received an email yet.

  Options:
    * :product_identifiers - List of product identifiers to include
    * :payment_type - Filter on metadata payment_type (e.g., "subscription")
  """
  @spec get_abandoned_transaction_candidates(keyword()) :: {:ok, [{pos_integer(), integer()}]}
  def get_abandoned_transaction_candidates(opts \\ []) do
    threshold_seconds = Keyword.get(opts, :threshold_seconds) || abandoned_threshold_seconds()
    ten_minutes_ago = DateTime.add(DateTime.utc_now(), -threshold_seconds, :second)
    product_identifiers = Keyword.get(opts, :product_identifiers)
    payment_type = Keyword.get(opts, :payment_type)

    query =
      from(t in PaymentTransaction,
        where: t.status == "pending",
        where: t.inserted_at < ^ten_minutes_ago,
        where:
          fragment(
            "? ->> 'abandoned_email_sent' IS NULL OR ? ->> 'abandoned_email_sent' = 'false'",
            t.metadata,
            t.metadata
          )
      )

    query =
      if product_identifiers do
        from(t in query, where: t.product_identifier in ^product_identifiers)
      else
        query
      end

    query =
      if payment_type do
        from(t in query,
          where: fragment("? ->> 'payment_type' = ?", t.metadata, ^payment_type)
        )
      else
        query
      end

    query =
      from(t in query,
        group_by: t.user_id,
        select: {t.user_id, count(t.id)}
      )

    {:ok, Repo.all(query)}
  end

  @doc """
  Marks abandoned transaction email as sent for a user.
  """
  @spec mark_abandoned_transaction_email_sent(pos_integer()) :: {integer(), nil}
  def mark_abandoned_transaction_email_sent(user_id) do
    query =
      from(t in PaymentTransaction,
        where: t.user_id == ^user_id,
        where: t.status == "pending",
        update: [
          set: [
            metadata:
              fragment(
                "jsonb_set(?, '{abandoned_email_sent}', 'true')",
                t.metadata
              )
          ]
        ]
      )

    Repo.update_all(query, [])
  end

  defp abandoned_threshold_seconds do
    Application.get_env(:tymeslot, :abandoned_transaction_threshold_seconds, 600)
  end
end
