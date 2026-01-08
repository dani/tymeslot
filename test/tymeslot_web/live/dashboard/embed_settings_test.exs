defmodule TymeslotWeb.Live.Dashboard.EmbedSettingsTest do
  use TymeslotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  describe "embed settings component" do
    setup do
      user = insert(:user)
      profile = insert(:profile, user: user, username: "testuser", allowed_embed_domains: [])

      conn = log_in_user(build_conn(), user)

      {:ok, conn: conn, user: user, profile: profile}
    end

    test "displays embed options", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      assert has_element?(view, "div", "Inline Embed")
      assert has_element?(view, "div", "Popup Modal")
      assert has_element?(view, "div", "Direct Link")
      assert has_element?(view, "div", "Floating Button")
    end

    test "shows security section when toggled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Security section should be hidden initially
      refute has_element?(view, "input[name='allowed_domains']")

      # Click to show security section
      view
      |> element("button", "Configure")
      |> render_click()

      # Now it should be visible
      assert has_element?(view, "input[name='allowed_domains']")
    end

    test "updates allowed domains successfully", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Show security section
      view |> element("button", "Configure") |> render_click()

      # Submit domains
      view
      |> form("form", %{allowed_domains: "example.com, test.org"})
      |> render_submit()

      # Check for success message
      assert render(view) =~ "Security settings saved successfully"

      # Verify domains were saved
      updated_profile = Tymeslot.Repo.reload(profile)
      assert length(updated_profile.allowed_embed_domains) == 2
      assert "example.com" in updated_profile.allowed_embed_domains
      assert "test.org" in updated_profile.allowed_embed_domains
    end

    test "shows error for invalid domains", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      view
      |> form("form", %{allowed_domains: "https://example.com, invalid*.com"})
      |> render_submit()

      assert render(view) =~ "Failed to save"
      assert render(view) =~ "invalid domains"
    end

    test "shows error when too many domains", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      # Create 21 domains
      many_domains = for i <- 1..21, do: "example#{i}.com"
      domains_str = Enum.join(many_domains, ", ")

      view
      |> form("form", %{allowed_domains: domains_str})
      |> render_submit()

      assert render(view) =~ "cannot have more than 20"
    end

    test "shows error for domain exceeding 255 characters", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      long_domain = String.duplicate("a", 256) <> ".com"

      view
      |> form("form", %{allowed_domains: long_domain})
      |> render_submit()

      assert render(view) =~ "exceed maximum length"
    end

    test "clears domains successfully", %{conn: conn, profile: profile} do
      # First set some domains
      {:ok, _} =
        Tymeslot.Profiles.update_allowed_embed_domains(profile, ["example.com", "test.org"])

      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      # Should show clear button when domains are set
      assert has_element?(view, "button", "Clear & Allow All")

      # Click clear
      view
      |> element("button", "Clear & Allow All")
      |> render_click()

      assert render(view) =~ "Embedding is now allowed on all domains"

      # Verify domains were cleared
      updated_profile = Tymeslot.Repo.reload(profile)
      assert updated_profile.allowed_embed_domains == []
    end

    test "copies embed code to clipboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Click copy button for inline embed
      view
      |> element("button[phx-click='copy_code'][phx-value-type='inline']")
      |> render_click()

      assert render(view) =~ "Code copied to clipboard"
    end

    test "switches between embed types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Initially inline should be selected
      assert render(view) =~ "Inline Embed"

      # Click on popup option
      view
      |> element("div[phx-click='select_embed_type'][phx-value-type='popup']")
      |> render_click()

      # Popup should now be selected (check for visual indicator)
      html = render(view)
      assert html =~ "popup"
    end

    test "displays username in embed code snippets", %{conn: conn, profile: profile} do
      {:ok, view, html} = live(conn, "/dashboard/embed")

      assert html =~ "data-username=\"#{profile.username}\""
      assert html =~ "/#{profile.username}"
    end

    test "rate limits domain updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      # Submit 11 times (limit is 10 per hour)
      for i <- 1..11 do
        view
        |> form("form", %{allowed_domains: "example#{i}.com"})
        |> render_submit()

        # Small delay to ensure rate limiter can track
        Process.sleep(10)
      end

      # The 11th request should be rate limited
      html = render(view)
      assert html =~ "Too many updates" or html =~ "wait a moment"
    end

    test "shows current domain count in UI", %{conn: conn, profile: profile} do
      {:ok, _} =
        Tymeslot.Profiles.update_allowed_embed_domains(profile, [
          "example.com",
          "test.org",
          "subdomain.example.com"
        ])

      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      html = render(view)
      # Should show that 3 domains are configured
      assert html =~ "example.com, test.org, subdomain.example.com"
    end

    test "handles empty domain input", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button", "Configure") |> render_click()

      view
      |> form("form", %{allowed_domains: ""})
      |> render_submit()

      assert render(view) =~ "saved successfully"

      # Empty should clear domains
      updated_profile = Tymeslot.Repo.reload(Tymeslot.Profiles.get_profile(conn.assigns.current_user.id))
      assert updated_profile.allowed_embed_domains == []
    end
  end

  describe "embed preview" do
    setup do
      user = insert(:user)
      profile = insert(:profile, user: user, username: "testuser")
      # Make sure profile is ready for scheduling
      insert(:meeting_type, profile: profile)

      conn = log_in_user(build_conn(), user)

      {:ok, conn: conn, user: user, profile: profile}
    end

    test "shows preview when toggled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Preview should be hidden initially
      refute has_element?(view, "#live-preview-container")

      # Click to show preview
      view
      |> element("button", "Show Preview")
      |> render_click()

      # Now preview should be visible
      assert has_element?(view, "#live-preview-container")
    end

    test "hides preview when toggled off", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Show preview
      view |> element("button", "Show Preview") |> render_click()
      assert has_element?(view, "#live-preview-container")

      # Hide preview
      view |> element("button", "Hide Preview") |> render_click()
      refute has_element?(view, "#live-preview-container")
    end
  end

  # Helper function to log in user for tests
  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
  end
end
