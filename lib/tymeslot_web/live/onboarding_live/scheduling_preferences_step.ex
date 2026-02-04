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
  @spec scheduling_preferences_step(map()) :: Phoenix.LiveView.Rendered.t()
  def scheduling_preferences_step(assigns) do
    ~H"""
    <div class="onboarding-step">
      <div class="text-center mb-6">
        <h2 class="onboarding-step-title">{StepConfig.step_title(:scheduling_preferences)}</h2>
        <p class="onboarding-step-description">{StepConfig.step_description(:scheduling_preferences)}</p>
      </div>

      <div class="onboarding-form text-left">
        <!-- Buffer Time Between Meetings -->
        <div class="onboarding-form-group">
          <label class="label">
            Buffer Between Meetings
          </label>

          <p class="text-sm mb-3 font-bold text-slate-400 uppercase tracking-widest">
            Time to block after every appointment
          </p>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.buffer_time_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-buffer_minutes={value}
                class={[
                  "btn-tag-selector btn-tag-selector-primary",
                  if(@profile.buffer_minutes == value,
                    do: "btn-tag-selector-primary--active"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <%= if @form_errors[:buffer_minutes] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:buffer_minutes]}</p>
          <% end %>
        </div>

    <!-- Advance Booking Window -->
        <div class="onboarding-form-group pt-6 border-t-2 border-slate-50">
          <label class="label">
            Booking Window
          </label>

          <p class="text-sm mb-3 font-bold text-slate-400 uppercase tracking-widest">
            How far in advance clients can schedule
          </p>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.advance_booking_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-advance_booking_days={value}
                class={[
                  "btn-tag-selector btn-tag-selector-secondary",
                  if(@profile.advance_booking_days == value,
                    do: "btn-tag-selector-secondary--active"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <%= if @form_errors[:advance_booking_days] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:advance_booking_days]}</p>
          <% end %>
        </div>

    <!-- Minimum Advance Notice -->
        <div class="onboarding-form-group pt-6 border-t-2 border-slate-50">
          <label class="label">
            Minimum Notice
          </label>

          <p class="text-sm mb-3 font-bold text-slate-400 uppercase tracking-widest">
            Prevents last-minute surprise bookings
          </p>

          <div class="flex flex-wrap items-center gap-3">
            <%= for {label, value} <- StepConfig.min_advance_options() do %>
              <button
                type="button"
                phx-click="update_scheduling_preferences"
                phx-value-min_advance_hours={value}
                class={[
                  "btn-tag-selector btn-tag-selector-tertiary",
                  if(@profile.min_advance_hours == value,
                    do: "btn-tag-selector-tertiary--active"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <%= if @form_errors[:min_advance_hours] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:min_advance_hours]}</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
