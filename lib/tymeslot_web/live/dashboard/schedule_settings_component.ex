defmodule TymeslotWeb.Dashboard.ScheduleSettingsComponent do
  @moduledoc """
  LiveView component for managing user availability settings including
  weekly schedules, breaks, and date-specific overrides.
  """
  use TymeslotWeb, :live_component

  alias Tymeslot.Availability.{AvailabilityActions, WeeklySchedule}
  alias TymeslotWeb.Components.DashboardComponents
  alias TymeslotWeb.Dashboard.Availability.{GridComponent, ListComponent}

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_schedule()
      |> assign(saving: false)
      |> assign(input_mode: :list)
      |> assign(form_errors: %{})

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("toggle_input_mode", %{"option" => option}, socket) do
    new_mode =
      case option do
        "list" -> :list
        "grid" -> :grid
        _ -> :list
      end

    {:noreply, assign(socket, :input_mode, new_mode)}
  end

  @spec handle_info({:reload_schedule}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:reload_schedule}, socket) do
    {:noreply, reload_schedule(socket)}
  end

  # State Management Functions

  @spec load_schedule(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_schedule(socket) do
    profile_id = socket.assigns.profile.id
    weekly_schedule = WeeklySchedule.get_weekly_schedule(profile_id)
    full_schedule = AvailabilityActions.ensure_complete_schedule(weekly_schedule, profile_id)

    socket
    |> assign(:weekly_schedule, full_schedule)
    |> assign(:saving, false)
  end

  @spec reload_schedule(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp reload_schedule(socket) do
    load_schedule(socket)
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-6">
        <DashboardComponents.section_header
          icon={:calendar}
          title="Availability"
          class="mb-0"
        />

        <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-4">
          <!-- Input Mode Toggle -->
          <div class="bg-white border-2 border-slate-50 p-1.5 rounded-2xl shadow-sm flex items-center">
            <button
              phx-click="toggle_input_mode"
              phx-value-option="list"
              phx-target={@myself}
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-black transition-all duration-300",
                if(@input_mode == :list,
                  do: "bg-turquoise-50 text-turquoise-700 shadow-sm",
                  else: "text-slate-400 hover:text-slate-600"
                )
              ]}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
              </svg>
              List
            </button>
            <button
              phx-click="toggle_input_mode"
              phx-value-option="grid"
              phx-target={@myself}
              class={[
                "flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-black transition-all duration-300",
                if(@input_mode == :grid,
                  do: "bg-turquoise-50 text-turquoise-700 shadow-sm",
                  else: "text-slate-400 hover:text-slate-600"
                )
              ]}
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
              </svg>
              Grid
            </button>
          </div>

          <%= if @saving do %>
            <div class="flex items-center bg-emerald-50 text-emerald-700 px-4 py-2 rounded-full font-black text-xs uppercase tracking-wider border-2 border-emerald-100">
              <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              Saving changes...
            </div>
          <% end %>
        </div>
      </div>

      <div class="animate-in fade-in duration-500">
        <%= if @input_mode == :list do %>
          <.live_component
            module={ListComponent}
            id="availability-list"
            weekly_schedule={@weekly_schedule}
            profile={@profile}
            form_errors={@form_errors}
            client_ip={@client_ip}
            user_agent={@user_agent}
          />
        <% else %>
          <.live_component
            module={GridComponent}
            id="availability-grid"
            current_user={@current_user}
            profile={@profile}
            weekly_schedule={@weekly_schedule}
          />
        <% end %>
      </div>
    </div>
    """
  end
end
