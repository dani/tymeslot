defmodule Tymeslot.Availability.Conflicts do
  @moduledoc """
  Pure functions for conflict detection and slot filtering.
  """

  alias Tymeslot.Availability.{BusinessHours, TimeSlots}
  alias Tymeslot.Utils.TimeRange

  @doc """
  Filters available slots based on conflicts and booking rules.

  ## Parameters
    - all_slots: List of time slot strings
    - events: List of events in user timezone
    - duration_minutes: Meeting duration in minutes
    - timezone: User timezone
    - date: The date being checked
    - config: Configuration map with buffer_minutes, advance_booking_hours, max_advance_booking_days

  ## Returns
    List of available time slot strings
  """
  @spec filter_available_slots([String.t()], [map()], integer(), String.t(), Date.t(), map()) :: [
          String.t()
        ]
  def filter_available_slots(all_slots, events, duration_minutes, timezone, date, config \\ %{}) do
    buffer_minutes = Map.get(config, :buffer_minutes, 15)
    min_advance_hours = Map.get(config, :min_advance_hours, 3)
    advance_booking_minutes = min_advance_hours * 60
    max_advance_booking_days = Map.get(config, :max_advance_booking_days, 90)

    # Get current time in the same timezone as the slots
    current_time = DateTime.shift_zone!(DateTime.utc_now(), timezone)
    minimum_booking_time = DateTime.add(current_time, advance_booking_minutes, :minute)
    maximum_booking_time = DateTime.add(current_time, max_advance_booking_days * 24 * 60, :minute)

    Enum.filter(all_slots, fn slot ->
      # Parse the slot time and create datetime
      slot_time = TimeSlots.parse_time_slot(slot)
      slot_start = create_datetime_safe(date, slot_time, timezone)
      slot_end = DateTime.add(slot_start, duration_minutes, :minute)

      # Check all booking constraints
      meets_advance_buffer?(slot_start, minimum_booking_time) and
        meets_max_advance?(slot_start, maximum_booking_time) and
        no_event_conflict?(slot_start, slot_end, events, buffer_minutes)
    end)
  end

  @doc """
  Checks if two time ranges overlap.
  Delegates to the shared TimeRange utility.
  """
  defdelegate events_overlap?(slot_start, slot_end, event_start, event_end),
    to: TimeRange,
    as: :overlaps?

  @doc """
  Converts a list of events to a specific timezone.
  """
  @spec convert_events_to_timezone(list(map()), String.t()) :: list(map())
  def convert_events_to_timezone(events, timezone) do
    Enum.map(events, fn event ->
      case {DateTime.shift_zone(event.start_time, timezone),
            DateTime.shift_zone(event.end_time, timezone)} do
        {{:ok, start_tz}, {:ok, end_tz}} ->
          %{event | start_time: start_tz, end_time: end_tz}

        _ ->
          event
      end
    end)
  end

  @doc """
  Checks if a date has available slots given pre-fetched events.
  Used for efficient month view checking.
  """
  @spec date_has_slots_with_events?(Date.t(), String.t(), String.t(), [map()], map()) :: boolean()
  def date_has_slots_with_events?(
        date,
        owner_timezone,
        user_timezone,
        events_in_user_tz,
        config \\ %{}
      ) do
    buffer_minutes = Map.get(config, :buffer_minutes, 15)
    min_advance_hours = Map.get(config, :min_advance_hours, 3)
    profile_id = Map.get(config, :profile_id)

    # Get current time in user timezone
    current_time =
      case DateTime.shift_zone(DateTime.utc_now(), user_timezone) do
        {:ok, dt} -> dt
        _ -> DateTime.shift_zone!(DateTime.utc_now(), "Etc/UTC")
      end

    minimum_booking_time = DateTime.add(current_time, min_advance_hours * 60, :minute)

    # Check if this is today
    today = DateTime.to_date(current_time)
    is_today = date == today

    # Pre-filter events to only those that could potentially overlap with the 3-day window.
    # We use a +/- 2 day window to be safe with timezone shifts.
    start_date_limit = Date.add(date, -2)
    end_date_limit = Date.add(date, 2)

    relevant_events =
      Enum.filter(events_in_user_tz, fn event ->
        event_start_date = DateTime.to_date(event.start_time)
        event_end_date = DateTime.to_date(event.end_time)

        not (Date.compare(event_end_date, start_date_limit) == :lt or
               Date.compare(event_start_date, end_date_limit) == :gt)
      end)

    params = %{
      target_date: date,
      profile_id: profile_id,
      owner_tz: owner_timezone,
      user_tz: user_timezone,
      is_today: is_today,
      min_booking_time: minimum_booking_time,
      events: relevant_events,
      buffer: buffer_minutes
    }

    # Check the selected date and adjacent days in owner's timezone
    Enum.any?([Date.add(date, -1), date, Date.add(date, 1)], fn d ->
      check_day_for_slots(d, params)
    end)
  end

  defp check_day_for_slots(d, params) do
    # Look up business hours for this specific day
    {start_time, end_time} =
      if params.profile_id do
        BusinessHours.business_hours_range(params.profile_id, Date.day_of_week(d))
      else
        BusinessHours.business_hours_range()
      end

    if is_nil(start_time) or is_nil(end_time) do
      false
    else
      # Create datetime range in owner's timezone for this specific date
      owner_start = create_datetime_safe(d, start_time, params.owner_tz)
      owner_end = create_datetime_safe(d, end_time, params.owner_tz)

      # Convert to user's timezone
      case {DateTime.shift_zone(owner_start, params.user_tz),
            DateTime.shift_zone(owner_end, params.user_tz)} do
        {{:ok, user_start}, {:ok, user_end}} ->
          # Only proceed if this owner-day's window actually intersects with the user's selected date
          if DateTime.to_date(user_start) == params.target_date or
               DateTime.to_date(user_end) == params.target_date do
            check_window_availability(
              user_end,
              params.is_today,
              params.min_booking_time,
              params.events,
              user_start,
              params.buffer
            )
          else
            false
          end

        _ ->
          false
      end
    end
  end

  defp check_window_availability(user_end, is_today, min_booking_time, events, user_start, buffer) do
    # For today, check if the business hours end is still in the future
    # (accounting for minimum advance booking time)
    if is_today and DateTime.compare(user_end, min_booking_time) != :gt do
      # All slots for today have passed (end of business hours < minimum booking time)
      false
    else
      # Check if any event blocks the entire business day window
      # Pre-calculate bounds to avoid DateTime.add in the loop
      start_bound = DateTime.add(user_start, buffer, :minute)
      end_bound = DateTime.add(user_end, -buffer, :minute)

      not Enum.any?(events, fn event ->
        # Check if this event covers the entire business hours window
        # Equivalent to: event.start - buffer <= user_start AND event.end + buffer >= user_end
        DateTime.compare(event.start_time, start_bound) != :gt and
          DateTime.compare(event.end_time, end_bound) != :lt
      end)
    end
  end

  # Private functions

  defp meets_advance_buffer?(slot_start, minimum_booking_time) do
    DateTime.compare(slot_start, minimum_booking_time) != :lt
  end

  defp meets_max_advance?(slot_start, maximum_booking_time) do
    DateTime.compare(slot_start, maximum_booking_time) != :gt
  end

  defp no_event_conflict?(slot_start, slot_end, events, buffer_minutes) do
    not TimeRange.has_conflict_with_events?(slot_start, slot_end, events, buffer_minutes)
  end

  defp create_datetime_safe(date, time, timezone) do
    case DateTime.new(date, time, timezone) do
      {:ok, datetime} ->
        datetime

      {:ambiguous, first, _second} ->
        # For DST transitions, we consistently pick the first occurrence (usually the one before the fold)
        first

      {:error, _reason} ->
        # Fallback to UTC if timezone is invalid or time doesn't exist (DST gap)
        DateTime.new!(date, time, "Etc/UTC")
    end
  end
end
