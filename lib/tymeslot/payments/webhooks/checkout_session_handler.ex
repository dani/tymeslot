defmodule Tymeslot.Payments.Webhooks.CheckoutSessionHandler do
  @moduledoc """
  Handler for checkout.session.completed webhook events.
  """
  @behaviour Tymeslot.Payments.Behaviours.WebhookHandler

  require Logger
  alias DBConnection.ConnectionError
  alias Stripe.Error, as: StripeError
  alias Tymeslot.Payments

  @impl true
  def can_handle?(event_type), do: event_type == "checkout.session.completed"

  @impl true
  def validate(session) do
    # Trust Stripe's data - just ensure we have an ID
    case Map.get(session, "id") do
      nil -> {:error, :missing_field, "Session ID missing"}
      "" -> {:error, :missing_field, "Session ID empty"}
      _id -> :ok
    end
  end

  @impl true
  def process(_event, session) do
    session_id = Map.get(session, "id")
    mode = Map.get(session, "mode")
    Logger.info("Processing checkout.session.completed", session_id: session_id, mode: mode)

    case mode do
      "subscription" ->
        handle_subscription_completion(session)

      _ ->
        handle_payment_completion(session)
    end
  end

  defp handle_payment_completion(session) do
    session_id = session["id"]
    tax_info = extract_tax_info(session)

    case Payments.process_successful_payment(session_id, tax_info) do
      {:ok, :payment_processed} ->
        {:ok, :payment_processed}

      {:error, %StripeError{} = error} ->
        handle_retryable_error(error, session_id)

      {:error, %ConnectionError{} = error} ->
        {:error, :retry_later, "Database connection error: #{Exception.message(error)}"}

      {:error, reason} ->
        Logger.error("Payment processing failed",
          session_id: session_id,
          error: inspect(reason),
          session_data: Map.take(session, ["id", "metadata", "total_details", "customer_details"])
        )

        {:error, :payment_failed, "Payment processing failed: #{inspect(reason)}"}
    end
  end

  defp handle_subscription_completion(session) do
    manager = Application.get_env(:tymeslot, :subscription_manager)

    if manager do
      case manager.handle_checkout_completed(session) do
        {:ok, _transaction} ->
          {:ok, :subscription_processed}

        {:error, reason} ->
          Logger.error("Subscription processing failed",
            session_id: session["id"],
            error: inspect(reason)
          )

          {:error, :subscription_failed, "Subscription processing failed: #{inspect(reason)}"}
      end
    else
      Logger.error("Subscription manager not configured for subscription completion")
      {:error, :subscriptions_not_supported, "Subscription manager not configured"}
    end
  end

  defp extract_tax_info(session) do
    # Stripe sends tax amounts in cents, ensure it's an integer
    raw_tax_amount = get_in(session, ["total_details", "amount_tax"])

    tax_amount =
      case raw_tax_amount do
        nil ->
          0

        amount when is_integer(amount) ->
          amount

        amount when is_binary(amount) ->
          case Integer.parse(amount) do
            {parsed, _} -> parsed
            :error -> 0
          end

        _ ->
          0
      end

    %{
      tax_amount: tax_amount,
      country_code: get_in(session, ["customer_details", "address", "country"]),
      tax_id: extract_tax_id(session),
      is_eu_business: eu_business?(session),
      billing_address: get_in(session, ["customer_details", "address"])
    }
  end

  defp extract_tax_id(session) do
    case get_in(session, ["customer_details", "tax_ids"]) do
      tax_ids when is_list(tax_ids) and tax_ids != [] ->
        tax_ids |> List.first() |> Map.get("value", nil)

      _ ->
        nil
    end
  end

  @spec eu_business?(map()) :: boolean()
  defp eu_business?(session) do
    tax_ids = get_in(session, ["customer_details", "tax_ids"]) || []
    country = get_in(session, ["customer_details", "address", "country"])

    has_eu_vat =
      Enum.any?(tax_ids, fn
        %{"type" => "eu_vat"} -> true
        _ -> false
      end)

    has_eu_vat and country != nil and country in eu_country_codes()
  end

  @spec eu_country_codes() :: [String.t()]
  defp eu_country_codes do
    Application.get_env(
      :tymeslot,
      :eu_country_codes,
      ~w(AT BE BG HR CY CZ DK EE FI FR DE GR HU IE IT LV LT LU MT NL PL PT RO SK SI ES SE)
    )
  end

  defp handle_retryable_error(error, session_id) do
    if retryable_stripe_error?(error) do
      {:error, :retry_later, "Stripe error for session #{session_id}: #{error.message}"}
    else
      Logger.error("Payment processing failed",
        session_id: session_id,
        error: inspect(error)
      )

      {:error, :payment_failed, "Payment processing failed: #{inspect(error)}"}
    end
  end

  defp retryable_stripe_error?(%StripeError{extra: %{http_status: status}})
       when is_integer(status) do
    status >= 500 or status == 429
  end

  defp retryable_stripe_error?(%StripeError{source: :network}), do: true
  defp retryable_stripe_error?(_), do: false
end
