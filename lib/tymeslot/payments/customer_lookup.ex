defmodule Tymeslot.Payments.CustomerLookup do
  @moduledoc """
  Centralized customer lookup utilities for payment operations.

  Provides functions to find user information based on Stripe customer IDs,
  consolidating logic that was previously duplicated across RefundHandler
  and SubscriptionManager.
  """

  require Logger

  @doc """
  Parses a user ID from metadata, handling both integer and string formats.
  """
  @spec parse_user_id(any()) :: integer() | nil
  def parse_user_id(nil), do: nil
  def parse_user_id(id) when is_integer(id), do: id

  def parse_user_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> int_id
      _ -> nil
    end
  end

  def parse_user_id(_), do: nil

  @doc """
  Finds the user_id associated with a Stripe customer ID.

  Queries the subscription schema (configured via application config) to find
  the user_id associated with the given Stripe customer ID.

  ## Parameters
    * `stripe_customer_id` - The Stripe customer ID to look up

  ## Returns
    * User ID (integer) if found
    * `nil` if no subscription found for the customer ID

  ## Examples

      iex> CustomerLookup.find_user_id_by_stripe_customer("cus_123")
      42

      iex> CustomerLookup.find_user_id_by_stripe_customer("cus_nonexistent")
      nil
  """
  @spec find_user_id_by_stripe_customer(String.t() | nil) :: integer() | nil
  def find_user_id_by_stripe_customer(nil), do: nil

  def find_user_id_by_stripe_customer(stripe_customer_id) do
    case get_subscription_by_customer_id(stripe_customer_id) do
      nil -> nil
      subscription -> subscription.user_id
    end
  end

  @doc """
  Gets the full subscription record by Stripe customer ID.

  Similar to `find_user_id_by_stripe_customer/1` but returns the entire
  subscription struct instead of just the user_id.

  ## Parameters
    * `stripe_customer_id` - The Stripe customer ID to look up

  ## Returns
    * Subscription struct if found
    * `nil` if no subscription found

  ## Examples

      iex> CustomerLookup.get_subscription_by_customer_id("cus_123")
      %Subscription{user_id: 42, stripe_customer_id: "cus_123", ...}

      iex> CustomerLookup.get_subscription_by_customer_id("cus_nonexistent")
      nil
  """
  @spec get_subscription_by_customer_id(String.t() | nil) :: struct() | nil
  def get_subscription_by_customer_id(nil), do: nil

  def get_subscription_by_customer_id(stripe_customer_id) do
    repo = Application.get_env(:tymeslot, :repo, Tymeslot.Repo)
    subscription_schema = Application.get_env(:tymeslot, :subscription_schema)

    if subscription_schema && Code.ensure_loaded?(subscription_schema) do
      case repo.get_by(subscription_schema, stripe_customer_id: stripe_customer_id) do
        nil ->
          Logger.debug("No subscription found for Stripe customer: #{stripe_customer_id}")
          nil

        subscription ->
          Logger.debug("Found subscription for Stripe customer: #{stripe_customer_id}")
          subscription
      end
    else
      Logger.error(
        "CRITICAL: Subscription schema not configured or not loaded. Customer lookup failed for: #{stripe_customer_id}"
      )

      nil
    end
  end
end
