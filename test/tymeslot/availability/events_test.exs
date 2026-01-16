defmodule Tymeslot.Availability.EventsTest do
  @moduledoc """
  Tests for the Events module - event processing and timezone conversion.
  """

  use ExUnit.Case, async: true
  alias Tymeslot.Availability.Events

  describe "convert_events_to_timezone/2" do
    test "converts events from UTC to Eastern timezone" do
      events = [
        %{
          start_time: ~U[2025-06-15 14:00:00Z],
          end_time: ~U[2025-06-15 15:00:00Z]
        }
      ]

      converted = Events.convert_events_to_timezone(events, "America/New_York")

      assert length(converted) == 1
      event = hd(converted)
      # UTC 14:00 = Eastern 10:00 AM (during EDT)
      assert event.start_time.time_zone == "America/New_York"
      assert event.end_time.time_zone == "America/New_York"
    end

    test "converts multiple events" do
      events = [
        %{
          start_time: ~U[2025-06-15 10:00:00Z],
          end_time: ~U[2025-06-15 11:00:00Z]
        },
        %{
          start_time: ~U[2025-06-15 14:00:00Z],
          end_time: ~U[2025-06-15 15:00:00Z]
        }
      ]

      converted = Events.convert_events_to_timezone(events, "Europe/London")

      assert length(converted) == 2

      for event <- converted do
        assert event.start_time.time_zone == "Europe/London"
        assert event.end_time.time_zone == "Europe/London"
      end
    end

    test "handles empty events list" do
      assert Events.convert_events_to_timezone([], "America/New_York") == []
    end

    test "preserves other event fields" do
      events = [
        %{
          start_time: ~U[2025-06-15 14:00:00Z],
          end_time: ~U[2025-06-15 15:00:00Z],
          title: "Test Meeting",
          uid: "test-uid-123"
        }
      ]

      converted = Events.convert_events_to_timezone(events, "America/New_York")

      event = hd(converted)
      assert event.title == "Test Meeting"
      assert event.uid == "test-uid-123"
    end

    test "handles all-day events (Date)" do
      events = [
        %{
          start_time: ~D[2025-06-15],
          end_time: ~D[2025-06-16]
        }
      ]

      converted = Events.convert_events_to_timezone(events, "America/New_York")

      assert length(converted) == 1
      event = hd(converted)
      assert %DateTime{} = event.start_time
      assert %DateTime{} = event.end_time
      assert event.start_time.time_zone == "America/New_York"
      assert event.start_time.hour == 0
      assert event.start_time.minute == 0
    end
  end
end
