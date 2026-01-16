defmodule TymeslotWeb.Components.Dashboard.Integrations.Calendar.NextcloudConfig do
  @moduledoc """
  Modern component for configuring Nextcloud calendar integration.
  """
  use TymeslotWeb, :live_component

  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.SharedFormComponents,
    as: SharedForm

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:discovered_calendars, [])
     |> assign(:discovery_credentials, %{})
     |> assign(:form_values, %{})
     |> assign(:form_errors, %{})
     |> assign(:saving, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:discovered_calendars, fn -> [] end)
     |> assign_new(:discovery_credentials, fn -> %{} end)
     |> assign_new(:form_values, fn -> %{} end)
     |> assign_new(:form_errors, fn -> %{} end)
     |> assign_new(:saving, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"nextcloud-config-#{@id}"} class="space-y-6">
      <div class="flex items-center gap-4 mb-2">
        <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-sky-500 to-blue-600 flex items-center justify-center shadow-lg">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M3 15a4 4 0 014-4h1a5 5 0 0110 0h1a4 4 0 110 8H7a4 4 0 01-4-4z"
            />
          </svg>
        </div>
        <div>
          <h3 class="text-xl font-black text-slate-900 tracking-tight">Nextcloud</h3>
          <p class="text-sm text-slate-500 font-medium">Sync calendars from your Nextcloud server</p>
        </div>
      </div>

      <SharedForm.config_form
        provider="nextcloud"
        show_calendar_selection={@show_calendar_selection}
        discovered_calendars={@discovered_calendars}
        discovery_credentials={@discovery_credentials}
        form_errors={@form_errors}
        form_values={@form_values}
        saving={@saving}
        target={@target}
        myself={@myself}
        suggested_name="My Nextcloud"
        name_placeholder="My Nextcloud Calendar"
        url_placeholder="https://cloud.example.com"
      />
    </div>
    """
  end
end
