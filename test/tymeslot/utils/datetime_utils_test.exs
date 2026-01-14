defmodule Tymeslot.Utils.DateTimeUtilsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Tymeslot.Utils.DateTimeUtils

  describe "parse_duration/1" do
    test "parses time durations (PT)" do
      assert {:ok, 3600} == DateTimeUtils.parse_duration("PT1H")
      assert {:ok, 90} == DateTimeUtils.parse_duration("PT1M30S")
      assert {:ok, 5400} == DateTimeUtils.parse_duration("PT1H30M")
      assert {:ok, 3661} == DateTimeUtils.parse_duration("PT1H1M1S")
    end

    test "parses day and week durations (P)" do
      assert {:ok, 86400} == DateTimeUtils.parse_duration("P1D")
      assert {:ok, 604800} == DateTimeUtils.parse_duration("P1W")
      assert {:ok, 691200} == DateTimeUtils.parse_duration("P1W1D")
    end

    test "returns error for invalid formats" do
      assert {:error, "Invalid duration format"} == DateTimeUtils.parse_duration("invalid")
      assert {:error, "Invalid duration format"} == DateTimeUtils.parse_duration("")
    end

    property "never crashes and returns either ok or error for random strings" do
      check all(s <- string(:ascii)) do
        result = DateTimeUtils.parse_duration(s)
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end

    property "correctly parses generated PT durations" do
      check all(
              h <- integer(0..1000),
              m <- integer(0..59),
              s <- integer(0..59)
            ) do
        duration_str = "PT#{h}H#{m}M#{s}S"
        expected_seconds = h * 3600 + m * 60 + s
        assert {:ok, ^expected_seconds} = DateTimeUtils.parse_duration(duration_str)
      end
    end

    property "correctly parses generated P durations" do
      check all(
              w <- integer(0..52),
              d <- integer(0..31)
            ) do
        duration_str = "P#{w}W#{d}D"
        expected_seconds = w * 604800 + d * 86400
        assert {:ok, ^expected_seconds} = DateTimeUtils.parse_duration(duration_str)
      end
    end
    
    test "handles unsupported P components gracefully (e.g. months)" do
      # Now returns error for unsupported components because of regex anchors
      assert {:error, _} = DateTimeUtils.parse_duration("P1M")
      assert {:error, _} = DateTimeUtils.parse_duration("P1Y")
    end
  end
end
