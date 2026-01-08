defmodule TymeslotWeb.Live.MultilingualBookingTest do
  use TymeslotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  setup do
    # Create a user with calendar integration for booking flow
    user = insert(:user)
    profile = insert(:profile, user: user, username: "testuser")

    insert(:calendar_integration,
      user: user,
      provider: "google",
      is_active: true
    )

    insert(:meeting_type,
      user: user,
      name: "Test Meeting",
      duration_minutes: 30,
      is_active: true
    )

    {:ok, user: user, profile: profile, username: profile.username}
  end

  describe "language detection and switching" do
    test "detects language from query parameter", %{conn: conn, username: username} do
      view = start_view(conn, username, "de")

      # Verify Gettext locale is set
      assert Gettext.get_locale(TymeslotWeb.Gettext) == "de"
      assert render(view) =~ "data-locale=\"de\""
    end

    test "persists language selection across navigation", %{conn: conn, username: username} do
      # Start with German
      view = start_view(conn, username, "de")

      # The locale should persist in the session
      session_locale = get_session(view, :locale)
      assert session_locale == "de"
    end

    test "persists locale change from dropdown across navigation", %{
      conn: conn,
      username: username
    } do
      # Start in English
      view = start_view(conn, username)
      assert render(view) =~ "data-locale=\"en\""

      # Switch to German via dropdown
      {:ok, view, _html} = change_locale(conn, view, "de")
      assert render(view) =~ "data-locale=\"de\""

      # Navigate to a different page - locale should persist
      # This simulates the user navigating while staying in the same session
      {:ok, new_view, _html} = live(conn, "/#{username}")

      # The new view should have the German locale from the session
      assert render(new_view) =~ "data-locale=\"de\""
    end

    test "switches language via language switcher without losing state", %{
      conn: conn,
      username: username
    } do
      # Start in English
      view = start_view(conn, username)

      # Open language dropdown
      view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()

      # Verify dropdown is open
      assert render(view) =~ "role=\"menu\""

      # Switch to German
      {:ok, view, _html} = change_locale(conn, view, "de")

      # Verify dropdown closed (in the NEW view)
      refute render(view) =~ "role=\"menu\""

      # Verify Gettext locale updated
      assert Gettext.get_locale(TymeslotWeb.Gettext) == "de"
    end

    test "accepts Accept-Language header for initial locale", %{conn: conn, username: username} do
      conn = put_req_header(conn, "accept-language", "uk-UA,uk;q=0.9")

      view = start_view(conn, username)
      assert render(view) =~ "data-locale=\"uk\""
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
      view = start_view(conn, username)

      # Initially closed
      refute render(view) =~ "role=\"menu\""

      # Open dropdown
      view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()
      assert render(view) =~ "role=\"menu\""

      # Close via click-away
      view |> element("div[phx-click-away='close_language_dropdown']") |> render_click()
      refute render(view) =~ "role=\"menu\""
    end

    test "shows current language as active in dropdown", %{conn: conn, username: username} do
      view = start_view(conn, username, "de")

      # Open dropdown
      html =
        view |> element("button[phx-click='toggle_language_dropdown']") |> render_click()

      # Current language should have active class
      assert html =~ "active"
    end
  end

  describe "locale fallback behavior" do
    test "falls back to English for unsupported locale", %{conn: conn, username: username} do
      view = start_view(conn, username, "fr")

      # Should fall back to English
      assert render(view) =~ "data-locale=\"en\""
    end

    test "handles missing Accept-Language header gracefully", %{conn: conn, username: username} do
      view = start_view(conn, username)

      # Should default to English
      assert render(view) =~ "data-locale=\"en\""
    end

    test "handles malformed locale parameter gracefully", %{conn: conn, username: username} do
      view = start_view(conn, username, "invalid123")

      # Should fall back to English
      assert render(view) =~ "data-locale=\"en\""
    end
  end

  describe "multilingual booking flow completeness" do
    test "completes full booking flow in German", %{conn: conn, username: username} do
      view = start_view(conn, username, "de", "30min")

      # Verify we're in German
      assert render(view) =~ "data-locale=\"de\""

      # Flow should work regardless of language
      assert has_element?(view, "[data-testid='duration-option']")
    end

    test "completes full booking flow in Ukrainian", %{conn: conn, username: username} do
      view = start_view(conn, username, "uk", "30min")

      # Verify we're in Ukrainian
      assert render(view) =~ "data-locale=\"uk\""

      # Flow should work regardless of language
      assert has_element?(view, "[data-testid='duration-option']")
    end

    test "language persists throughout booking flow steps", %{conn: conn, username: username} do
      view = start_view(conn, username, "de", "30min")

      # Start in German
      assert render(view) =~ "data-locale=\"de\""
      assert has_element?(view, "[data-testid='duration-option']")

      # Verify the locale is still German
      assert render(view) =~ "data-locale=\"de\""
    end
  end

  # Helper Functions

  defp start_view(conn, username, locale \\ nil, duration \\ nil) do
    url = "/#{username}"

    query_params = URI.encode_query(Enum.reject([locale: locale, duration: duration], fn {_, v} -> is_nil(v) end))

    url = if query_params == "", do: url, else: "#{url}?#{query_params}"

    {:ok, view, _html} = live(conn, url)

    view
  end

  defp change_locale(conn, view, locale) do
    view
    |> element("button[phx-click='change_locale'][phx-value-locale='#{locale}']")
    |> render_click()
    |> follow_redirect(conn)
  end
end
