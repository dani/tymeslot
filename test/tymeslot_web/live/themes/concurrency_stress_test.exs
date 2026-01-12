defmodule TymeslotWeb.Live.Themes.ConcurrencyStressTest do
  @moduledoc """
  Integration tests simulating rapid user interaction to verify stability of 
  asynchronous availability fetching and task management.
  """
  use TymeslotWeb.LiveCase, async: false

  import Mox
  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  alias Ecto.Adapters.SQL.Sandbox
  alias Tymeslot.Infrastructure.AvailabilityCache
  alias Tymeslot.Repo
  alias Tymeslot.Security.RateLimiter
  alias Tymeslot.TestMocks

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()
    Sandbox.mode(Repo, {:shared, self()})

    case Process.whereis(RateLimiter) do
      nil -> start_supervised!(RateLimiter)
      _pid -> :ok
    end

    RateLimiter.clear_all()

    TestMocks.setup_email_mocks()
    TestMocks.setup_calendar_mocks()
    AvailabilityCache.clear_all()

    user = insert(:user)
    # Use a unique username for each test run to avoid cache/state leakage
    username = "stress-test-#{System.unique_integer([:positive])}"
    profile = insert(:profile, user: user, username: username, booking_theme: "1")
    insert(:meeting_type, user: user, duration_minutes: 30, is_active: true)
    insert(:meeting_type, user: user, duration_minutes: 60, is_active: true)
    insert(:calendar_integration, user: user, is_active: true)

    # Set some business hours
    Enum.each(1..7, fn day_of_week ->
      insert(:weekly_availability, profile: profile, day_of_week: day_of_week, is_available: true)
    end)

    {:ok, user: user, profile: profile}
  end

  test "rapid month navigation cancels previous tasks without crashing", %{
    conn: conn,
    profile: profile
  } do
    # Stub calendar to be slow (delay 100ms)
    stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _start, _end ->
      Process.sleep(100)
      {:ok, []}
    end)

    {:ok, view, _html} = live(conn, ~p"/#{profile.username}/schedule/30min")

    # Click 'next_month' rapidly 2 times (to avoid hitting max advance booking days)
    # Each click should trigger a new task and cancel the previous one
    Enum.each(1..2, fn _ ->
      view |> element("button[phx-click='next_month']") |> render_click()
    end)

    # Use wait_until instead of sleep for robustness
    wait_until(fn ->
      # UI should still be responsive and showing the correct month
      # We just want to check it's not in :loading state anymore
      not (render(view) =~ "calendar-day--loading")
    end)
  end

  test "rapid duration switching cancels previous tasks", %{conn: conn, profile: profile} do
    # Stub calendar to be slow
    stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _start, _end ->
      Process.sleep(100)
      {:ok, []}
    end)

    {:ok, view, _html} = live(conn, ~p"/#{profile.username}")

    # Rapidly switch between 30min and 60min
    # Use render_click since they might not have data-testid or might be in a list
    Enum.each(1..3, fn _ ->
      view
      |> element("button[phx-click='select_duration'][phx-value-duration='30min']")
      |> render_click()

      view
      |> element("button[phx-click='select_duration'][phx-value-duration='60min']")
      |> render_click()
    end)

    # Ensure no crashes occurred and we can proceed to schedule
    view |> element("button[phx-click='next_step']") |> render_click()

    wait_until(fn ->
      render(view) =~ "Select a Date"
    end)
  end

  test "handles calendar service failure gracefully", %{conn: conn, profile: profile} do
    # Force calendar fetch to return error
    stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _start, _end ->
      {:error, :service_unavailable}
    end)

    # Invalidate cache to ensure it hits the mock
    AvailabilityCache.clear_all()

    {:ok, view, _html} = live(conn, ~p"/#{profile.username}/schedule/30min")

    # Wait for async task to complete and flash to appear
    wait_until(fn ->
      html = render(view)

      html =~ "Calendar is loading slowly" or
        html =~ "Calendar service is slow"
    end)
  end
end
