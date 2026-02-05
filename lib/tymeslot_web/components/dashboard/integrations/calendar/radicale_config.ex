defmodule TymeslotWeb.Components.Dashboard.Integrations.Calendar.RadicaleConfig do
  @moduledoc """
  Modern component for configuring Radicale calendar integration.
  """
  use TymeslotWeb, :live_component

  use TymeslotWeb.Components.Dashboard.Integrations.Calendar.ConfigBase,
    provider: :radicale,
    default_name: "My Radicale"

  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.SharedFormComponents,
    as: SharedForm

  @impl true
  def mount(socket) do
    {:ok, assign_config_defaults(socket)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_config_defaults()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"radicale-config-#{@id}"} class="space-y-6">
      <div class="flex items-center gap-4 mb-2">
        <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-amber-500 to-orange-500 flex items-center justify-center shadow-lg">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
            />
          </svg>
        </div>
        <div>
          <h3 class="text-xl font-black text-slate-900 tracking-tight">Radicale</h3>
          <p class="text-sm text-slate-500 font-medium">Lightweight CalDAV server integration</p>
        </div>
      </div>

      <SharedForm.config_form
        provider="radicale"
        show_calendar_selection={@show_calendar_selection}
        discovered_calendars={@discovered_calendars}
        discovery_credentials={@discovery_credentials}
        form_errors={@form_errors}
        form_values={@form_values}
        saving={@saving}
        target={@target}
        myself={@myself}
        suggested_name="My Radicale"
        name_placeholder="My Radicale Calendar"
        url_placeholder="https://radicale.example.com:5232"
      />
    </div>
    """
  end
end
