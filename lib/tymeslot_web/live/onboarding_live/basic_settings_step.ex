defmodule TymeslotWeb.OnboardingLive.BasicSettingsStep do
  @moduledoc """
  Basic settings step component for the onboarding flow.

  Handles the collection of user profile information including
  full name, username, and timezone selection.
  """

  use Phoenix.Component

  alias TymeslotWeb.Components.TimezoneDropdown
  alias TymeslotWeb.OnboardingLive.StepConfig

  @doc """
  Renders the basic settings step component.

  ## Assigns

  * `profile` - The user's profile struct
  * `form_data` - Current form data map
  * `timezone_options` - Available timezone options
  * `timezone_dropdown_open` - Boolean for dropdown state
  * `timezone_search` - Current search query
  * `form_errors` - Map of form validation errors
  """
  @spec basic_settings_step(map()) :: Phoenix.LiveView.Rendered.t()
  def basic_settings_step(assigns) do
    ~H"""
    <div class="onboarding-step">
      <div class="text-center mb-12">
        <h2 class="onboarding-step-title">{StepConfig.step_title(:basic_settings)}</h2>
        <p class="onboarding-step-description">{StepConfig.step_description(:basic_settings)}</p>
      </div>

      <.form
        for={%{}}
        as={:basic_settings}
        phx-change="validate_basic_settings"
        phx-submit="update_basic_settings"
        class="onboarding-form text-left"
        id="basic-settings-form"
      >
        <div class="onboarding-form-group">
          <label for="full_name" class="label">
            Display Name
          </label>
          <input
            type="text"
            id="full_name"
            name="full_name"
            value={Map.get(@form_data, "full_name", "")}
            class={[
              "input",
              if(@form_errors[:full_name], do: "input-error", else: "")
            ]}
            placeholder="e.g. John Doe"
            autocomplete="name"
          />
          <%= if @form_errors[:full_name] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:full_name]}</p>
          <% end %>
        </div>

        <div class="onboarding-form-group">
          <label for="username" class="label">
            Booking URL
          </label>
          <div class="relative group">
            <% domain = Application.get_env(:tymeslot, :email)[:domain] || "tymeslot.app" %>
            <div class="absolute inset-y-0 left-4 flex items-center pointer-events-none">
              <span class="text-slate-400 font-bold text-sm tracking-tight">{domain}/</span>
            </div>
            <input
              type="text"
              id="username"
              name="username"
              value={Map.get(@form_data, "username", "")}
              class={[
                "input pl-[120px]",
                if(@form_errors[:username], do: "input-error", else: "")
              ]}
              placeholder="yourname"
              autocomplete="username"
            />
          </div>
          <%= if @form_errors[:username] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:username]}</p>
          <% end %>
          <p class="text-sm mt-3 font-bold text-slate-400 uppercase tracking-widest">
            This will be your unique scheduling link.
          </p>
        </div>
        
    <!-- Timezone component inside form -->
        <div class="onboarding-form-group pt-4 border-t-2 border-slate-50">
          <label class="label mb-4">Your Timezone</label>
          <TimezoneDropdown.timezone_dropdown
            profile={@profile}
            timezone_options={@timezone_options}
            timezone_dropdown_open={@timezone_dropdown_open}
            timezone_search={@timezone_search}
            safe_flags={true}
          />
          <%= if @form_errors[:timezone] do %>
            <p class="mt-2 text-sm text-red-600 font-bold">{@form_errors[:timezone]}</p>
          <% end %>
        </div>
      </.form>
    </div>
    """
  end
end
