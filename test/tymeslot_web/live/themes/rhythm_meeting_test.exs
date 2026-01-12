defmodule TymeslotWeb.Live.Themes.RhythmMeetingTest do
  use TymeslotWeb.LiveCase, async: false

  import Phoenix.LiveViewTest

  alias TymeslotWeb.ThemeMeetingTestCases

  setup do
    ThemeMeetingTestCases.setup_theme_meeting(%{
      user_name: "John Doe",
      theme_id: "2",
      username: "john",
      color_scheme: "purple",
      background_value: "gradient_1",
      start_time: ~U[2026-01-20 10:00:00Z],
      duration: 30
    })
  end

  describe "Cancel Confirmed Page" do
    setup %{conn: conn, profile: profile, meeting: meeting} do
      ThemeMeetingTestCases.setup_cancel_confirmed_view(conn, profile, meeting)
    end

    test "renders and handles navigation", %{view: view} do
      ThemeMeetingTestCases.test_cancel_confirmed_page(view)
    end
  end

  describe "Reschedule Page" do
    setup %{conn: conn, profile: profile, meeting: meeting} do
      ThemeMeetingTestCases.setup_reschedule_view(conn, profile, meeting)
    end

    test "renders the reschedule page with rhythm style and meeting details", %{view: view} do
      ThemeMeetingTestCases.test_reschedule_page_rendering(view)

      # Check meeting details
      assert render(view) =~ "January 20, 2026"
      assert render(view) =~ "10:00 AM"
      assert render(view) =~ "John Doe"
      assert render(view) =~ "30 min"

      # Check for the action button
      assert has_element?(view, "button", "Go to Calendar")
    end

    test "Go to Calendar button navigates back to profile", %{
      view: view,
      profile: profile
    } do
      ThemeMeetingTestCases.test_reschedule_page_navigation(
        view,
        "Go to Calendar",
        profile.username
      )
    end
  end
end
