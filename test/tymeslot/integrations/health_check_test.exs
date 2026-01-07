defmodule Tymeslot.Integrations.HealthCheckTest do
  use Tymeslot.DataCase, async: false

  import Tymeslot.Factory
  import Mox

  alias Tymeslot.Integrations.HealthCheck
  alias Tymeslot.DatabaseQueries.CalendarIntegrationQueries

  setup do
    # Start the GenServer with initial_delay: 0 to disable automatic checks
    {:ok, pid} = HealthCheck.start_link(check_interval: 1_000_000, initial_delay: 0)
    
    # Allow the HealthCheck process to use mocks defined in the test process
    Mox.allow(GoogleCalendarAPIMock, self(), pid)
    Mox.allow(Tymeslot.HTTPClientMock, self(), pid)

    on_exit(fn ->
      if Process.alive?(pid) do
        Process.exit(pid, :kill)
      end
    end)

    {:ok, pid: pid}
  end

  describe "integration health monitoring" do
    test "deactivates integration after repeated failures" do
      user = insert(:user)
      integration = insert(:calendar_integration, user: user, is_active: true, provider: "google")
      test_pid = self()

      # Mock failure for 3 checks (threshold is 3)
      # We use fn -> send(...) end to synchronize
      expect(GoogleCalendarAPIMock, :list_primary_events, 3, fn _int, _start, _end ->
        send(test_pid, :mock_called)
        {:error, :unauthorized, "Token expired"}
      end)

      # 1st failure
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      status = HealthCheck.get_health_status(:calendar, integration.id)
      assert status.status == :degraded
      assert status.failures == 1

      # 2nd failure
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      status = HealthCheck.get_health_status(:calendar, integration.id)
      assert status.status == :degraded
      assert status.failures == 2

      # 3rd failure
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      status = HealthCheck.get_health_status(:calendar, integration.id)
      assert status.status == :unhealthy
      assert status.failures == 3

      # Verify it was deactivated in DB
      {:ok, updated} = CalendarIntegrationQueries.get(integration.id)
      refute updated.is_active
    end

    test "recovers integration after repeated successes" do
      user = insert(:user)
      integration = insert(:calendar_integration, user: user, is_active: true, provider: "google")
      test_pid = self()

      # Initial failure to make it degraded
      expect(GoogleCalendarAPIMock, :list_primary_events, 1, fn _int, _start, _end ->
        send(test_pid, :mock_called)
        {:error, :unauthorized}
      end)
      
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      assert HealthCheck.get_health_status(:calendar, integration.id).status == :degraded

      # Mock success for 2 checks (recovery threshold is 2)
      expect(GoogleCalendarAPIMock, :list_primary_events, 2, fn _int, _start, _end ->
        send(test_pid, :mock_called)
        {:ok, []}
      end)

      # 1st success
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      assert HealthCheck.get_health_status(:calendar, integration.id).status == :degraded

      # 2nd success
      HealthCheck.check_all_integrations()
      assert_receive :mock_called, 1000
      sync_with_server()
      assert HealthCheck.get_health_status(:calendar, integration.id).status == :healthy
    end
  end

  describe "user health report" do
    test "builds correct report for user" do
      user = insert(:user)
      c1 = insert(:calendar_integration, user: user, provider: "google")
      v1 = insert(:video_integration, user: user, provider: "mirotalk")
      test_pid = self()

      # Mock success for both
      expect(GoogleCalendarAPIMock, :list_primary_events, 1, fn _int, _start, _end -> 
        send(test_pid, :calendar_mock_called)
        {:ok, []} 
      end)
      
      stub(Tymeslot.HTTPClientMock, :post, fn _url, _body, _headers, _opts -> 
        send(test_pid, :video_mock_called)
        {:ok, %HTTPoison.Response{status_code: 200}}
      end)

      HealthCheck.check_all_integrations()
      assert_receive :calendar_mock_called, 1000
      assert_receive :video_mock_called, 1000
      sync_with_server()

      report = HealthCheck.get_user_health_report(user.id)
      
      assert length(report.calendar_integrations) == 1
      assert Enum.any?(report.calendar_integrations, &(&1.id == c1.id))
      
      assert length(report.video_integrations) == 1
      assert Enum.any?(report.video_integrations, &(&1.id == v1.id))
      
      assert is_map(report.summary)
    end
  end

  # Helper to ensure the GenServer has finished processing its message queue
  defp sync_with_server do
    _ = :sys.get_state(HealthCheck)
  end
end
