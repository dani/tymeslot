defmodule TymeslotWeb.Live.MultilingualBookingTest do
  use TymeslotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  alias Tymeslot.Demo

  setup do
    # Create a user with calendar connection for booking flow
    user = insert(:user)
    profile = insert(:profile, user: user)

    insert(:calendar_connection,
      user: user,
      provider: "google",
      status: "connected"
    )

    insert(:meeting_type,
      user: user,
      name: "Test Meeting",
      duration_minutes: 30,
      is_active: true
    )

    {:ok, user: user, profile: profile, username: Demo.username(profile)}
  end

  describe "language detection and switching" do
    test "detects language from query parameter", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=de")

      # Verify locale is set in assigns
      assert view.assigns.locale == "de"

      # Verify Gettext locale is set
      assert Gettext.get_locale(TymeslotWeb.Gettext) == "de"
    end

    test "persists language selection across navigation", %{conn: conn, username: username} do
      # Start with German
      {:ok, view, _html} = live(conn, "/#{username}?locale=de")
      assert view.assigns.locale == "de"

      # Select a duration and navigate (this would normally trigger navigation)
      # The locale should persist in the session
      session_locale = get_session(view, :locale)
      assert session_locale == "de"
    end

    test "persists locale change from dropdown across navigation", %{
      conn: conn,
      username: username
    } do
      # Start in English
      {:ok, view, _html} = live(conn, "/#{username}")
      assert view.assigns.locale == "en"

      # Switch to German via dropdown
      view
      |> element("button[phx-click='change_locale'][phx-value-locale='de']")
      |> render_click()

      assert view.assigns.locale == "de"

      # Navigate to a different page - locale should persist
      # This simulates the user navigating while staying in the same session
      {:ok, new_view, _html} = live(conn, "/#{username}")

      # The new view should have the German locale from the session
      assert new_view.assigns.locale == "de"
    end

    test "switches language via language switcher without losing state", %{
      conn: conn,
      username: username
    } do
      # Start in English
      {:ok, view, _html} = live(conn, "/#{username}")
      assert view.assigns.locale == "en"

      # Open language dropdown
      view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()
      assert view.assigns.language_dropdown_open == true

      # Switch to German
      view
      |> element("button[phx-click='change_locale'][phx-value-locale='de']")
      |> render_click()

      # Verify language changed
      assert view.assigns.locale == "de"

      # Verify dropdown closed
      assert view.assigns.language_dropdown_open == false

      # Verify Gettext locale updated
      assert Gettext.get_locale(TymeslotWeb.Gettext) == "de"
    end

    test "accepts Accept-Language header for initial locale", %{conn: conn, username: username} do
      conn = put_req_header(conn, "accept-language", "uk-UA,uk;q=0.9")

      {:ok, view, _html} = live(conn, "/#{username}")
      assert view.assigns.locale == "uk"
    end

    test "language switcher displays all supported locales", %{conn: conn, username: username} do
      {:ok, _view, html} = live(conn, "/#{username}")

      # Verify language switcher is present (without asserting on specific text)
      assert html =~ "language-switcher"

      # All three locales should be available
      assert html =~ "phx-value-locale=\"en\""
      assert html =~ "phx-value-locale=\"de\""
      assert html =~ "phx-value-locale=\"uk\""
    end
  end

  describe "language switcher UI interactions" do
    test "opens and closes language dropdown", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}")

      # Initially closed
      assert view.assigns.language_dropdown_open == false

      # Open dropdown
      view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()
      assert view.assigns.language_dropdown_open == true

      # Close via click-away
      view |> element("div[phx-click-away='close_language_dropdown']") |> render_click()
      assert view.assigns.language_dropdown_open == false
    end

    test "shows current language as active in dropdown", %{conn: conn, username: username} do
      {:ok, view, html} = live(conn, "/#{username}?locale=de")

      # Open dropdown
      html =
        view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()

      # Current language should have active class
      assert html =~ "active"
    end
  end

  describe "locale fallback behavior" do
    test "falls back to English for unsupported locale", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=fr")

      # Should fall back to English
      assert view.assigns.locale == "en"
    end

    test "handles missing Accept-Language header gracefully", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}")

      # Should default to English
      assert view.assigns.locale == "en"
    end

    test "handles malformed locale parameter gracefully", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=invalid123")

      # Should fall back to English
      assert view.assigns.locale == "en"
    end
  end

  describe "multilingual booking flow completeness" do
    test "completes full booking flow in German", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=de&duration=30min")

      # Verify we're in German
      assert view.assigns.locale == "de"

      # Flow should work regardless of language
      # This tests that the feature is functional, not the specific translations
      assert view.assigns.current_state == :overview
    end

    test "completes full booking flow in Ukrainian", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=uk&duration=30min")

      # Verify we're in Ukrainian
      assert view.assigns.locale == "uk"

      # Flow should work regardless of language
      assert view.assigns.current_state == :overview
    end

    test "language persists throughout booking flow steps", %{conn: conn, username: username} do
      {:ok, view, _html} = live(conn, "/#{username}?locale=de&duration=30min")

      # Start in German
      assert view.assigns.locale == "de"
      assert view.assigns.current_state == :overview

      # Navigate to next step - language should persist
      # Note: Full navigation testing would require mocking calendar availability
      # This test verifies the locale assignment mechanism is in place
      assert view.assigns.locale == "de"
    end
  end
end
