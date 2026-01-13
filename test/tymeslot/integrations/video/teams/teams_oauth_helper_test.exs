defmodule Tymeslot.Integrations.Video.Teams.TeamsOAuthHelperTest do
  use Tymeslot.DataCase, async: false

  alias Tymeslot.Integrations.Common.OAuth.State
  alias Tymeslot.Integrations.Video.Teams.TeamsOAuthHelper
  import Mox

  setup :verify_on_exit!

  setup do
    # Teams helper reuses Outlook config in the code
    Application.put_env(:tymeslot, :outlook_oauth,
      client_id: "teams-id",
      client_secret: "teams-secret",
      state_secret: "teams-state"
    )

    :ok
  end

  describe "authorization_url/2" do
    test "generates valid Teams OAuth URL" do
      url = TeamsOAuthHelper.authorization_url(1, "http://uri")
      assert url =~ "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
      assert url =~ "client_id=teams-id"
      assert url =~ "scope=https%3A%2F%2Fgraph.microsoft.com%2FOnlineMeetings.ReadWrite"
    end
  end

  describe "exchange_code_for_tokens/3" do
    test "exchanges code and validates state" do
      user_id = 123
      state = State.generate(user_id, "teams-state")

      resp_body =
        Jason.encode!(%{
          "access_token" => "at-123",
          "refresh_token" => "rt-123",
          "expires_in" => 3600,
          "scope" => "OnlineMeetings.ReadWrite"
        })

      expect(Tymeslot.HTTPClientMock, :request, fn :post, _, _, _, _ ->
        {:ok, %{status_code: 200, body: resp_body}}
      end)

      assert {:ok, tokens} =
               TeamsOAuthHelper.exchange_code_for_tokens("code", "http://uri", state)

      assert tokens.access_token == "at-123"
      assert tokens.user_id == user_id
    end
  end

  describe "refresh_access_token/2" do
    test "refreshes token successfully" do
      resp_body =
        Jason.encode!(%{
          "access_token" => "new-at",
          "expires_in" => 3600
        })

      expect(Tymeslot.HTTPClientMock, :request, fn :post, _, _, _, _ ->
        {:ok, %{status_code: 200, body: resp_body}}
      end)

      assert {:ok, tokens} = TeamsOAuthHelper.refresh_access_token("old-rt")
      assert tokens.access_token == "new-at"
    end
  end

  describe "validate_token/1" do
    test "returns :valid when token is not expired" do
      future = DateTime.add(DateTime.utc_now(), 1, :hour)
      assert {:ok, :valid} = TeamsOAuthHelper.validate_token(%{token_expires_at: future})
    end

    test "returns :needs_refresh when token is close to expiry" do
      soon = DateTime.add(DateTime.utc_now(), 2, :minute)
      assert {:ok, :needs_refresh} = TeamsOAuthHelper.validate_token(%{token_expires_at: soon})
    end

    test "returns error when expiration info is missing" do
      assert {:error, _} = TeamsOAuthHelper.validate_token(%{})
    end
  end
end
