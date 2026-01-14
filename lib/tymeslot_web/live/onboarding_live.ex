defmodule TymeslotWeb.OnboardingLive do
  use TymeslotWeb, :live_view

  alias Tymeslot.Onboarding
  alias Tymeslot.Profiles.Timezone
  alias Tymeslot.Utils.TimezoneUtils
  alias TymeslotWeb.Components.CoreComponents
  alias TymeslotWeb.Helpers.ClientIP
  alias TymeslotWeb.OnboardingLive.BasicSettingsHandlers
  alias TymeslotWeb.OnboardingLive.BasicSettingsStep
  alias TymeslotWeb.OnboardingLive.CompleteStep
  alias TymeslotWeb.OnboardingLive.NavigationHandlers
  alias TymeslotWeb.OnboardingLive.SchedulingHandlers
  alias TymeslotWeb.OnboardingLive.SchedulingPreferencesStep
  alias TymeslotWeb.OnboardingLive.StepConfig
  alias TymeslotWeb.OnboardingLive.TimezoneHandlers
  alias TymeslotWeb.OnboardingLive.WelcomeStep

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:ok, Phoenix.LiveView.Socket.t(), keyword()}
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Check if this is a debug route by examining the live_action
    is_debug = socket.assigns.live_action in [:debug_welcome, :debug_step]

    # Check if user has already completed onboarding (skip for debug routes)
    if user.onboarding_completed_at && !is_debug do
      socket = put_flash(socket, :info, "You have already completed onboarding.")
      {:ok, redirect(socket, to: ~p"/dashboard")}
    else
      # Handle profile creation
      {:ok, profile} = Onboarding.get_or_create_profile(user.id)

      # Use existing user name if available, otherwise fall back to profile full_name
      default_full_name = user.name || profile.full_name || ""

      # Read detected timezone from connect params (set in assets/js/app.js)
      connect_params = get_connect_params(socket) || %{}
      detected_timezone = connect_params["timezone"]

      # Decide prefill value in the context (pure function, no persistence)
      prefilled_timezone = Timezone.prefill_timezone(profile.timezone, detected_timezone)
      prefilled_profile = Map.put(profile, :timezone, prefilled_timezone)

      socket =
        socket
        |> assign(:profile, prefilled_profile)
        |> assign(:form_data, %{
          "full_name" => default_full_name,
          "username" => profile.username || ""
        })
        |> assign(:current_step, :welcome)
        |> assign(:step_data, %{})
        |> assign(:show_skip_modal, false)
        |> assign(:steps, StepConfig.get_steps())
        |> assign(:timezone_options, TimezoneUtils.get_all_timezone_options())
        |> assign(:timezone_dropdown_open, false)
        |> assign(:timezone_search, "")
        |> assign(:page_title, "Welcome to Tymeslot")
        |> assign(:form_errors, %{})
        |> assign(:remote_ip, ClientIP.get(socket))

      {:ok, socket}
    end
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(%{"step" => step}, _uri, socket) do
    if StepConfig.valid_step?(step) do
      step_atom = String.to_existing_atom(step)
      {:noreply, assign(socket, :current_step, step_atom)}
    else
      # Preserve debug route when redirecting
      redirect_path =
        if socket.assigns.live_action in [:debug_welcome, :debug_step] do
          ~p"/debug/onboarding"
        else
          ~p"/onboarding"
        end

      {:noreply, redirect(socket, to: redirect_path)}
    end
  end

  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :current_step, :welcome)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <main class="min-h-screen bg-gradient-to-br from-turquoise-600 via-cyan-600 to-blue-600 flex items-center justify-center p-6 relative overflow-hidden">
      <!-- Animated background elements -->
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(255,255,255,0.15),transparent_50%)]"></div>
      <div class="absolute inset-0 bg-[radial-gradient(circle_at_70%_80%,rgba(6,182,212,0.3),transparent_50%)]"></div>

      <div class="w-full max-w-3xl relative z-10 animate-in fade-in zoom-in-95 duration-700">
        <div class="flex-1 flex flex-col items-center">
          <div class="w-full">
            <!-- Progress indicator with enhancements -->
            <div class="progress-indicator">
              <div class="progress-indicator-container">
                <%= for {step, index} <- Enum.with_index(@steps) do %>
                  <div class="flex items-center">
                    <div class={[
                      "progress-step-circle",
                      if(StepConfig.step_completed?(step, @current_step),
                        do: "progress-step-circle--completed",
                        else:
                          if(step == @current_step,
                            do: "progress-step-circle--active",
                            else: "progress-step-circle--inactive"
                          )
                      )
                    ]}>
                      <%= if StepConfig.step_completed?(step, @current_step) do %>
                        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                        </svg>
                      <% else %>
                        {index + 1}
                      <% end %>
                    </div>

                    <%= if index < length(@steps) - 1 do %>
                      <div class={[
                        "progress-step-connector",
                        if(StepConfig.step_completed?(step, @current_step),
                          do: "progress-step-connector--completed",
                          else: ""
                        )
                      ]}>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
            
    <!-- Main content card -->
            <div class="card-glass shadow-2xl shadow-slate-900/20 p-10 lg:p-16">
              <div class="animate-in fade-in slide-in-from-bottom-4 duration-500">
                <%= case @current_step do %>
                  <% :welcome -> %>
                    <WelcomeStep.welcome_step />
                  <% :basic_settings -> %>
                    <BasicSettingsStep.basic_settings_step
                      profile={@profile}
                      form_data={@form_data}
                      timezone_options={@timezone_options}
                      timezone_dropdown_open={@timezone_dropdown_open}
                      timezone_search={@timezone_search}
                      form_errors={@form_errors}
                    />
                  <% :scheduling_preferences -> %>
                    <SchedulingPreferencesStep.scheduling_preferences_step
                      profile={@profile}
                      form_errors={@form_errors}
                    />
                  <% :complete -> %>
                    <CompleteStep.complete_step />
                <% end %>
              </div>
              
    <!-- Navigation buttons -->
              <div class="flex flex-col sm:flex-row items-center justify-between mt-12 pt-10 border-t-2 border-slate-50 gap-6">
                <button type="button" phx-click="show_skip_modal" class="text-slate-400 hover:text-slate-600 font-black uppercase tracking-widest text-xs transition-colors">
                  Skip for now
                </button>

                <div class="flex items-center gap-4 w-full sm:w-auto">
                  <%= if @current_step != :welcome do %>
                    <button type="button" phx-click="previous_step" class="btn-secondary flex-1 sm:flex-none px-8 py-4">
                      Back
                    </button>
                  <% end %>

                  <button type="button" phx-click="next_step" class="btn-primary flex-1 sm:flex-none px-10 py-4">
                    {StepConfig.next_button_text(@current_step)}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Skip confirmation modal -->
      <CoreComponents.modal
        id="skip-onboarding-modal"
        show={@show_skip_modal}
        on_cancel={JS.push("hide_skip_modal")}
        size={:medium}
      >
        <:header>
          <div class="flex items-center gap-4">
            <div class="w-12 h-12 bg-amber-50 rounded-2xl flex items-center justify-center border border-amber-100">
              <svg class="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
              </svg>
            </div>
            Skip setup?
          </div>
        </:header>

        <p class="text-slate-600 font-medium text-lg leading-relaxed">
          Are you sure you want to skip the quick start? You can always configure these settings later in your dashboard.
        </p>

        <:footer>
          <div class="flex flex-col sm:flex-row gap-3">
            <CoreComponents.action_button
              variant={:danger}
              phx-click="skip_onboarding"
              class="flex-1 py-4"
            >
              Skip anyway
            </CoreComponents.action_button>
            <CoreComponents.action_button
              variant={:secondary}
              phx-click="hide_skip_modal"
              class="flex-1 py-4"
            >
              Continue setup
            </CoreComponents.action_button>
          </div>
        </:footer>
      </CoreComponents.modal>
    </main>
    """
  end

  # Event handlers - Navigation
  @impl true
  def handle_event("next_step", _params, socket) do
    NavigationHandlers.handle_next_step(socket)
  end

  def handle_event("previous_step", _params, socket) do
    NavigationHandlers.handle_previous_step(socket)
  end

  def handle_event("show_skip_modal", _params, socket) do
    NavigationHandlers.handle_show_skip_modal(socket)
  end

  def handle_event("hide_skip_modal", _params, socket) do
    NavigationHandlers.handle_hide_skip_modal(socket)
  end

  def handle_event("skip_onboarding", _params, socket) do
    NavigationHandlers.handle_skip_onboarding(socket)
  end

  # Event handlers - Basic Settings
  def handle_event("validate_basic_settings", params, socket) do
    BasicSettingsHandlers.handle_validate_basic_settings(params, socket)
  end

  def handle_event("update_basic_settings", _params, socket) do
    NavigationHandlers.handle_next_step(socket)
  end

  # Event handlers - Scheduling Preferences
  def handle_event("validate_scheduling_preferences", params, socket) do
    SchedulingHandlers.handle_validate_scheduling_preferences(params, socket)
  end

  def handle_event("update_scheduling_preferences", params, socket) do
    SchedulingHandlers.handle_update_scheduling_preferences(params, socket)
  end

  # Event handlers - Timezone
  def handle_event("toggle_timezone_dropdown", _params, socket) do
    TimezoneHandlers.handle_toggle_timezone_dropdown(socket)
  end

  def handle_event("close_timezone_dropdown", _params, socket) do
    TimezoneHandlers.handle_close_timezone_dropdown(socket)
  end

  def handle_event("search_timezone", %{"search" => search}, socket) do
    TimezoneHandlers.handle_search_timezone(search, socket)
  end

  def handle_event("search_timezone", %{"value" => search}, socket) do
    TimezoneHandlers.handle_search_timezone(search, socket)
  end

  def handle_event("change_timezone", %{"timezone" => timezone}, socket) do
    TimezoneHandlers.handle_change_timezone(timezone, socket)
  end

  # Handle flash messages from components
  @impl true
  def handle_info({:flash, {type, message}}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end
end
