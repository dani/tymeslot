defmodule TymeslotWeb.Live.Dashboard.EmbedSettingsTest do
  use TymeslotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  alias Plug.Conn
  alias Plug.Test
  alias Tymeslot.Profiles
  alias Tymeslot.Repo

  describe "embed settings component" do
    setup do
      user = insert(:user, onboarding_completed_at: DateTime.utc_now())
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

      # Security section tab panel should be hidden initially
      assert render(view) =~ "id=\"panel-security\" aria-labelledby=\"tab-security\" hidden=\"\""

      # Click to show security section tab
      view
      |> element("button#tab-security")
      |> render_click()

      # Now it should be visible (hidden attribute removed)
      refute render(view) =~ "id=\"panel-security\" aria-labelledby=\"tab-security\" hidden=\"\""
      assert has_element?(view, "input[name='allowed_domains']")
    end

    test "updates allowed domains successfully", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Show security section tab
      view |> element("button#tab-security") |> render_click()

      # Submit domains
      view
      |> form("form", %{allowed_domains: "example.com, test.org"})
      |> render_submit()

      # Check for success message
      assert render(view) =~ "Security settings saved successfully"

      # Verify domains were saved
      updated_profile = Repo.reload(profile)
      assert length(updated_profile.allowed_embed_domains) == 2
      assert "example.com" in updated_profile.allowed_embed_domains
      assert "test.org" in updated_profile.allowed_embed_domains
    end

    test "shows error for invalid domains", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button#tab-security") |> render_click()

      view
      |> form("form", %{allowed_domains: "https://example.com, invalid*.com"})
      |> render_submit()

      assert render(view) =~ "Failed to save"
      assert render(view) =~ "Invalid domain format"
    end

    test "shows error when too many domains", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button#tab-security") |> render_click()

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

      view |> element("button#tab-security") |> render_click()

    long_domain = String.duplicate("a", 256) <> ".com"

    view
    |> form("form", %{allowed_domains: long_domain})
    |> render_submit()

    assert render(view) =~ "exceed maximum length"
  end

    test "clears domains successfully", %{conn: conn, profile: profile} do
      # First set some domains
      {:ok, _} =
        Profiles.update_allowed_embed_domains(profile, ["example.com", "test.org"])

      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button#tab-security") |> render_click()

      # Should show disable button when domains are set
      assert has_element?(view, "button", "Disable Embedding")

      # Click disable
      view
      |> element("button", "Disable Embedding")
      |> render_click()

      assert render(view) =~ "Embedding is now disabled"

      # Verify domains were cleared (set to ["none"])
      updated_profile = Repo.reload(profile)
      assert updated_profile.allowed_embed_domains == ["none"]
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
      assert render(view) =~ "Inline Mode"

      # Click on popup option
      view
      |> element(".embed-option-card[phx-value-type='popup']")
      |> render_click()

      # Popup should now be selected (check for visual indicator)
      html = render(view)
      assert html =~ "Popup Mode"
    end

    test "displays username in embed code snippets", %{conn: conn, profile: profile} do
      {:ok, _view, html} = live(conn, "/dashboard/embed")

      assert html =~ profile.username
      assert html =~ "/#{profile.username}"
    end

    test "shows current domain count in UI", %{conn: conn, profile: profile} do
      {:ok, _} =
        Profiles.update_allowed_embed_domains(profile, [
          "example.com",
          "test.org",
          "subdomain.example.com"
        ])

      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button#tab-security") |> render_click()

      html = render(view)
      # Should show that 3 domains are configured
      assert html =~ "example.com, test.org, subdomain.example.com"
    end

    test "handles empty domain input", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      view |> element("button#tab-security") |> render_click()

      view
      |> form("form", %{allowed_domains: ""})
      |> render_submit()

      assert render(view) =~ "saved successfully"

      # Empty input should set domains to ["none"] (disabled)
      updated_profile = Repo.reload(Profiles.get_profile(user.id))
      assert updated_profile.allowed_embed_domains == ["none"]
    end
  end

  describe "embed preview" do
    setup do
      user = insert(:user, onboarding_completed_at: DateTime.utc_now())
      profile = insert(:profile, user: user, username: "testuser")
      # Make sure profile is ready for scheduling
      insert(:meeting_type, user: user)

      conn = log_in_user(build_conn(), user)

      {:ok, conn: conn, user: user, profile: profile}
    end

    test "shows preview when toggled", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/embed")

      # Preview should be hidden initially (it's in a tab)
      assert render(view) =~ "id=\"panel-preview\" aria-labelledby=\"tab-preview\" hidden=\"\""

      # Click to show preview tab
      view
      |> element("button#tab-preview")
      |> render_click()

      # Now preview should be visible
      refute render(view) =~ "id=\"panel-preview\" aria-labelledby=\"tab-preview\" hidden=\"\""
      assert has_element?(view, "#live-preview-container")
    end
  end

  # Helper function to log in user for tests
  defp log_in_user(conn, user) do
    session = insert(:user_session, user: user)

    conn
    |> Test.init_test_session(%{})
    |> Conn.put_session(:user_token, session.token)
  end
end
