defmodule TymeslotWeb.Live.Themes.AvailabilityRefinementTest do
  use TymeslotWeb.LiveCase, async: false

  import Mox
  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  alias Tymeslot.Security.RateLimiter
  alias Tymeslot.TestMocks

  setup :verify_on_exit!

  setup do
    Mox.set_mox_global()
    ensure_rate_limiter_started()
    RateLimiter.clear_all()

    TestMocks.setup_email_mocks()
    TestMocks.setup_calendar_mocks()

    :ok
  end

  describe "Quill theme availability refinement" do
    test "refines availability based on calendar conflicts", %{conn: conn} do
      Ecto.Adapters.SQL.Sandbox.mode(Tymeslot.Repo, {:shared, self()})
      timezone = "America/New_York"
      user = insert(:user)

      profile =
        insert(:profile,
          user: user,
          username: "refinement-test",
          booking_theme: "1",
          timezone: timezone,
          advance_booking_days: 30,
          min_advance_hours: 0,
          buffer_minutes: 0
        )

      _meeting_type =
        insert(:meeting_type,
          user: user,
          duration_minutes: 30,
          name: "Refinement Chat",
          is_active: true
        )

      Enum.each(1..7, fn day_of_week ->
        insert(:weekly_availability,
          profile: profile,
          day_of_week: day_of_week,
          is_available: true,
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        )
      end)

      insert(:calendar_integration, user: user, is_active: true)

      target_date = Date.add(Date.utc_today(), 2)
      date_str = Date.to_string(target_date)

      stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _start, _end ->
        {:ok,
         [
           %{
             uid: "busy-day",
             start_time: DateTime.new!(target_date, ~T[00:00:00], timezone),
             end_time: DateTime.new!(target_date, ~T[23:59:59], timezone)
           }
         ]}
      end)

      {:ok, view, _html} =
        live(conn, ~p"/#{profile.username}/schedule/30min?timezone=#{timezone}")

      wait_until(fn ->
        render(view) =~ "data-date=\"#{date_str}\"" and
          has_element?(
            view,
            "button[data-testid='calendar-day'][phx-value-date='#{date_str}'][disabled]"
          )
      end)

      assert has_element?(
               view,
               "button[data-testid='calendar-day'][phx-value-date='#{date_str}'][disabled]"
             )
    end

    test "greys out today if business hours have passed", %{conn: conn} do
      Ecto.Adapters.SQL.Sandbox.mode(Tymeslot.Repo, {:shared, self()})
      timezone = "Etc/GMT-14"
      user = insert(:user)

      profile =
        insert(:profile,
          user: user,
          booking_theme: "1",
          timezone: timezone,
          username: "today-grey-test"
        )

      _meeting_type = insert(:meeting_type, user: user, duration_minutes: 30, is_active: true)
      insert(:calendar_integration, user: user, is_active: true)

      now_in_tz = DateTime.shift_zone!(DateTime.utc_now(), timezone)
      today_in_tz = DateTime.to_date(now_in_tz)
      today_str = Date.to_string(today_in_tz)

      {:ok, view, _html} =
        live(conn, ~p"/#{profile.username}/schedule/30min?timezone=#{timezone}")

      if now_in_tz.hour >= 17 do
        wait_until(fn ->
          has_element?(
            view,
            "button[data-testid='calendar-day'][phx-value-date='#{today_str}'][disabled]"
          )
        end)
      end
    end

    test "communicates failure when calendar fetch fails", %{conn: conn} do
      user = insert(:user)
      profile = insert(:profile, user: user, username: "failure-test", booking_theme: "1")
      _meeting_type = insert(:meeting_type, user: user, duration_minutes: 30, is_active: true)
      insert(:calendar_integration, user: user, is_active: true)

      stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _, _, _ ->
        {:error, :timeout}
      end)

      {:ok, view, _html} = live(conn, ~p"/#{profile.username}/schedule/30min")

      wait_until(fn ->
        html = render(view)
        html =~ "Calendar is loading slowly" || html =~ "Calendar service is slow"
      end)
    end
  end

  describe "Rhythm theme availability refinement" do
    test "Rhythm theme refines availability based on calendar conflicts", %{conn: conn} do
      timezone = "America/New_York"
      user = insert(:user)

      profile =
        insert(:profile,
          user: user,
          username: "refinement-rhythm",
          booking_theme: "2",
          timezone: timezone,
          advance_booking_days: 30,
          min_advance_hours: 0,
          buffer_minutes: 0
        )

      _meeting_type =
        insert(:meeting_type,
          user: user,
          duration_minutes: 30,
          name: "Rhythm Chat",
          is_active: true
        )

      Enum.each(1..7, fn day_of_week ->
        insert(:weekly_availability,
          profile: profile,
          day_of_week: day_of_week,
          is_available: true,
          start_time: ~T[09:00:00],
          end_time: ~T[17:00:00]
        )
      end)

      insert(:calendar_integration, user: user, is_active: true)

      # Target tomorrow to ensure it's definitely in the current week view
      target_date = Date.add(Date.utc_today(), 1)
      date_str = Date.to_string(target_date)

      stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _start, _end ->
        {:ok,
         [
           %{
             uid: "busy-day",
             start_time: DateTime.new!(target_date, ~T[00:00:00], timezone),
             end_time: DateTime.new!(target_date, ~T[23:59:59], timezone)
           }
         ]}
      end)

      {:ok, view, _html} = live(conn, ~p"/#{profile.username}?timezone=#{timezone}")

      view
      |> element("button[data-testid='duration-option'][data-duration='30']")
      |> render_click()

      view
      |> element("button[data-testid='next-step']")
      |> render_click()

      wait_until(fn ->
        html = render(view)

        html =~ "data-date=\"#{date_str}\"" and
          has_element?(
            view,
            "button[data-testid='calendar-day'][phx-value-date='#{date_str}'][disabled]"
          )
      end)
    end
  end

  # --- Helpers ---

  defp wait_until(predicate, timeout_ms \\ 10_000, interval_ms \\ 50) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait_until(predicate, deadline, interval_ms)
  end

  defp do_wait_until(predicate, deadline, interval_ms) do
    if predicate.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("Timed out waiting for UI condition")
      end

      Process.sleep(interval_ms)
      do_wait_until(predicate, deadline, interval_ms)
    end
  end

  defp ensure_rate_limiter_started do
    case Process.whereis(Tymeslot.Security.RateLimiter) do
      nil -> start_supervised!(Tymeslot.Security.RateLimiter)
      _pid -> :ok
    end
  end
end
