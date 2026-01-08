defmodule Tymeslot.Integrations.Calendar.Outlook.CalendarAPITest do
  use Tymeslot.DataCase, async: true

  import Tymeslot.Factory
  import Mox

  alias Tymeslot.Integrations.Calendar.Outlook.CalendarAPI
  alias Tymeslot.Security.Encryption

  setup :verify_on_exit!

  describe "list_calendars/1" do
    test "returns list of calendars when successful" do
      user = insert(:user)

      integration =
        insert(:calendar_integration,
          user: user,
          provider: "outlook",
          access_token_encrypted: Encryption.encrypt("valid_token"),
          token_expires_at: DateTime.add(DateTime.utc_now(), 3600)
        )

      expect(Tymeslot.HTTPClientMock, :request, fn :get, url, _body, headers, _opts ->
        assert String.starts_with?(url, "https://graph.microsoft.com/v1.0/me/calendars")

        assert Enum.any?(headers, fn {k, v} ->
                 String.downcase(k) == "authorization" and v == "Bearer valid_token"
               end)

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "value" => [%{"id" => "cal1", "name" => "Work Calendar"}]
             })
         }}
      end)

      assert {:ok, [%{"id" => "cal1"}]} = CalendarAPI.list_calendars(integration)
    end
  end

  describe "list_events/4" do
    test "fetches events for a specific calendar and date range" do
      user = insert(:user)

      integration =
        insert(:calendar_integration,
          user: user,
          provider: "outlook",
          access_token_encrypted: Encryption.encrypt("valid_token"),
          token_expires_at: DateTime.add(DateTime.utc_now(), 3600)
        )

      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, 3600)

      expect(Tymeslot.HTTPClientMock, :request, fn :get, url, _body, _headers, _opts ->
        assert String.contains?(url, "/me/calendars/test-cal/events")
        assert String.contains?(url, "%24filter=")

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "value" => [
                 %{
                   "id" => "event1",
                   "subject" => "Meeting",
                   "isCancelled" => false,
                   "start" => %{"dateTime" => "2024-01-01T10:00:00"},
                   "end" => %{"dateTime" => "2024-01-01T11:00:00"}
                 }
               ]
             })
         }}
      end)

      assert {:ok, [%{id: "event1"}]} =
               CalendarAPI.list_events(integration, "test-cal", start_time, end_time)
    end
  end

  describe "refresh_token/1" do
    test "calls Microsoft token endpoint and returns new tokens" do
      user = insert(:user)

      integration =
        insert(:calendar_integration,
          user: user,
          provider: "outlook",
          refresh_token_encrypted: Encryption.encrypt("old_refresh_token")
        )

      Application.put_env(:tymeslot, :outlook_oauth, client_id: "client", client_secret: "secret")

      expect(Tymeslot.HTTPClientMock, :request, fn :post, url, body, _headers, _opts ->
        assert url == "https://login.microsoftonline.com/common/oauth2/v2.0/token"
        assert String.contains?(body, "grant_type=refresh_token")
        assert String.contains?(body, "refresh_token=old_refresh_token")

        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "access_token" => "new_access_token",
               "refresh_token" => "new_refresh_token",
               "expires_in" => 3600
             })
         }}
      end)

      assert {:ok, {"new_access_token", "new_refresh_token", %DateTime{}}} =
               CalendarAPI.refresh_token(integration)
    end
  end
end
