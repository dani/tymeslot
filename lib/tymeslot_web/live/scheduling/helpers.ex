defmodule TymeslotWeb.Live.Scheduling.Helpers do
  @moduledoc """
  Shared helper functions for the scheduling flow.
  Contains common logic used across multiple scheduling components.
  """

  alias Tymeslot.Availability.Calculate
  alias Tymeslot.Demo
  alias Tymeslot.Integrations.Calendar
  alias Tymeslot.Security.FormValidation
  alias Tymeslot.Utils.{ContextUtils, DateTimeUtils, TimezoneUtils}
  alias TymeslotWeb.Components.FormSystem
  alias TymeslotWeb.Helpers.ClientIP

  require Logger

  import Phoenix.Component, only: [assign: 3]

  @doc """
  Handles username resolution and organizer setup.
  """
  @spec handle_username_resolution(Phoenix.LiveView.Socket.t(), String.t() | nil) ::
          Phoenix.LiveView.Socket.t()
  def handle_username_resolution(socket, nil) do
    socket
    |> store_client_ip()
    |> assign(:username_context, nil)
  end

  def handle_username_resolution(socket, username) do
    # Store client IP during username resolution to ensure it's available later
    socket = store_client_ip(socket)

    case Demo.resolve_organizer_context(username) do
      {:error, :profile_not_found} ->
        # During mount, we can't use put_flash/redirect - let the mount handle this
        socket
        |> assign(:username_context, nil)
        |> assign(:organizer_profile, nil)
        |> assign(:organizer_user_id, nil)
        |> assign(:meeting_types, [])
        |> assign(:page_title, "User Not Found")

      {:ok, context} ->
        socket
        |> assign(:username_context, context.username)
        |> assign(:organizer_profile, context.profile)
        |> assign(:organizer_user_id, context.user_id)
        |> assign(:meeting_types, context.meeting_types)
        |> assign(:page_title, context.page_title)
    end
  end

  defdelegate setup_form_state(socket, form_data \\ %{}), to: FormSystem
  defdelegate assign_form_errors(socket, errors), to: FormSystem

  @doc """
  Marks a form field as touched.
  """
  @spec mark_field_touched(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def mark_field_touched(socket, field_name) do
    assign(socket, :touched_fields, MapSet.put(socket.assigns.touched_fields, field_name))
  end

  @doc """
  Gets client IP address for rate limiting.
  Delegates to the unified ClientIP module.
  """
  @spec get_client_ip(Phoenix.LiveView.Socket.t()) :: String.t()
  def get_client_ip(socket) do
    ClientIP.get(socket)
  end

  @doc """
  Stores client IP in socket assigns during mount.
  Should be called during mount to capture IP for later use.
  """
  @spec store_client_ip(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def store_client_ip(socket) do
    ip = ClientIP.get(socket)
    assign(socket, :client_ip, ip)
  end

  @doc """
  Validates if form is complete and valid.
  """
  @spec form_valid?(Phoenix.HTML.Form.t()) :: boolean()
  def form_valid?(form) do
    case FormValidation.validate_booking_form(form.source) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets available slots for a specific date.
  """
  @spec get_available_slots(
          String.t(),
          String.t(),
          String.t(),
          integer(),
          map(),
          map() | nil
        ) :: {:ok, [map()]} | {:error, any()}
  def get_available_slots(
        date_string,
        duration,
        user_timezone,
        organizer_user_id,
        organizer_profile,
        context \\ nil
      ) do
    # Security: Ensure user_id matches the profile owner to prevent IDOR
    if organizer_profile && organizer_user_id != organizer_profile.user_id do
      {:error, :unauthorized}
    else
      with {:ok, date} <- Date.from_iso8601(date_string),
           {:ok, owner_timezone} <- get_owner_timezone(organizer_profile) do
        # Check if this is a demo user
        if demo_user?(organizer_profile) || ContextUtils.get_from_context(context, :demo_mode) do
          # Use demo provider for availability generation
          Demo.get_available_slots(
            date_string,
            duration,
            user_timezone,
            organizer_user_id,
            organizer_profile,
            context
          )
        else
          # Regular flow for real users
          with {:ok, events} <-
                 Calendar.get_calendar_events_from_context(
                   date,
                   organizer_user_id,
                   context
                 ),
               duration_minutes <- parse_duration_minutes(duration) do
            config = %{
              profile_id: organizer_profile.id,
              max_advance_booking_days: organizer_profile.advance_booking_days,
              min_advance_hours: organizer_profile.min_advance_hours,
              buffer_minutes: organizer_profile.buffer_minutes
            }

            Calculate.available_slots(
              date,
              duration_minutes,
              user_timezone,
              owner_timezone,
              events,
              config
            )
          end
        end
      end
    end
  end

  @doc """
  Gets month availability map showing which days have actual free slots.

  This fetches calendar events for the month and calculates real availability
  including conflicts, used to grey out fully booked days.

  ## Parameters
    - user_id: The organizer's user ID
    - year: Year to check
    - month: Month to check (1-12)
    - user_timezone: Timezone of the user viewing
    - organizer_profile: Profile with booking settings
    - context: Optional context map (replacing socket)

  ## Returns
    - `{:ok, map}` where map keys are date strings ("2026-01-15") and values are booleans
    - `{:error, reason}` if calendar fetch fails
  """
  @spec get_month_availability(
          integer(),
          integer(),
          integer(),
          String.t(),
          map(),
          map() | nil
        ) :: {:ok, map()} | {:error, any()}
  def get_month_availability(
        user_id,
        year,
        month,
        user_timezone,
        organizer_profile,
        context \\ nil
      ) do
    # Security: Ensure user_id matches the profile owner to prevent IDOR
    cond do
      organizer_profile && user_id != organizer_profile.user_id ->
        {:error, :unauthorized}

      demo_user?(organizer_profile) || ContextUtils.get_from_context(context, :demo_mode) ->
        # Delegate to demo provider
        Demo.get_month_availability(
          user_id,
          year,
          month,
          user_timezone,
          organizer_profile,
          context
        )

      true ->
        with {:ok, owner_timezone} <- get_owner_timezone(organizer_profile),
             start_date <- Date.new!(year, month, 1),
             {:ok, events} <-
               Calendar.get_calendar_events_from_context(
                 start_date,
                 user_id,
                 context
               ) do
          config = %{
            profile_id: organizer_profile.id,
            max_advance_booking_days: organizer_profile.advance_booking_days,
            min_advance_hours: organizer_profile.min_advance_hours,
            buffer_minutes: organizer_profile.buffer_minutes
          }

          Calculate.month_availability(
            year,
            month,
            owner_timezone,
            user_timezone,
            events,
            config
          )
        end
    end
  end

  @doc """
  Orchestrates fetching availability for a month, either synchronously (in tests) or asynchronously.
  Updates the socket with loading states and task references.
  """
  @spec perform_availability_fetch(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def perform_availability_fetch(socket) do
    context = %{
      demo_mode: Demo.demo_mode?(socket),
      organizer_profile: socket.assigns.organizer_profile,
      debug_calendar_module: socket.private[:debug_calendar_module]
    }

    start_time = System.monotonic_time()

    socket =
      socket
      |> assign(:month_availability_map, :loading)
      |> assign(:availability_status, :loading)
      |> assign(:availability_fetch_start_time, start_time)

    if Application.get_env(:tymeslot, :environment) == :test do
      perform_sync_availability_fetch(socket, context)
    else
      perform_async_availability_fetch(socket, context)
    end
  end

  @doc """
  Safely initiates an asynchronous month availability fetch if all requirements are met.
  Cancels any existing fetch task before starting a new one.
  """
  @spec fetch_month_availability_async(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def fetch_month_availability_async(socket) do
    if can_fetch_availability?(socket) do
      socket
      |> maybe_cancel_existing_task()
      |> perform_availability_fetch()
    else
      socket
    end
  end

  @doc """
  Checks if all conditions for fetching availability are met.
  """
  @spec can_fetch_availability?(Phoenix.LiveView.Socket.t()) :: boolean()
  def can_fetch_availability?(socket) do
    socket.assigns[:organizer_user_id] &&
      socket.assigns[:organizer_profile] &&
      socket.assigns[:current_year] &&
      socket.assigns[:current_month] &&
      socket.assigns[:availability_status] != :loading
  end

  @doc """
  Cancels any existing availability fetch task.
  """
  @spec maybe_cancel_existing_task(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def maybe_cancel_existing_task(socket) do
    if old_task = socket.assigns[:availability_task] do
      duration =
        case socket.assigns[:availability_fetch_start_time] do
          nil -> "unknown"
          start -> "#{System.monotonic_time() - start}ns"
        end

      Logger.debug(
        "Cancelling previous availability fetch task due to user navigation (task was running for #{duration})",
        user_id: socket.assigns.organizer_user_id,
        month: socket.assigns.current_month,
        year: socket.assigns.current_year
      )

      Task.shutdown(old_task, :brutal_kill)
    end

    socket
  end

  @doc """
  Performs a synchronous availability fetch. Used primarily in test environments.
  """
  @spec perform_sync_availability_fetch(Phoenix.LiveView.Socket.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  def perform_sync_availability_fetch(socket, context) do
    ref = make_ref()

    case get_month_availability(
           socket.assigns.organizer_user_id,
           socket.assigns.current_year,
           socket.assigns.current_month,
           socket.assigns.user_timezone,
           socket.assigns.organizer_profile,
           context
         ) do
      {:ok, availability} -> send(self(), {ref, {:ok, availability}})
      {:error, reason} -> send(self(), {ref, {:error, reason}})
    end

    socket
    |> assign(:availability_task, nil)
    |> assign(:availability_task_ref, ref)
  end

  @doc """
  Performs an asynchronous availability fetch using Task.async.
  """
  @spec perform_async_availability_fetch(Phoenix.LiveView.Socket.t(), map()) ::
          Phoenix.LiveView.Socket.t()
  def perform_async_availability_fetch(socket, context) do
    # Extract values needed for closure to avoid capturing socket
    organizer_user_id = socket.assigns.organizer_user_id
    current_year = socket.assigns.current_year
    current_month = socket.assigns.current_month
    user_timezone = socket.assigns.user_timezone
    organizer_profile = socket.assigns.organizer_profile

    task =
      Task.async(fn ->
        get_month_availability(
          organizer_user_id,
          current_year,
          current_month,
          user_timezone,
          organizer_profile,
          context
        )
      end)

    socket
    |> assign(:availability_task, task)
    |> assign(:availability_task_ref, task.ref)
  end

  @doc """
  Gets calendar days for month view.

  ## Parameters
    - user_timezone: Timezone of the user viewing
    - year: Year to display
    - month: Month to display (1-12)
    - organizer_profile: Profile with booking settings
    - availability_map: Optional real availability data. Can be:
      - nil: Use business hours only (fast)
      - :loading: Show loading state
      - %{}: Use real conflict-aware availability
  """
  @spec get_calendar_days(String.t(), integer(), integer(), map() | nil, map() | atom() | nil) ::
          [map()]
  def get_calendar_days(user_timezone, year, month, organizer_profile, availability_map \\ nil) do
    if organizer_profile do
      if demo_user?(organizer_profile) do
        # Delegate to demo provider for calendar days
        Demo.get_calendar_days(user_timezone, year, month, organizer_profile, availability_map)
      else
        config = %{
          profile_id: organizer_profile.id,
          max_advance_booking_days: organizer_profile.advance_booking_days,
          min_advance_hours: organizer_profile.min_advance_hours,
          buffer_minutes: organizer_profile.buffer_minutes
        }

        Calculate.get_calendar_days(user_timezone, year, month, config, availability_map)
      end
    else
      # Return empty calendar days when profile is nil
      []
    end
  end

  defp parse_duration_minutes(duration) do
    case duration do
      "15min" -> 15
      "30min" -> 30
      _ -> 30
    end
  end

  defp get_owner_timezone(organizer_profile) do
    {:ok, organizer_profile.timezone || "Europe/Kyiv"}
  end

  defp demo_user?(profile) do
    Demo.demo_profile?(profile)
  end

  @doc """
  Handles previous month navigation.
  """
  @spec handle_prev_month(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def handle_prev_month(socket) do
    current_month = socket.assigns.current_month
    current_year = socket.assigns.current_year

    {prev_year, prev_month} =
      if current_month == 1, do: {current_year - 1, 12}, else: {current_year, current_month - 1}

    socket
    |> assign(:current_month, prev_month)
    |> assign(:current_year, prev_year)
    |> update_calendar_data()
  end

  @doc """
  Handles next month navigation.
  """
  @spec handle_next_month(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def handle_next_month(socket) do
    current_month = socket.assigns.current_month
    current_year = socket.assigns.current_year

    {next_year, next_month} =
      if current_month == 12, do: {current_year + 1, 1}, else: {current_year, current_month + 1}

    socket
    |> assign(:current_month, next_month)
    |> assign(:current_year, next_year)
    |> update_calendar_data()
  end

  @doc """
  Handles timezone change.
  """
  @spec handle_timezone_change(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_timezone_change(socket, timezone) do
    socket
    |> assign(:user_timezone, timezone)
    |> update_calendar_data()
  end

  @doc """
  Handles timezone search.
  """
  @spec handle_timezone_search(Phoenix.LiveView.Socket.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_timezone_search(socket, search_term) do
    filtered_timezones = TimezoneUtils.get_filtered_timezone_options(search_term)
    assign(socket, :filtered_timezones, filtered_timezones)
  end

  @doc """
  Parses slot time string to DateTime for display.
  """
  @spec parse_slot_time(String.t()) :: DateTime.t()
  def parse_slot_time(slot_string) do
    case DateTimeUtils.parse_slot_time(slot_string) do
      {:ok, time} ->
        {:ok, dt} = DateTime.new(Date.utc_today(), time)
        dt

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  @doc """
  Checks if previous month navigation should be disabled.
  """
  @spec prev_month_disabled?(integer(), integer(), String.t()) :: boolean()
  def prev_month_disabled?(current_year, current_month, user_timezone) do
    today =
      case DateTime.now(user_timezone) do
        {:ok, dt} -> DateTime.to_date(dt)
        _ -> Date.utc_today()
      end

    current_year < today.year || (current_year == today.year && current_month <= today.month)
  end

  @doc """
  Checks if next month navigation should be disabled.
  """
  @spec next_month_disabled?(integer(), integer(), String.t()) :: boolean()
  def next_month_disabled?(current_year, current_month, user_timezone) do
    today =
      case DateTime.now(user_timezone) do
        {:ok, dt} -> DateTime.to_date(dt)
        _ -> Date.utc_today()
      end

    max_advance_booking_days =
      Application.get_env(:tymeslot, :scheduling)[:max_advance_booking_days] || 90

    max_booking_date = Date.add(today, max_advance_booking_days)

    next_month_first_day =
      if current_month == 12 do
        Date.new!(current_year + 1, 1, 1)
      else
        Date.new!(current_year, current_month + 1, 1)
      end

    Date.compare(next_month_first_day, max_booking_date) == :gt
  end

  defp update_calendar_data(socket) do
    %{
      current_month: current_month,
      current_year: current_year,
      user_timezone: user_timezone,
      organizer_profile: organizer_profile
    } = socket.assigns

    # Use availability map if present, otherwise nil (will use business hours only)
    availability_map = Map.get(socket.assigns, :month_availability_map)

    calendar_days =
      get_calendar_days(
        user_timezone,
        current_year,
        current_month,
        organizer_profile,
        availability_map
      )

    assign(socket, :calendar_days, calendar_days)
  end
end
