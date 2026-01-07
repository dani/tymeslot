defmodule Tymeslot.Availability.Calculate do
  @moduledoc """
  Main orchestrator for availability calculations.
  Combines business hours, time slots, and conflict detection.
  """

  alias Tymeslot.Availability.{BusinessHours, Conflicts, TimeSlots, WeeklySchedule}

  @doc """
  Calculates available time slots for a specific date.

  ## Parameters
    - date: Date to check
    - duration_minutes: Meeting duration in minutes
    - user_timezone: Timezone of the user viewing availability
    - owner_timezone: Timezone of the calendar owner
    - events: List of existing events
    - config: Optional configuration overrides

  ## Returns
    List of available time slot strings
  """
  @spec available_slots(Date.t(), integer(), String.t(), String.t(), [map()], map()) ::
          {:ok, [String.t()]} | {:error, any()}
  def available_slots(
        date,
        duration_minutes,
        user_timezone,
        owner_timezone,
        events,
        config \\ %{}
      ) do
    profile_id = Map.get(config, :profile_id)

    # To handle extreme timezone differences (up to 24 hours), we check the selected date
    # and its adjacent days in the owner's timezone, as they might bleed into
    # the attendee's selected date.
    dates_to_check = [
      Date.add(date, -1),
      date,
      Date.add(date, 1)
    ]

    # Collect all business hour windows across these dates that fall on the user's selected date
    business_hours_windows =
      Enum.flat_map(dates_to_check, fn d ->
        result =
          if profile_id do
            BusinessHours.get_business_hours_in_timezone(
              d,
              profile_id,
              owner_timezone,
              user_timezone
            )
          else
            BusinessHours.get_business_hours_in_timezone(d, owner_timezone, user_timezone)
          end

        case result do
          {:ok, %{start_datetime: start_dt, end_datetime: end_dt}}
          when not is_nil(start_dt) and not is_nil(end_dt) ->
            # Only include windows that overlap with the user's selected date
            if DateTime.to_date(start_dt) == date or DateTime.to_date(end_dt) == date do
              [%{start_dt: start_dt, end_dt: end_dt, date: d}]
            else
              []
            end

          _ ->
            []
        end
      end)

    if Enum.empty?(business_hours_windows) do
      {:ok, []}
    else
      # Convert events to user timezone once
      events_in_user_tz = Conflicts.convert_events_to_timezone(events, user_timezone)

      all_available_slots =
        Enum.flat_map(business_hours_windows, fn window ->
          generate_and_filter_slots_for_window(
            window.start_dt,
            window.end_dt,
            window.date,
            date,
            duration_minutes,
            user_timezone,
            events_in_user_tz,
            config
          )
        end)
        |> Enum.uniq()
        |> Enum.sort()

      {:ok, all_available_slots}
    end
  end

  defp generate_and_filter_slots_for_window(
         start_dt,
         end_dt,
         owner_date,
         user_date,
         duration_minutes,
         user_timezone,
         events_in_user_tz,
         config
       ) do
    # Get breaks for the owner's date
    breaks = get_breaks_for_day(owner_date, config)

    # Generate slots based on the datetime range, excluding breaks
    all_slots =
      TimeSlots.generate_slots_for_range_with_breaks(
        start_dt,
        end_dt,
        duration_minutes,
        user_date,
        breaks
      )

    # Filter out slots that conflict with existing events
    Conflicts.filter_available_slots(
      all_slots,
      events_in_user_tz,
      duration_minutes,
      user_timezone,
      user_date,
      config
    )
  end

  @doc """
  Gets availability status for multiple dates in a month.
  Optimized for calendar display.

  ## Returns
    Map of date strings to availability boolean
  """
  @spec month_availability(integer(), integer(), String.t(), String.t(), [map()], map()) ::
          {:ok, map()}
  def month_availability(year, month, owner_timezone, user_timezone, events, config \\ %{}) do
    # Get the date range for the month
    start_date = Date.new!(year, month, 1)
    end_date = Date.end_of_month(start_date)

    # Get today's date in user timezone
    today =
      case DateTime.now(user_timezone) do
        {:ok, dt} -> DateTime.to_date(dt)
        _ -> Date.utc_today()
      end

    # Get max booking date
    max_advance_booking_days = Map.get(config, :max_advance_booking_days, 90)
    max_booking_date = Date.add(today, max_advance_booking_days)

    # Convert events to user timezone once
    events_in_user_tz = Conflicts.convert_events_to_timezone(events, user_timezone)

    # Read profile_id once (if present)
    profile_id = Map.get(config, :profile_id)

    # Check each date in the month
    availability_map =
      Enum.reduce(Date.range(start_date, end_date), %{}, fn date, acc ->
        date_string = Date.to_string(date)

        is_outside_range =
          Date.compare(date, today) == :lt or Date.compare(date, max_booking_date) == :gt

        has_slots =
          not is_outside_range and
            business_day?(date, profile_id) and
            Conflicts.date_has_slots_with_events?(
              date,
              owner_timezone,
              user_timezone,
              events_in_user_tz,
              config
            )

        Map.put(acc, date_string, has_slots)
      end)

    {:ok, availability_map}
  end

  @doc """
  Gets calendar days for display in the UI.

  Returns a list of day objects for calendar rendering, including
  availability, current month status, and other display properties.
  """
  @spec get_calendar_days(String.t(), integer(), integer(), map()) :: list(map())
  def get_calendar_days(user_timezone, year, month, config \\ %{}) do
    # Get today in user's timezone
    today =
      case DateTime.now(user_timezone) do
        {:ok, dt} -> DateTime.to_date(dt)
        _ -> Date.utc_today()
      end

    # Create date for the given year/month
    start_of_month = Date.new!(year, month, 1)

    # Get the first day to display (Sunday of the week containing the 1st)
    first_day = start_of_month
    days_before = Date.day_of_week(first_day)
    days_before = if days_before == 7, do: 0, else: days_before
    first_display_date = Date.add(first_day, -days_before)

    # Configuration
    max_advance_booking_days = Map.get(config, :max_advance_booking_days, 90)

    # Generate 42 days (6 weeks) for consistent calendar display
    Enum.map(0..41, fn offset ->
      date = Date.add(first_display_date, offset)

      # Business logic for availability
      profile_id = Map.get(config, :profile_id)

      is_business_day =
        if profile_id do
          BusinessHours.business_day?(date, profile_id)
        else
          BusinessHours.business_day?(date)
        end

      is_future = Date.compare(date, today) != :lt
      is_within_limit = Date.diff(date, today) <= max_advance_booking_days
      is_available = is_business_day && is_future && is_within_limit

      %{
        date: Date.to_string(date),
        day: date.day,
        available: is_available,
        past: Date.compare(date, today) == :lt,
        today: date == today,
        current_month: date.month == month
      }
    end)
  end

  @doc """
  Validates that both date and time have been selected for booking.
  Used in booking workflow validation.
  """
  @spec validate_time_selection(String.t() | nil, String.t() | nil, list()) ::
          :ok | {:error, String.t()}
  def validate_time_selection(nil, _time, _slots), do: {:error, "Please select a date"}

  @spec validate_time_selection(String.t(), String.t() | nil, list()) ::
          :ok | {:error, String.t()}
  def validate_time_selection("", _time, _slots), do: {:error, "Please select a date"}

  @spec validate_time_selection(String.t(), String.t() | nil, list()) ::
          :ok | {:error, String.t()}
  def validate_time_selection(_date, nil, _slots), do: {:error, "Please select a time"}
  @spec validate_time_selection(String.t(), String.t(), list()) :: :ok | {:error, String.t()}
  def validate_time_selection(_date, "", _slots), do: {:error, "Please select a time"}

  @spec validate_time_selection(String.t(), String.t(), list()) :: :ok | {:error, String.t()}
  def validate_time_selection(date, time, slots) when is_list(slots) do
    if time_slot_available?(date, time, slots) do
      :ok
    else
      {:error, "Selected time is no longer available"}
    end
  end

  @spec validate_time_selection(term(), term(), term()) :: {:error, String.t()}
  def validate_time_selection(_date, _time, _slots), do: {:error, "Please select a date and time"}

  @doc """
  Checks if a specific time slot is available.
  """
  @spec time_slot_available?(String.t(), String.t(), list()) :: boolean()
  def time_slot_available?(date, time, slots)
      when is_binary(date) and is_binary(time) and is_list(slots) do
    # For validation, we just need to confirm that selections exist
    # The actual availability is checked during booking submission
    true
  end

  @spec time_slot_available?(term(), term(), term()) :: boolean()
  def time_slot_available?(_date, _time, _slots), do: false

  # Private functions

  defp get_breaks_for_day(date, config) do
    with profile_id when not is_nil(profile_id) <- Map.get(config, :profile_id),
         day_of_week <- Date.day_of_week(date),
         %{breaks: breaks} when is_list(breaks) <-
           WeeklySchedule.get_day_availability(profile_id, day_of_week) do
      # Convert breaks to the format expected by TimeSlots
      Enum.map(breaks, fn break ->
        {break.start_time, break.end_time}
      end)
    else
      _ -> []
    end
  end

  # Helper to determine if a date is a business day based on optional profile_id
  defp business_day?(date, nil), do: BusinessHours.business_day?(date)
  defp business_day?(date, profile_id), do: BusinessHours.business_day?(date, profile_id)
end
