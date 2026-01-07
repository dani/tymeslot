defmodule TymeslotWeb.OnboardingLive.SchedulingPreferencesStep do
  @moduledoc """
  Scheduling preferences step component for the onboarding flow.

  Handles the configuration of scheduling preferences including
  buffer time, advance booking window, and minimum advance notice.
  """

  use Phoenix.Component

  alias TymeslotWeb.OnboardingLive.StepConfig

  @doc """
  Renders the scheduling preferences step component.

  ## Assigns

  * `profile` - The user's profile struct
  * `form_errors` - Map of form validation errors
  """
  def scheduling_preferences_step(assigns) do
    ~H"""
    <div class="onboarding-step">
      <div class="text-center mb-12">
        <h2 class="onboarding-step-title">{StepConfig.step_title(:scheduling_preferences)}</h2>
        <p class="onboarding-step-description">{StepConfig.step_description(:scheduling_preferences)}</p>
      </div>

      <div class="onboarding-form space-y-10 text-left">
        <!-- Buffer Time Between Meetings -->
        <div class="onboarding-form-group">
          <label class="label">
            Buffer Between Meetings
          </label>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.buffer_time_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-buffer_minutes={value}
                class={[
                  "inline-flex items-center px-4 py-2 rounded-xl text-sm font-black transition-all duration-300 border-2",
                  if(@profile.buffer_minutes == value,
                    do: "bg-turquoise-50 text-turquoise-700 border-turquoise-200 shadow-sm",
                    else: "bg-white text-slate-500 border-slate-100 hover:border-turquoise-100 hover:text-turquoise-600 hover:bg-slate-50"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <p class="text-sm mt-3 font-bold text-slate-400 uppercase tracking-widest">
            Time to block after every appointment
          </p>
          <%= if @form_errors[:buffer_minutes] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:buffer_minutes]}</p>
          <% end %>
        </div>
        
    <!-- Advance Booking Window -->
        <div class="onboarding-form-group pt-8 border-t-2 border-slate-50">
          <label class="label">
            Booking Window
          </label>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.advance_booking_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-advance_booking_days={value}
                class={[
                  "inline-flex items-center px-4 py-2 rounded-xl text-sm font-black transition-all duration-300 border-2",
                  if(@profile.advance_booking_days == value,
                    do: "bg-cyan-50 text-cyan-700 border-cyan-200 shadow-sm",
                    else: "bg-white text-slate-500 border-slate-100 hover:border-cyan-100 hover:text-cyan-600 hover:bg-slate-50"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <p class="text-sm mt-3 font-bold text-slate-400 uppercase tracking-widest">
            How far in advance clients can schedule
          </p>
          <%= if @form_errors[:advance_booking_days] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:advance_booking_days]}</p>
          <% end %>
        </div>
        
    <!-- Minimum Advance Notice -->
        <div class="onboarding-form-group pt-8 border-t-2 border-slate-50">
          <label class="label">
            Minimum Notice
          </label>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.min_advance_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-min_advance_hours={value}
                class={[
                  "inline-flex items-center px-4 py-2 rounded-xl text-sm font-black transition-all duration-300 border-2",
                  if(@profile.min_advance_hours == value,
                    do: "bg-blue-50 text-blue-700 border-blue-200 shadow-sm",
                    else: "bg-white text-slate-500 border-slate-100 hover:border-blue-100 hover:text-blue-600 hover:bg-slate-50"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <p class="text-sm mt-3 font-bold text-slate-400 uppercase tracking-widest">
            Prevents last-minute surprise bookings
          </p>
          <%= if @form_errors[:min_advance_hours] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:min_advance_hours]}</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
