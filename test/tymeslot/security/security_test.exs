defmodule Tymeslot.Security.SecurityTest do
  use Tymeslot.DataCase, async: false
  alias Tymeslot.Security.Security

  describe "validate_url_params/1" do
    test "returns true for safe parameters" do
      params = %{"id" => "123", "name" => "John Doe"}
      assert Security.validate_url_params(params) == true
    end

    test "returns false for dangerous patterns" do
      assert Security.validate_url_params(%{"q" => "<script>alert(1)</script>"}) == false
      assert Security.validate_url_params(%{"url" => "javascript:alert(1)"}) == false
      assert Security.validate_url_params(%{"file" => "../../../etc/passwd"}) == false
      assert Security.validate_url_params(%{"input" => "line1\nline2"}) == false
    end
  end

  describe "validate_timezone/1" do
    test "accepts valid timezones" do
      assert {:ok, "Europe/Kyiv"} = Security.validate_timezone("Europe/Kyiv")
      assert {:ok, "UTC"} = Security.validate_timezone("UTC")
      assert {:ok, "Etc/UTC"} = Security.validate_timezone("Etc/UTC")
    end

    test "rejects invalid formats" do
      assert {:error, "Invalid timezone format"} = Security.validate_timezone("InvalidTimezone")
      assert {:error, "Invalid timezone format"} = Security.validate_timezone("Europe/Kyiv/Kiev")
    end

    test "rejects non-string values" do
      assert {:error, "Invalid timezone"} = Security.validate_timezone(123)
    end
  end

  describe "validate_business_hours/2" do
    test "accepts time within business hours" do
      # 10:00 UTC in Europe/Kyiv (assuming no DST for simplicity, or just check the logic)
      # Actually it converts TO Europe/Kyiv.
      # If I give 10:00 AM UTC, it's 12:00 PM or 1:00 PM in Kyiv.
      {:ok, time} = Time.new(10, 0, 0)
      assert {:ok, _dt} = Security.validate_business_hours(time, "UTC")
    end

    test "rejects time outside business hours" do
      {:ok, time} = Time.new(22, 0, 0)
      assert {:error, "Time outside business hours"} = Security.validate_business_hours(time, "UTC")
    end
  end

  describe "validate_calendar_access/2" do
    test "allows access to current or future dates" do
      today = Date.utc_today()
      assert {:ok, ^today} = Security.validate_calendar_access(today, "user_1")

      tomorrow = Date.add(today, 1)
      assert {:ok, ^tomorrow} = Security.validate_calendar_access(tomorrow, "user_1")
    end

    test "denies access to past dates" do
      yesterday = Date.add(Date.utc_today(), -1)
      assert {:error, "Cannot query past dates"} = Security.validate_calendar_access(yesterday, "user_1")
    end

    test "denies access to dates too far in future" do
      way_future = Date.add(Date.utc_today(), 367)
      assert {:error, "Cannot query dates more than a year in advance"} = Security.validate_calendar_access(way_future, "user_1")
    end
  end

  describe "consistent_response_delay/0" do
    test "completes within reasonable time" do
      # It should sleep for 50-150ms
      {micro, :ok} = :timer.tc(fn -> Security.consistent_response_delay() end)
      assert micro >= 50_000
    end
  end
end
