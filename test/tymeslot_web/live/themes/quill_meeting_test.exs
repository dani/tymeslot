defmodule TymeslotWeb.Live.Themes.QuillMeetingTest do
  use TymeslotWeb.LiveCase, async: false

  import Phoenix.LiveViewTest

  alias TymeslotWeb.ThemeMeetingTestCases

  setup do
    ThemeMeetingTestCases.setup_theme_meeting(%{
      user_name: "Jane Smith",
      theme_id: "1",
      username: "jane",
      color_scheme: "turquoise",
      background_value: "gradient_2",
      start_time: ~U[2026-02-15 14:00:00Z],
      duration: 45
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

    test "renders the reschedule page with quill style and meeting details", %{view: view} do
      ThemeMeetingTestCases.test_reschedule_page_rendering(view)

      # Check meeting details
      assert render(view) =~ "February 15, 2026"
      assert render(view) =~ "02:00 PM"
      assert render(view) =~ "Jane Smith"
      assert render(view) =~ "45 min"
    end

    test "Choose New Time button navigates back to profile", %{
      view: view,
      profile: profile
    } do
      ThemeMeetingTestCases.test_reschedule_page_navigation(
        view,
        "Choose New Time",
        profile.username
      )
    end
  end
end
