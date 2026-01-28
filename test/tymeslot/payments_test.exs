defmodule Tymeslot.PaymentsTest do
  use Tymeslot.DataCase, async: true
  alias Tymeslot.DatabaseQueries.PaymentQueries
  alias Tymeslot.DatabaseSchemas.PaymentTransactionSchema
  alias Tymeslot.Payments
  alias Tymeslot.Repo
  import Mox

  setup do
    # Explicitly set the mocks to override runtime configuration
    Application.put_env(:tymeslot, :stripe_provider, Tymeslot.Payments.StripeMock)

    Application.put_env(
      :tymeslot,
      :subscription_manager,
      Tymeslot.Payments.SubscriptionManagerMock
    )

    :ok
  end

  setup :verify_on_exit!

  describe "initiate_payment/7" do
    test "creates a new transaction and stripe session" do
      user = insert(:user)
      amount = 1000
      product = "pro_plan"
      email = user.email
      success_url = "http://success"
      cancel_url = "http://cancel"

      expect(Tymeslot.Payments.StripeMock, :create_customer, fn ^email ->
        {:ok, %{id: "cus_123"}}
      end)

      expect(Tymeslot.Payments.StripeMock, :create_session, fn _customer,
                                                               ^amount,
                                                               _transaction,
                                                               ^success_url,
                                                               ^cancel_url ->
        {:ok, %{id: "sess_123", url: "http://stripe.com/pay"}}
      end)

      assert {:ok, url} =
               Payments.initiate_payment(amount, product, user.id, email, success_url, cancel_url)

      assert url == "http://stripe.com/pay"

      # Verify transaction was created
      assert {:ok, [transaction]} = PaymentQueries.get_transactions_by_status("pending", user.id)
      assert transaction.amount == amount
      assert transaction.stripe_id == "sess_123"
    end

    test "supersedes existing pending transaction" do
      user = insert(:user)
      old_transaction = insert(:payment_transaction, user: user, status: "pending")

      amount = 2000
      email = user.email

      expect(Tymeslot.Payments.StripeMock, :create_customer, fn _ -> {:ok, %{id: "cus_123"}} end)

      expect(Tymeslot.Payments.StripeMock, :create_session, fn _, _, _, _, _ ->
        {:ok, %{id: "sess_456", url: "http://stripe.com/pay2"}}
      end)

      assert {:ok, _} = Payments.initiate_payment(amount, "new", user.id, email, "s", "c")

      # Verify old transaction is failed/superseded
      old = Repo.get!(PaymentTransactionSchema, old_transaction.id)
      assert old.status == "failed"
      assert old.metadata["superseded"] == true
    end
  end

  describe "process_successful_payment/3" do
    test "updates transaction status to completed" do
      transaction = insert(:payment_transaction, stripe_id: "sess_123", status: "pending")

      expect(Tymeslot.Payments.StripeMock, :verify_session, fn "sess_123" ->
        {:ok, %{id: "sess_123", status: "complete"}}
      end)

      assert {:ok, :payment_processed} =
               Payments.process_successful_payment("sess_123", %{tax: 0})

      updated = Repo.get!(PaymentTransactionSchema, transaction.id)
      assert updated.status == "completed"
    end

    test "returns error if transaction not found" do
      expect(Tymeslot.Payments.StripeMock, :verify_session, fn "unknown" ->
        {:ok, %{id: "unknown"}}
      end)

      assert Payments.process_successful_payment("unknown", %{}) ==
               {:error, :transaction_not_found}
    end
  end

  describe "process_failed_payment/1" do
    test "updates transaction status to failed" do
      transaction = insert(:payment_transaction, stripe_id: "sess_fail", status: "pending")
      assert {:ok, :payment_failed} = Payments.process_failed_payment("sess_fail")

      updated = Repo.get!(PaymentTransactionSchema, transaction.id)
      assert updated.status == "failed"
    end
  end

  describe "initiate_subscription/7" do
    test "creates subscription and transaction" do
      user = insert(:user)
      urls = %{success: "s", cancel: "c"}

      expect(Tymeslot.Payments.SubscriptionManagerMock, :create_subscription_checkout, fn _p,
                                                                                          _pr,
                                                                                          _a,
                                                                                          _u,
                                                                                          _e,
                                                                                          ^urls,
                                                                                          _m ->
        {:ok, %{"id" => "sess_sub", "url" => "http://sub", "subscription" => "sub_123"}}
      end)

      assert {:ok, %{checkout_url: url}} =
               Payments.initiate_subscription("price_1", "pro", 1000, user.id, user.email, urls)

      assert url == "http://sub"

      assert {:ok, [transaction]} = PaymentQueries.get_transactions_by_status("pending", user.id)
      assert transaction.stripe_id == "sess_sub"
      assert transaction.subscription_id == "sub_123"
    end
  end
end
