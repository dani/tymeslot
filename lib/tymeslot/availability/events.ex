defmodule Tymeslot.Availability.Events do
  @moduledoc """
  Pure functions for event processing and timezone conversion.
  """

  alias Tymeslot.Utils.DateTimeUtils

  @doc """
  Converts a list of events to a specific timezone.
  Handles both DateTime (normal) and Date (all-day) events.
  """
  @spec convert_events_to_timezone(list(map()), String.t()) :: list(map())
  def convert_events_to_timezone(events, timezone) do
    Enum.map(events, fn event ->
      # Convert start_time and end_time, potentially upgrading Date to DateTime
      start_dt = ensure_datetime(event.start_time, timezone)
      end_dt = ensure_datetime(event.end_time, timezone)

      case {shift_safe(start_dt, timezone), shift_safe(end_dt, timezone)} do
        {{:ok, s}, {:ok, e}} ->
          %{event | start_time: s, end_time: e}

        _ ->
          # If we can't shift (e.g. invalid timezone), keep original
          event
      end
    end)
  end

  defp ensure_datetime(%DateTime{} = dt, _timezone), do: dt

  defp ensure_datetime(%Date{} = d, timezone) do
    # All-day event: starts at 00:00:00 in the target timezone
    DateTimeUtils.create_datetime_safe(d, ~T[00:00:00], timezone)
  end

  defp ensure_datetime(nil, _timezone), do: nil
  defp ensure_datetime(_, _timezone), do: nil

  defp shift_safe(nil, _timezone), do: {:error, nil}

  defp shift_safe(%DateTime{} = dt, timezone) do
    if dt.time_zone == timezone do
      {:ok, dt}
    else
      DateTime.shift_zone(dt, timezone)
    end
  rescue
    _ -> {:error, :invalid_timezone}
  end
end
