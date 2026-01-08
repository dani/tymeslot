defmodule TymeslotWeb.Dashboard.MeetingSettings.Components do
  @moduledoc """
  Reusable components for meeting scheduling settings.
  Includes buffer time, advance booking, and minimum notice settings.
  """
  use Phoenix.Component

  @doc """
  Component for configuring buffer time between appointments.
  """
  attr :profile, :map, required: true
  attr :myself, :any, required: true

  @spec buffer_minutes_setting(map()) :: Phoenix.LiveView.Rendered.t()
  def buffer_minutes_setting(assigns) do
    assigns =
      assign(
        assigns,
        :buffer_value,
        if(assigns.profile, do: assigns.profile.buffer_minutes, else: 0)
      )

    ~H"""
    <div>
      <label class="label">
        Buffer Between Appointments
      </label>
      
    <!-- Tag-based Selection -->
      <div class="flex flex-wrap items-center gap-3">
        <!-- Quick preset tags -->
        <%= for minutes <- [0, 5, 10, 15, 30, 60] do %>
          <button
            type="button"
            phx-click="update_buffer_minutes"
            phx-value-buffer_minutes={minutes}
            phx-target={@myself}
            class={[
              "inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 border-2",
              if(@buffer_value == minutes,
                do: "bg-turquoise-50 text-turquoise-700 border-turquoise-200 shadow-sm",
                else: "bg-white text-tymeslot-500 border-tymeslot-100 hover:border-turquoise-100 hover:text-turquoise-600 hover:bg-tymeslot-50"
              )
            ]}
          >
            <%= if minutes == 0 do %>
              No buffer
            <% else %>
              {minutes} min
            <% end %>
          </button>
        <% end %>
        
    <!-- Custom input tag -->
        <%= if @buffer_value not in [0, 5, 10, 15, 30, 60] do %>
          <div class={[
            "inline-flex items-center rounded-token-xl border-2 transition-all duration-300",
            "bg-turquoise-50 text-turquoise-700 border-turquoise-200 shadow-sm"
          ]}>
            <input
              type="number"
              min="0"
              max="120"
              step="5"
              value={@buffer_value}
              phx-blur="update_buffer_minutes"
              phx-target={@myself}
              name="buffer_minutes"
              class="w-20 px-3 py-2 text-token-sm font-black bg-transparent border-0 focus:ring-0 focus:outline-none rounded-l-xl"
              placeholder="0"
            />
            <span class="pr-3 py-2 text-token-sm font-black text-turquoise-700">
              min
            </span>
          </div>
        <% else %>
          <button
            type="button"
            phx-click="focus_custom_input"
            phx-value-setting="buffer_minutes"
            phx-target={@myself}
            class="inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 bg-white text-tymeslot-500 border-2 border-tymeslot-100 hover:border-turquoise-100 hover:text-turquoise-600 hover:bg-tymeslot-50"
          >
            Custom
          </button>
        <% end %>
      </div>

      <p class="mt-4 text-token-sm text-tymeslot-500 font-bold">
        Time to block after each appointment for preparation, travel, or breaks.
      </p>
    </div>
    """
  end

  @doc """
  Component for configuring how far in advance appointments can be booked.
  """
  attr :profile, :map, required: true
  attr :myself, :any, required: true

  @spec advance_booking_days_setting(map()) :: Phoenix.LiveView.Rendered.t()
  def advance_booking_days_setting(assigns) do
    assigns =
      assign(
        assigns,
        :booking_days,
        if(assigns.profile, do: assigns.profile.advance_booking_days, else: 90)
      )

    ~H"""
    <div>
      <label class="label">
        How Far in Advance Can People Book
      </label>
      
    <!-- Tag-based Selection -->
      <div class="flex flex-wrap items-center gap-3">
        <!-- Quick preset tags -->
        <%= for {days, label} <- [
          {7, "1 week"},
          {14, "2 weeks"},
          {30, "1 month"},
          {60, "2 months"},
          {90, "3 months"},
          {180, "6 months"}
        ] do %>
          <button
            type="button"
            phx-click="update_advance_booking_days"
            phx-value-advance_booking_days={days}
            phx-target={@myself}
            class={[
              "inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 border-2",
              if(@booking_days == days,
                do: "bg-cyan-50 text-cyan-700 border-cyan-200 shadow-sm",
                else: "bg-white text-tymeslot-500 border-tymeslot-100 hover:border-cyan-100 hover:text-cyan-600 hover:bg-tymeslot-50"
              )
            ]}
          >
            {label}
          </button>
        <% end %>
        
    <!-- Custom input tag -->
        <%= if @booking_days not in [7, 14, 30, 60, 90, 180] do %>
          <div class={[
            "inline-flex items-center rounded-token-xl border-2 transition-all duration-300",
            "bg-cyan-50 text-cyan-700 border-cyan-200 shadow-sm"
          ]}>
            <input
              type="number"
              min="1"
              max="365"
              step="1"
              value={@booking_days}
              phx-blur="update_advance_booking_days"
              phx-target={@myself}
              name="advance_booking_days"
              class="w-20 px-3 py-2 text-token-sm font-black bg-transparent border-0 focus:ring-0 focus:outline-none rounded-l-xl"
              placeholder="90"
            />
            <span class="pr-3 py-2 text-token-sm font-black text-cyan-700">
              days
            </span>
          </div>
        <% else %>
          <button
            type="button"
            phx-click="focus_custom_input"
            phx-value-setting="advance_booking_days"
            phx-target={@myself}
            class="inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 bg-white text-tymeslot-500 border-2 border-tymeslot-100 hover:border-cyan-100 hover:text-cyan-600 hover:bg-tymeslot-50"
          >
            Custom
          </button>
        <% end %>
      </div>

      <p class="mt-4 text-token-sm text-tymeslot-500 font-bold">
        Maximum number of days into the future that appointments can be booked.
      </p>
    </div>
    """
  end

  @doc """
  Component for configuring minimum booking notice required.
  """
  attr :profile, :map, required: true
  attr :myself, :any, required: true

  @spec min_advance_hours_setting(map()) :: Phoenix.LiveView.Rendered.t()
  def min_advance_hours_setting(assigns) do
    assigns =
      assign(
        assigns,
        :notice_hours,
        if(assigns.profile, do: assigns.profile.min_advance_hours, else: 24)
      )

    ~H"""
    <div>
      <label class="label">
        Minimum Booking Notice
      </label>
      
    <!-- Tag-based Selection -->
      <div class="flex flex-wrap items-center gap-3">
        <!-- Quick preset tags -->
        <%= for {hours, label} <- [
          {0, "instant"},
          {1, "1 hour"},
          {4, "4 hours"},
          {24, "1 day"},
          {48, "2 days"},
          {168, "1 week"}
        ] do %>
          <button
            type="button"
            phx-click="update_min_advance_hours"
            phx-value-min_advance_hours={hours}
            phx-target={@myself}
            class={[
              "inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 border-2",
              if(@notice_hours == hours,
                do: "bg-blue-50 text-blue-700 border-blue-200 shadow-sm",
                else: "bg-white text-tymeslot-500 border-tymeslot-100 hover:border-blue-100 hover:text-blue-600 hover:bg-tymeslot-50"
              )
            ]}
          >
            {label}
          </button>
        <% end %>
        
    <!-- Custom input tag -->
        <%= if @notice_hours not in [0, 1, 4, 24, 48, 168] do %>
          <div class={[
            "inline-flex items-center rounded-token-xl border-2 transition-all duration-300",
            "bg-blue-50 text-blue-700 border-blue-200 shadow-sm"
          ]}>
            <input
              type="number"
              min="0"
              max="168"
              step="1"
              value={@notice_hours}
              phx-blur="update_min_advance_hours"
              phx-target={@myself}
              name="min_advance_hours"
              class="w-20 px-3 py-2 text-token-sm font-black bg-transparent border-0 focus:ring-0 focus:outline-none rounded-l-xl"
              placeholder="24"
            />
            <span class="pr-3 py-2 text-token-sm font-black text-blue-700">
              hours
            </span>
          </div>
        <% else %>
          <button
            type="button"
            phx-click="focus_custom_input"
            phx-value-setting="min_advance_hours"
            phx-target={@myself}
            class="inline-flex items-center px-4 py-2 rounded-token-xl text-token-sm font-black transition-all duration-300 bg-white text-tymeslot-500 border-2 border-tymeslot-100 hover:border-blue-100 hover:text-blue-600 hover:bg-tymeslot-50"
          >
            Custom
          </button>
        <% end %>
      </div>

      <p class="mt-4 text-token-sm text-tymeslot-500 font-bold">
        Minimum hours of notice required before an appointment can be booked.
      </p>
    </div>
    """
  end
end
