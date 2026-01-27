defmodule Tymeslot.Workers.IntegrationHealthWorkerTest do
  use Tymeslot.DataCase, async: false

  use Oban.Testing, repo: Tymeslot.Repo
  import Tymeslot.Factory
  import Mox

  alias Tymeslot.Integrations.HealthCheck
  alias Tymeslot.Workers.IntegrationHealthWorker

  setup do
    {:ok, pid} = HealthCheck.start_link(check_interval: 1_000_000, initial_delay: 0)

    Mox.set_mox_global()

    on_exit(fn ->
      Mox.set_mox_private()

      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end)

    {:ok, pid: pid}
  end

  test "discards invalid arguments" do
    job = %Oban.Job{args: %{"type" => "calendar"}}

    assert {:discard, "Invalid arguments"} = IntegrationHealthWorker.perform(job)
  end

  test "discards invalid integration type" do
    job = %Oban.Job{args: %{"type" => "unknown", "integration_id" => 1}}

    assert {:discard, "Invalid integration type"} = IntegrationHealthWorker.perform(job)
  end

  test "returns ok when health check reports error" do
    user = insert(:user)
    integration = insert(:calendar_integration, user: user, is_active: true, provider: "google")
    test_pid = self()

    expect(GoogleCalendarAPIMock, :list_primary_events, 1, fn _int, _start, _end ->
      send(test_pid, :mock_called)
      {:error, :timeout}
    end)

    job = %Oban.Job{args: %{"type" => "calendar", "integration_id" => integration.id}, id: 1}

    assert :ok = IntegrationHealthWorker.perform(job)
    assert_receive :mock_called, 1000
    _ = :sys.get_state(HealthCheck, 5000)

    status = HealthCheck.get_health_status(:calendar, integration.id)
    assert status.status == :degraded
    assert status.failures == 1
  end
end
