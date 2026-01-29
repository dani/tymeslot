defmodule Tymeslot.Payments.CustomerLookupTest do
  use Tymeslot.DataCase, async: false

  alias Tymeslot.Payments.CustomerLookup
  alias TymeslotSaas.Schemas.Subscription

  import Tymeslot.TestFixtures

  setup do
    # Configure subscription schema for tests
    Application.put_env(:tymeslot, :subscription_schema, TymeslotSaas.Schemas.Subscription)
    Application.put_env(:tymeslot, :repo, Tymeslot.SaasRepo)

    on_exit(fn ->
      Application.delete_env(:tymeslot, :subscription_schema)
      Application.delete_env(:tymeslot, :repo)
    end)

    :ok
  end

  describe "parse_user_id/1" do
    test "parses integer" do
      assert CustomerLookup.parse_user_id(123) == 123
    end

    test "parses string integer" do
      assert CustomerLookup.parse_user_id("456") == 456
    end

    test "returns nil for invalid string" do
      assert CustomerLookup.parse_user_id("abc") == nil
    end

    test "returns nil for nil" do
      assert CustomerLookup.parse_user_id(nil) == nil
    end

    test "returns nil for other types" do
      assert CustomerLookup.parse_user_id(%{id: 1}) == nil
    end
  end

  describe "find_user_id_by_stripe_customer/1" do
    test "returns user_id when subscription exists" do
      user = create_user_fixture()
      stripe_customer_id = "cus_test_123"

      # Create subscription
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      Tymeslot.SaasRepo.insert!(%Subscription{
        user_id: user.id,
        stripe_subscription_id: "sub_123",
        stripe_customer_id: stripe_customer_id,
        plan: "pro",
        status: "active",
        current_period_start: now,
        current_period_end: DateTime.add(now, 30, :day)
      })

      assert CustomerLookup.find_user_id_by_stripe_customer(stripe_customer_id) == user.id
    end

    test "returns nil when subscription does not exist" do
      assert CustomerLookup.find_user_id_by_stripe_customer("cus_nonexistent") == nil
    end

    test "returns nil when stripe_customer_id is nil" do
      assert CustomerLookup.find_user_id_by_stripe_customer(nil) == nil
    end
  end

  describe "get_subscription_by_customer_id/1" do
    test "returns subscription struct when exists" do
      user = create_user_fixture()
      stripe_customer_id = "cus_test_456"

      # Create subscription
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      subscription = Tymeslot.SaasRepo.insert!(%Subscription{
        user_id: user.id,
        stripe_subscription_id: "sub_456",
        stripe_customer_id: stripe_customer_id,
        plan: "pro",
        status: "active",
        current_period_start: now,
        current_period_end: DateTime.add(now, 30, :day)
      })

      result = CustomerLookup.get_subscription_by_customer_id(stripe_customer_id)

      assert result.id == subscription.id
      assert result.user_id == user.id
      assert result.stripe_customer_id == stripe_customer_id
    end

    test "returns nil when subscription does not exist" do
      assert CustomerLookup.get_subscription_by_customer_id("cus_nonexistent") == nil
    end

    test "returns nil when stripe_customer_id is nil" do
      assert CustomerLookup.get_subscription_by_customer_id(nil) == nil
    end

    test "logs error when schema is not configured" do
      import ExUnit.CaptureLog
      Application.delete_env(:tymeslot, :subscription_schema)

      assert capture_log(fn ->
               assert CustomerLookup.find_user_id_by_stripe_customer("cus_123") == nil
             end) =~ "CRITICAL: Subscription schema not configured"
    end
  end
end
