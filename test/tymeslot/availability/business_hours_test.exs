defmodule Tymeslot.Availability.BusinessHoursTest do
  use ExUnit.Case, async: true
  alias Tymeslot.Availability.BusinessHours

  describe "create_datetime_safe/3" do
    test "handles standard time correctly" do
      date = ~D[2024-06-01]
      time = ~T[12:00:00]
      timezone = "Europe/London"

      dt = BusinessHours.create_datetime_safe(date, time, timezone)
      assert dt.year == 2024
      assert dt.month == 6
      assert dt.day == 1
      assert dt.hour == 12
      assert dt.time_zone == "Europe/London"
    end

    test "handles spring forward gap (non-existing time)" do
      # In Europe/London, 2024-03-31 01:00:00 moved to 02:00:00
      # 01:30:00 does not exist
      date = ~D[2024-03-31]
      time = ~T[01:30:00]
      timezone = "Europe/London"

      dt = BusinessHours.create_datetime_safe(date, time, timezone)

      # Should shift forward by 1 hour
      assert dt.hour == 2
      assert dt.minute == 30
      assert dt.time_zone == "Europe/London"
    end

    test "handles fall back ambiguity (repeated time)" do
      # In Europe/London, 2024-10-27 02:00:00 moved back to 01:00:00
      # 01:30:00 occurs twice
      date = ~D[2024-10-27]
      time = ~T[01:30:00]
      timezone = "Europe/London"

      dt = BusinessHours.create_datetime_safe(date, time, timezone)

      # Should pick the first occurrence (BST)
      assert dt.hour == 1
      assert dt.minute == 30
      assert dt.zone_abbr == "BST"
      assert dt.time_zone == "Europe/London"
    end

    test "falls back to UTC for invalid timezone" do
      date = ~D[2024-01-01]
      time = ~T[12:00:00]
      timezone = "Invalid/Timezone"

      dt = BusinessHours.create_datetime_safe(date, time, timezone)
      assert dt.time_zone == "Etc/UTC"
      assert dt.hour == 12
    end
  end
end
