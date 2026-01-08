defmodule TymeslotWeb.Themes.Rhythm.Scheduling.Components.ScheduleComponent do
  @moduledoc """
  Rhythm theme component for the schedule (date/time selection) step.
  Extracted from the monolithic RhythmSlidesComponent to improve separation of concerns.
  """
  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Availability.BusinessHours
  alias Tymeslot.Demo
  alias Tymeslot.Profiles
  alias Tymeslot.Utils.TimezoneUtils
  alias TymeslotWeb.Live.Scheduling.Helpers
  alias TymeslotWeb.Themes.Shared.LocalizationHelpers

  @impl true
  def update(assigns, socket) do
    filtered_assigns = Map.drop(assigns, [:flash, :socket])

    today = Date.utc_today()
    week_start = Date.beginning_of_week(today, :monday)

    {:ok,
     socket
     |> assign(filtered_assigns)
     |> assign_new(:current_week_start, fn -> week_start end)
     |> assign_new(:timezone_dropdown_open, fn -> false end)
     |> assign_new(:timezone_search, fn -> "" end)}
  end

  @impl true
  def handle_event("select_date", %{"date" => date}, socket) do
    new_date = if socket.assigns[:selected_date] == date, do: nil, else: date

    socket =
      socket
      |> assign(:selected_date, new_date)
      |> assign(:selected_time, nil)

    send(self(), {:step_event, :schedule, :select_date, %{date: new_date}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_time", %{"time" => time}, socket) do
    new_time = if socket.assigns[:selected_time] == time, do: nil, else: time
    send(self(), {:step_event, :schedule, :select_time, %{time: new_time}})
    {:noreply, assign(socket, :selected_time, new_time)}
  end

  @impl true
  def handle_event("change_timezone", %{"timezone" => timezone}, socket) do
    send(self(), {:step_event, :schedule, :change_timezone, timezone})

    {:noreply,
     socket
     |> assign(:timezone_dropdown_open, false)
     |> assign(:timezone_search, "")}
  end

  @impl true
  def handle_event("toggle_timezone_dropdown", _params, socket) do
    send(self(), {:step_event, :schedule, :toggle_timezone_dropdown, nil})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_timezone_dropdown", _params, socket) do
    {:noreply, assign(socket, :timezone_dropdown_open, false)}
  end

  @impl true
  def handle_event("search_timezone", params, socket) do
    search_term =
      case params do
        %{"search" => term} -> term
        %{"value" => term} -> term
        %{"_target" => ["search"], "search" => term} -> term
        _ -> ""
      end

    {:noreply,
     socket
     |> assign(:timezone_search, search_term)
     |> assign(:timezone_dropdown_open, true)}
  end

  @impl true
  def handle_event("prev_week", _params, socket) do
    new_week_start = Date.add(socket.assigns[:current_week_start], -7)
    {:noreply, assign(socket, :current_week_start, new_week_start)}
  end

  @impl true
  def handle_event("next_week", _params, socket) do
    new_week_start = Date.add(socket.assigns[:current_week_start], 7)
    {:noreply, assign(socket, :current_week_start, new_week_start)}
  end

  @impl true
  def handle_event("prev_slide", _params, socket) do
    send(self(), {:step_event, :schedule, :prev_step, %{}})
    {:noreply, socket}
  end

  @impl true
  def handle_event("next_slide", _params, socket) do
    send(self(), {:step_event, :schedule, :next_step, %{}})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="scheduling-box" data-locale={@locale}>
      <div class="slide-container">
        <div class="slide active">
          <div
            class="slide-content schedule-slide"
            style="display: flex; flex-direction: column; height: 100%;"
          >
            <!-- Organizer Header -->
            <div class="schedule-header" style="flex-shrink: 0;">
              <div class="organizer-profile-small">
                <img
                  src={Demo.avatar_url(@organizer_profile, :thumb)}
                  alt={Demo.avatar_alt_text(@organizer_profile)}
                  class="avatar-image-small"
                />
                <div class="organizer-info-small">
                  <div class="organizer-name">{gettext("Schedule with")}</div>
                  <div class="organizer-name-full">
                    {Profiles.display_name(@organizer_profile) || ""}
                  </div>
                  <div class="meeting-duration">{gettext("%{duration} minutes", duration: @selected_duration)}</div>
                </div>
              </div>
              <!-- Timezone Selector -->
              <div class="timezone-selector-container">
                <label class="timezone-label">{gettext("Your timezone")}:</label>
                <div class="timezone-dropdown-wrapper">
                  <button
                    class="timezone-trigger"
                    phx-click="toggle_timezone_dropdown"
                    phx-target={@myself}
                    type="button"
                  >
                    <div class="timezone-display">
                      <%= if country_code = TimezoneUtils.get_country_code_for_timezone(@user_timezone || "America/New_York") do %>
                        <Flagpack.flag name={country_code} class="timezone-flag" />
                      <% end %>
                      <span class="timezone-text">
                        {TimezoneUtils.format_timezone(@user_timezone || "America/New_York")}
                      </span>
                    </div>
                    <div class="timezone-arrow">▼</div>
                  </button>
                  <%= if @timezone_dropdown_open do %>
                    <div
                      class="timezone-dropdown"
                      phx-click-away="close_timezone_dropdown"
                      phx-target={@myself}
                    >
                      <div class="timezone-search-wrapper">
                        <input
                          id="timezone-search-input"
                          type="text"
                          placeholder={gettext("Search cities, countries, or timezones...")}
                          class="timezone-search"
                          phx-keyup="search_timezone"
                          phx-target={@myself}
                          name="search"
                          value={@timezone_search}
                          phx-hook="AutoFocus"
                        />
                      </div>
                      <div class="timezone-options">
                        <%= for {label, value, offset} <- TimezoneUtils.get_filtered_timezone_options(@timezone_search) do %>
                          <button
                            class="timezone-option"
                            phx-click="change_timezone"
                            phx-value-timezone={value}
                            phx-target={@myself}
                            type="button"
                          >
                            <div class="timezone-option-content">
                              <%= if country_code = TimezoneUtils.get_country_code_for_timezone(value) do %>
                                <Flagpack.flag name={country_code} class="timezone-option-flag" />
                              <% end %>
                              <div class="timezone-option-text">
                                <div class="timezone-option-label">{label}</div>
                                <div class="timezone-option-offset">{offset}</div>
                              </div>
                            </div>
                          </button>
                        <% end %>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Calendar and Time Selection -->
            <div
              class="schedule-grid"
              style="margin-top: 12px; flex: 1; display: flex; flex-direction: column; gap: 16px; min-height: 0; overflow-y: auto;"
            >
              <!-- Calendar -->
              <div class="calendar-section" style="flex-shrink: 0;">
                <div class="calendar-header">
                  <button class="calendar-nav-button" phx-click="prev_week" phx-target={@myself}>
                    ←
                  </button>
                  <h3>{get_week_display(@current_week_start)}</h3>
                  <button class="calendar-nav-button" phx-click="next_week" phx-target={@myself}>
                    →
                  </button>
                </div>

                <div class="calendar-grid">
                  <%= for day <- get_week_days(@current_week_start, assigns) do %>
                    <button
                      class={[
                        "calendar-day",
                        @selected_date == day.date && "selected",
                        day.loading && "calendar-day--loading"
                      ]}
                      data-testid="calendar-day"
                      data-date={day.date}
                      phx-click="select_date"
                      phx-value-date={day.date}
                      phx-target={@myself}
                      disabled={not day.available || day.loading}
                    >
                      <div class="day-name">{day.day_name}</div>
                      <div class="day-number">{day.day_number}</div>
                    </button>
                  <% end %>
                </div>
              </div>
              
    <!-- Time Slots -->
              <div
                class="time-slots-section"
                style="display: flex; flex-direction: column; flex-shrink: 0;"
              >
                <h3 style="margin-bottom: 8px; flex-shrink: 0;">{gettext("Available Times")}</h3>
                <div class="time-slots-grid" style={get_slots_container_style(@available_slots)}>
                  <%= if @selected_date do %>
                    <%= if @loading_slots do %>
                      <div class="loading-slots">
                        <span>{gettext("Loading available times...")}</span>
                      </div>
                    <% else %>
                      <%= if @calendar_error do %>
                        <div class="calendar-error">
                          {@calendar_error}
                        </div>
                      <% end %>
                      <%= if !@calendar_error && length(@available_slots) > 0 do %>
                        <%= for {period, slots} <- LocalizationHelpers.group_slots_by_period(@available_slots) do %>
                          <%= if length(slots) > 0 do %>
                            <div class="time-period-section" style="margin-bottom: 12px;">
                              <h4
                                class="time-period-header"
                                style="font-size: 12px; font-weight: 600; margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.5px;"
                              >
                                {period}
                              </h4>
                              <div
                                class="time-period-slots"
                                style={get_period_slots_style(@available_slots)}
                              >
                                <%= for slot <- slots do %>
                                  <button
                                    class={"time-slot #{if @selected_time == slot, do: "selected", else: ""}"}
                                    data-testid="time-slot"
                                    data-time={slot}
                                    style={get_slot_button_style(@available_slots)}
                                    phx-click="select_time"
                                    phx-value-time={slot}
                                    phx-target={@myself}
                                  >
                                    {LocalizationHelpers.format_time_by_locale(Helpers.parse_slot_time(slot))}
                                  </button>
                                <% end %>
                              </div>
                            </div>
                          <% end %>
                        <% end %>
                      <% else %>
                        <%= if !@calendar_error do %>
                          <div class="no-slots">
                            <p>{gettext("This date is fully booked")}</p>
                            <p>{gettext("Please select another date")}</p>
                          </div>
                        <% end %>
                      <% end %>
                    <% end %>
                  <% else %>
                    <div class="no-slots">
                      <p>{gettext("Please select a date to see available times")}</p>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
            
    <!-- Navigation -->
            <div
              class="slide-actions"
              style="flex-shrink: 0; margin-top: 16px; display: flex; gap: 12px;"
            >
              <button
                class="prev-button"
                phx-click="prev_slide"
                phx-target={@myself}
                data-testid="back-step"
                style="flex: 1;"
              >
                ← {gettext("back")}
              </button>
              <button
                class={
                  if @selected_date && @selected_time, do: "next-button", else: "next-button disabled"
                }
                phx-click="next_slide"
                phx-target={@myself}
                data-testid="next-step"
                disabled={is_nil(@selected_date) or is_nil(@selected_time)}
                style="flex: 1;"
              >
                {gettext("next")} →
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helpers
  defp get_week_display(week_start) do
    week_end = Date.add(week_start, 6)

    if week_start.month == week_end.month do
      gettext("%{month} %{year}", month: month_name(week_start.month), year: week_start.year)
    else
      gettext("%{start_month} - %{end_month} %{year}", 
        start_month: month_name(week_start.month), 
        end_month: month_name(week_end.month), 
        year: week_start.year
      )
    end
  end

  defp month_name(month_num) when is_integer(month_num) do
    case month_num do
      1 -> gettext("January")
      2 -> gettext("February")
      3 -> gettext("March")
      4 -> gettext("April")
      5 -> gettext("May")
      6 -> gettext("June")
      7 -> gettext("July")
      8 -> gettext("August")
      9 -> gettext("September")
      10 -> gettext("October")
      11 -> gettext("November")
      12 -> gettext("December")
    end
  end

  defp get_week_days(week_start, assigns) do
    availability_map = Map.get(assigns, :month_availability_map)

    Enum.map(0..6, fn day_offset ->
      date = Date.add(week_start, day_offset)
      date_string = Date.to_string(date)

      # Check availability based on availability_map state
      {is_available, is_loading} =
        cond do
          # Loading state
          availability_map == :loading ->
            {false, true}

          # Real availability data provided
          is_map(availability_map) ->
            real_available = Map.get(availability_map, date_string, false)
            {real_available, false}

          # No availability map: use business hours logic
          true ->
            business_hours_available = day_available?(date, assigns.organizer_profile)
            {business_hours_available, false}
        end

      %{
        date: date_string,
        day_name: day_name_short(Date.day_of_week(date)),
        day_number: date.day,
        available: is_available,
        loading: is_loading
      }
    end)
  end

  defp day_name_short(day_of_week) do
    case day_of_week do
      1 -> gettext("MON")
      2 -> gettext("TUE")
      3 -> gettext("WED")
      4 -> gettext("THU")
      5 -> gettext("FRI")
      6 -> gettext("SAT")
      7 -> gettext("SUN")
    end
  end

  defp day_available?(date, organizer_profile) do
    today = Date.utc_today()
    is_weekday = BusinessHours.business_day?(date)
    is_future = Date.compare(date, today) != :lt
    is_within_limit = Date.diff(date, today) <= organizer_profile.advance_booking_days

    is_weekday && is_future && is_within_limit
  end

  defp get_slots_container_style(_available_slots), do: ""
  defp get_period_slots_style(_available_slots), do: ""
  defp get_slot_button_style(_available_slots), do: ""
end
