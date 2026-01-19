defmodule TymeslotWeb.Dashboard.ProfileSettingsTest do
  use TymeslotWeb.LiveCase, async: true

  import Tymeslot.Factory
  import Tymeslot.AuthTestHelpers

  alias Tymeslot.Repo

  setup %{conn: conn} do
    user = insert(:user, onboarding_completed_at: DateTime.utc_now())
    profile = insert(:profile, user: user)
    conn = conn |> Plug.Test.init_test_session(%{}) |> fetch_session()
    conn = log_in_user(conn, user)
    {:ok, conn: conn, user: user, profile: profile}
  end

  describe "Avatar upload" do
    test "successfully uploads an avatar", %{conn: conn, profile: profile} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      # Prepare file for upload
      avatar = %{
        last_modified: System.system_time(:millisecond),
        name: "avatar.png",
        content: "fake-image-content",
        type: "image/png"
      }

      # Simulate selecting a file
      # The form helper respects phx-target
      view
      |> file_input("#avatar-upload-form", :avatar, [avatar])
      |> render_upload("avatar.png")

      # We wait for the message processing (auto-consumption)
      render(view)
      
      # Verify success message appears without manual submit
      assert render(view) =~ "Avatar updated successfully"
      
      # Verify profile was updated in DB
      updated_profile = Repo.reload!(profile)
      assert updated_profile.avatar != nil
    end

    test "does not show error when no files are provided on submit (auto-upload fallback)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")
      
      # Submit without any file selected using the form helper to respect phx-target
      view
      |> form("#avatar-upload-form", %{})
      |> render_submit()
      
      # Wait for message processing
      render(view)
      
      # Should NOT show "No file was uploaded" anymore as we silently ignore empty results
      refute render(view) =~ "No file was uploaded"
    end

    test "fails with invalid file type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      avatar = %{
        last_modified: System.system_time(:millisecond),
        name: "test.txt",
        content: "text content",
        type: "text/plain"
      }

      # Use form/file_input to respect phx-target
      view
      |> file_input("#avatar-upload-form", :avatar, [avatar])
      |> render_upload("test.txt")
      
      render(view)
      
      # Should show the humanized error message from LiveView's extension validation
      assert render(view) =~ "Not accepted"
    end

    test "successfully deletes an avatar", %{conn: conn, profile: profile} do
      # Manually set an avatar for the profile to test deletion
      # We update the database directly to bypass file system operations in update_avatar
      profile = Repo.update!(Ecto.Changeset.change(profile, avatar: "test_avatar.png"))

      {:ok, view, _html} = live(conn, ~p"/dashboard/settings")

      # Verify the delete button is visible (it only shows if profile.avatar is present)
      assert has_element?(view, "button", "Delete Photo")

      # Click the show modal button
      view
      |> element("button", "Delete Photo")
      |> render_click()

      # Click the confirm delete button in the modal
      view
      |> element("button", "Delete Avatar")
      |> render_click()

      # Verify success message
      assert render(view) =~ "Avatar deleted successfully"
      
      # Verify profile was updated in DB
      updated_profile = Repo.reload!(profile)
      assert updated_profile.avatar == nil
    end
  end
end
