defmodule Tymeslot.Integrations.VideoTest do
  use Tymeslot.DataCase, async: true

  import Tymeslot.Factory
  import Mox

  alias Tymeslot.Integrations.Video

  setup :verify_on_exit!

  describe "list_integrations/1" do
    test "returns all video integrations for a user" do
      user = insert(:user)
      insert(:video_integration, user: user, provider: "google_meet")
      insert(:video_integration, user: user, provider: "teams")

      integrations = Video.list_integrations(user.id)
      assert length(integrations) == 2
    end
  end

  describe "create_integration/3" do
    test "creates a video integration" do
      user = insert(:user)
      attrs = %{
        name: "My Meet",
        access_token: "token",
        refresh_token: "refresh",
        provider: "google_meet"
      }

      assert {:ok, integration} = Video.create_integration(user.id, :google_meet, attrs)
      assert integration.user_id == user.id
      assert integration.provider == "google_meet"
    end

    test "normalizes provider name" do
      user = insert(:user)
      attrs = %{
        name: "My Meet",
        access_token: "token",
        refresh_token: "refresh"
      }

      assert {:ok, integration} = Video.create_integration(user.id, "GOOGLE_MEET", attrs)
      assert integration.provider == "google_meet"
    end

    test "validates mirotalk connection before creation" do
      user = insert(:user)
      attrs = %{
        name: "Miro",
        api_key: "test_key",
        base_url: "https://mirotalk.com"
      }

      # Stub HTTPClient for Mirotalk connection test
      stub(Tymeslot.HTTPClientMock, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{}"}}
      end)

      assert {:ok, integration} = Video.create_integration(user.id, :mirotalk, attrs)
      assert integration.provider == "mirotalk"
    end
  end

  describe "delete_integration/2" do
    test "deletes the integration" do
      user = insert(:user)
      integration = insert(:video_integration, user: user)

      assert {:ok, :deleted} = Video.delete_integration(user.id, integration.id)
      assert [] = Video.list_integrations(user.id)
    end

    test "returns error if not found" do
      user = insert(:user)
      assert {:error, :not_found} = Video.delete_integration(user.id, 999)
    end
  end

  describe "toggle_integration/2" do
    test "toggles active status" do
      user = insert(:user)
      integration = insert(:video_integration, user: user, is_active: true)

      assert {:ok, toggled} = Video.toggle_integration(user.id, integration.id)
      refute toggled.is_active

      assert {:ok, toggled_back} = Video.toggle_integration(user.id, integration.id)
      assert toggled_back.is_active
    end
  end

  describe "set_default/2" do
    test "sets integration as default and unsets others" do
      user = insert(:user)
      i1 = insert(:video_integration, user: user, provider: "google_meet", is_default: true, access_token: "t1", refresh_token: "r1")
      i2 = insert(:video_integration, user: user, provider: "teams", is_default: false, tenant_id: "t", client_id: "c", client_secret: "s", teams_user_id: "u")

      assert {:ok, updated_i2} = Video.set_default(user.id, i2.id)
      assert updated_i2.is_default

      # Verify i1 is no longer default
      integrations = Video.list_integrations(user.id)
      updated_i1 = Enum.find(integrations, &(&1.id == i1.id))
      refute updated_i1.is_default
    end
  end

  describe "create_meeting_room/1" do
    test "returns error when no active integration" do
      user = insert(:user)
      assert {:error, message} = Video.create_meeting_room(user.id)
      assert String.contains?(message, "No video integration configured")
    end

    test "creates room with default provider" do
      user = insert(:user)
      insert(:video_integration,
        user: user,
        provider: "mirotalk",
        is_default: true,
        is_active: true,
        api_key: "test_key",
        base_url: "https://mirotalk.com"
      )

      stub(Tymeslot.HTTPClientMock, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "{\"meeting\": \"https://mirotalk.com/room123\"}"}}
      end)

      assert {:ok, room} = Video.create_meeting_room(user.id)
      assert room.provider_type == :mirotalk
      assert room.room_data.room_id == "https://mirotalk.com/room123"
    end
  end
end
