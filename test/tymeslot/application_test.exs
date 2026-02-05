defmodule Tymeslot.ApplicationTest do
  use ExUnit.Case, async: false

  alias Tymeslot.Infrastructure.{AvailabilityCache, DashboardCache}
  alias Tymeslot.Payments.Webhooks.IdempotencyCache
  alias Tymeslot.Security.{AccountLockout, RateLimiter}

  describe "core application services" do
    test "Tymeslot.PubSub is started" do
      assert is_pid(Process.whereis(Tymeslot.PubSub))
    end

    test "Repo is started" do
      assert is_pid(Process.whereis(Tymeslot.Repo))
    end

    test "Finch is started" do
      assert is_pid(Process.whereis(Tymeslot.Finch))
    end

    test "Task.Supervisor is started" do
      assert is_pid(Process.whereis(Tymeslot.TaskSupervisor))
    end

    test "Infrastructure caches are started" do
      assert is_pid(Process.whereis(DashboardCache))
      assert is_pid(Process.whereis(AvailabilityCache))
      assert is_pid(Process.whereis(IdempotencyCache))
    end

    test "Security services are started" do
      assert is_pid(Process.whereis(RateLimiter))
      assert is_pid(Process.whereis(AccountLockout))
    end

    test "Oban is started" do
      # In test mode with testing: :manual, Oban might be registered under a different name
      # or we can check via Oban.whereis/1 using the default name.
      assert is_pid(Process.whereis(Oban)) or is_pid(Oban.whereis(Oban))
    end

    test "CircuitBreakerSupervisor is started" do
      assert is_pid(Process.whereis(Tymeslot.Infrastructure.CircuitBreakerSupervisor))
    end

    test "RequestCoalescer is started" do
      assert is_pid(Process.whereis(Tymeslot.Integrations.Calendar.RequestCoalescer))
    end
  end

  describe "email asset cache" do
    test "tymeslot_email_assets ETS table exists" do
      assert :ets.whereis(:tymeslot_email_assets) != :undefined
    end
  end
end
