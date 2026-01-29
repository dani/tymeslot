defmodule Tymeslot.PaymentsTest do
  use Tymeslot.DataCase, async: true

  alias Tymeslot.Payments
  import Mox

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    Application.put_env(:tymeslot, :stripe_provider, Tymeslot.Payments.StripeMock)
    
    # Mock rate limiter
    defmodule MockRateLimiter do
      def check_payment_initiation_rate_limit(_user_id), do: :ok
    end
    # Assuming RateLimiter is configurable or we can just mock the module if it's a behaviour
    # For now let's assume it's not easily mockable without more info, 
    # but we can try to use the real one if it doesn't hit external services.
    
    :ok
  end

  describe "initiate_payment/7" do
    test "successfully initiates payment" do
      user = Tymeslot.Factory.insert(:user)
      amount = 1000
      email = "test@example.com"
      
      expect(Tymeslot.Payments.StripeMock, :create_customer, fn ^email ->
        {:ok, %{id: "cus_123"}}
      end)
      
      expect(Tymeslot.Payments.StripeMock, :create_session, fn _customer, ^amount, _transaction, _success, _cancel ->
        {:ok, %{id: "sess_123", url: "https://stripe.com/sess_123"}}
      end)
      
      assert {:ok, "https://stripe.com/sess_123"} = Payments.initiate_payment(
        amount, "Pro Plan", user.id, email, "https://success", "https://cancel"
      )
    end

    test "supersedes existing pending transaction" do
      user = Tymeslot.Factory.insert(:user)
      Tymeslot.Factory.insert(:payment_transaction, user: user, status: "pending", stripe_id: "old_sess")
      
      amount = 2000
      email = "test@example.com"
      
      expect(Tymeslot.Payments.StripeMock, :create_customer, fn ^email ->
        {:ok, %{id: "cus_123"}}
      end)
      
      expect(Tymeslot.Payments.StripeMock, :create_session, fn _customer, ^amount, _transaction, _success, _cancel ->
        {:ok, %{id: "sess_456", url: "https://stripe.com/sess_456"}}
      end)
      
      assert {:ok, "https://stripe.com/sess_456"} = Payments.initiate_payment(
        amount, "Pro Plan", user.id, email, "https://success", "https://cancel"
      )
      
      # Verify old transaction is failed/superseded
      old_tx = Tymeslot.Repo.get_by(Tymeslot.DatabaseSchemas.PaymentTransactionSchema, stripe_id: "old_sess")
      assert old_tx.status == "failed"
      assert old_tx.metadata["superseded"] == true
    end

    test "returns error for invalid amount" do
      assert {:error, :invalid_amount} = Payments.initiate_payment(
        10, "Pro Plan", 1, "test@example.com", "https://success", "https://cancel"
      )
    end
  end

  describe "process_successful_payment/3" do
    test "successfully processes payment" do
      user = Tymeslot.Factory.insert(:user)
      Tymeslot.Factory.insert(:payment_transaction, user: user, stripe_id: "sess_123", status: "pending")
      
      expect(Tymeslot.Payments.StripeMock, :verify_session, fn "sess_123" ->
        {:ok, %{id: "sess_123"}}
      end)
      
      assert {:ok, :payment_processed} = Payments.process_successful_payment("sess_123", %{"tax" => 100})
      
      tx = Tymeslot.Repo.get_by(Tymeslot.DatabaseSchemas.PaymentTransactionSchema, stripe_id: "sess_123")
      assert tx.status == "completed"
    end

    test "returns error when transaction not found" do
      expect(Tymeslot.Payments.StripeMock, :verify_session, fn "unknown" ->
        {:ok, %{id: "unknown"}}
      end)
      
      assert {:error, :transaction_not_found} = Payments.process_successful_payment("unknown", %{})
    end
  end

  describe "initiate_subscription/7" do
    test "successfully initiates subscription" do
      user = Tymeslot.Factory.insert(:user)
      
      defmodule MockSubManager do
        def create_subscription_checkout(_price, _prod, _amt, _uid, _email, _urls, _meta) do
          {:ok, %{"id" => "cs_sub_123", "url" => "https://stripe.com/sub_123", "subscription" => "sub_123"}}
        end
      end
      
      Application.put_env(:tymeslot, :subscription_manager, MockSubManager)
      
      assert {:ok, %{checkout_url: "https://stripe.com/sub_123"}} = Payments.initiate_subscription(
        "price_123", "Pro Plan", 1500, user.id, "test@example.com", %{success: "https://s", cancel: "https://c"}
      )
      
      tx = Tymeslot.Repo.get_by(Tymeslot.DatabaseSchemas.PaymentTransactionSchema, stripe_id: "cs_sub_123")
      assert tx.subscription_id == "sub_123"
      
      Application.delete_env(:tymeslot, :subscription_manager)
    end
  end
end
