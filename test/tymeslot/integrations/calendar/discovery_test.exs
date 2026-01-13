defmodule Tymeslot.Integrations.Calendar.DiscoveryTest do
  use Tymeslot.DataCase, async: true

  alias Tymeslot.Integrations.Calendar.Discovery
  import Tymeslot.Factory
  import Mox

  setup :verify_on_exit!

  describe "discover_calendars_for_integration/1" do
    test "discovers for google provider" do
      integration = insert(:calendar_integration, provider: "google")

      expect(GoogleCalendarAPIMock, :list_calendars, fn _ ->
        {:ok, [%{"id" => "primary", "summary" => "Primary", "primary" => true}]}
      end)

      assert {:ok, calendars} = Discovery.discover_calendars_for_integration(integration)
      assert length(calendars) == 1
      assert Enum.at(calendars, 0).name == "Primary"
    end

    test "discovers for outlook provider" do
      integration = insert(:calendar_integration, provider: "outlook")

      expect(OutlookCalendarAPIMock, :list_calendars, fn _ ->
        {:ok, [%{"id" => "cal1", "name" => "Outlook", "isDefaultCalendar" => true}]}
      end)

      assert {:ok, calendars} = Discovery.discover_calendars_for_integration(integration)
      assert length(calendars) == 1
      assert Enum.at(calendars, 0).name == "Outlook"
    end

    test "handles unknown provider" do
      assert {:error, "Unknown provider: unknown"} =
               Discovery.discover_calendars_for_integration(%{provider: "unknown"})
    end
  end

  describe "discover_calendars_for_credentials/5" do
    test "returns error for unknown provider" do
      assert {:error, "Unknown provider: unknown"} =
               Discovery.discover_calendars_for_credentials(
                 :unknown,
                 "http://url",
                 "u",
                 "p"
               )
    end
  end

  describe "maybe_discover_calendars/1" do
    test "passes through non-caldav providers" do
      attrs = %{"provider" => "google"}
      assert {:ok, ^attrs} = Discovery.maybe_discover_calendars(attrs)
    end
  end
end
