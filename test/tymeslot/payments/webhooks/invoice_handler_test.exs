defmodule Tymeslot.Payments.Webhooks.InvoiceHandlerTest do
  use Tymeslot.DataCase, async: true

  alias Tymeslot.DatabaseQueries.PaymentQueries
  alias Tymeslot.Payments.Webhooks.InvoiceHandler
  import Tymeslot.Factory

  describe "can_handle?/1" do
    test "returns true for supported invoice events" do
      assert InvoiceHandler.can_handle?("invoice.payment_succeeded")
      assert InvoiceHandler.can_handle?("invoice.payment_failed")
    end

    test "returns false for unsupported events" do
      refute InvoiceHandler.can_handle?("invoice.created")
      refute InvoiceHandler.can_handle?("customer.created")
    end
  end

  describe "validate/1" do
    test "returns :ok for valid invoice" do
      assert InvoiceHandler.validate(%{"id" => "in_123"}) == :ok
    end

    test "returns error for missing or empty id" do
      assert {:error, :missing_field, _} = InvoiceHandler.validate(%{})
      assert {:error, :missing_field, _} = InvoiceHandler.validate(%{"id" => ""})
    end
  end

  describe "process/2" do
    test "handles invoice.payment_succeeded" do
      user = insert(:user)
      subscription_id = "sub_123"

      # Create an existing transaction for this subscription
      insert(:payment_transaction,
        user: user,
        subscription_id: subscription_id,
        status: "completed",
        stripe_id: "sess_123"
      )

      invoice = %{
        "id" => "in_123",
        "subscription" => subscription_id,
        "amount_paid" => 1000,
        "currency" => "eur",
        "status" => "paid"
      }

      event = %{"type" => "invoice.payment_succeeded"}

      assert {:ok, :invoice_processed} = InvoiceHandler.process(event, invoice)

      # Verify a new transaction was created for the renewal
      assert {:ok, transactions} = PaymentQueries.get_transactions_by_status("completed", user.id)
      # One initial + one renewal
      assert length(transactions) == 2
    end

    test "handles invoice.payment_failed" do
      user = insert(:user)
      subscription_id = "sub_fail"

      insert(:payment_transaction,
        user: user,
        subscription_id: subscription_id,
        status: "completed",
        stripe_id: "sess_fail"
      )

      invoice = %{
        "id" => "in_fail",
        "subscription" => subscription_id,
        "billing_reason" => "subscription_cycle",
        "attempt_count" => 1,
        "created" => 1_234_567_890
      }

      event = %{"type" => "invoice.payment_failed"}

      assert {:ok, :invoice_processed} = InvoiceHandler.process(event, invoice)

      # Verify transaction status was updated to pending_reconciliation
      assert {:ok, [t]} =
               PaymentQueries.get_transactions_by_status("pending_reconciliation", user.id)

      assert t.subscription_id == subscription_id
    end

    test "returns error when subscription not found" do
      invoice = %{"id" => "in_123", "subscription" => "nonexistent"}
      event = %{"type" => "invoice.payment_succeeded"}

      assert {:error, :retry_later, _} = InvoiceHandler.process(event, invoice)
    end

    test "returns ok for missing subscription id" do
      invoice = %{"id" => "in_123", "subscription" => nil}
      event = %{"type" => "invoice.payment_succeeded"}

      assert {:ok, :no_subscription} = InvoiceHandler.process(event, invoice)
    end
  end
end
