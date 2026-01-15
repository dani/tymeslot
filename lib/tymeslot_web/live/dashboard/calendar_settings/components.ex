defmodule TymeslotWeb.Dashboard.CalendarSettings.Components do
  @moduledoc """
  Functional components for the calendar settings dashboard.
  """
  use TymeslotWeb, :html

  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.CaldavConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.NextcloudConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.RadicaleConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.ProviderCard
  alias TymeslotWeb.Components.Icons.ProviderIcon
  alias TymeslotWeb.Components.UI.StatusSwitch
  alias TymeslotWeb.Dashboard.CalendarSettings.Helpers

  attr :selected_provider, :atom, required: true
  attr :myself, :any, required: true
  attr :security_metadata, :map, required: true
  attr :form_errors, :map, required: true
  attr :is_saving, :boolean, required: true

  @spec config_view(map()) :: Phoenix.LiveView.Rendered.t()
  def config_view(assigns) do
    ~H"""
    <div
      id="calendar-config-view"
      phx-hook="ScrollReset"
      data-action={@selected_provider}
      class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500"
    >
      <div class="flex items-center gap-6 bg-white p-6 rounded-token-3xl border-2 border-tymeslot-50 shadow-sm">
        <button
          phx-click="back_to_providers"
          phx-target={@myself}
          class="flex items-center gap-2 px-4 py-2 rounded-token-xl bg-tymeslot-50 text-tymeslot-600 font-bold hover:bg-tymeslot-100 transition-all"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2.5"
              d="M10 19l-7-7m0 0l7-7m-7 7h18"
            />
          </svg>
          Back
        </button>

        <div class="h-8 w-px bg-tymeslot-100"></div>

        <div class="flex items-center gap-4">
          <div class="w-12 h-12 bg-turquoise-50 rounded-token-xl flex items-center justify-center border border-turquoise-100 shadow-sm">
            <svg class="w-6 h-6 text-turquoise-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2.5"
                d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
          </div>
          <h2 class="text-token-3xl font-black text-tymeslot-900 tracking-tight">
            Setup <%= case @selected_provider do
              :nextcloud -> "Nextcloud"
              :radicale -> "Radicale"
              :caldav -> "CalDAV"
              _ -> "Calendar"
            end %>
          </h2>
        </div>
      </div>

      <div class="card-glass">
        <%= case @selected_provider do %>
          <% :nextcloud -> %>
            <.live_component
              module={NextcloudConfig}
              id="nextcloud-config"
              target={@myself}
              metadata={@security_metadata}
              form_errors={@form_errors}
              saving={@is_saving}
            />
          <% :radicale -> %>
            <.live_component
              module={RadicaleConfig}
              id="radicale-config"
              target={@myself}
              metadata={@security_metadata}
              form_errors={@form_errors}
              saving={@is_saving}
            />
          <% :caldav -> %>
            <.live_component
              module={CaldavConfig}
              id="caldav-config"
              target={@myself}
              metadata={@security_metadata}
              form_errors={@form_errors}
              saving={@is_saving}
            />
          <% _ -> %>
            <p class="text-tymeslot-500 font-medium">Configuration form not available for this provider.</p>
        <% end %>
      </div>
    </div>
    """
  end

  attr :integrations, :list, required: true
  attr :testing_integration_id, :integer, required: true
  attr :validating_integration_id, :integer, required: true
  attr :myself, :any, required: true

  @spec connected_calendars_section(map()) :: Phoenix.LiveView.Rendered.t()
  def connected_calendars_section(assigns) do
    # Group integrations by active/inactive
    grouped = %{
      active: Enum.filter(assigns.integrations, & &1.is_active),
      inactive: Enum.filter(assigns.integrations, &(!&1.is_active))
    }

    # Determine if we need section headers (both types present)
    show_section_headers = grouped.active != [] && grouped.inactive != []

    assigns =
      assigns
      |> assign(:grouped, grouped)
      |> assign(:show_section_headers, show_section_headers)

    ~H"""
    <div :if={@integrations != []} class="space-y-6">
      <!-- Active Calendars (Conflict Checking) -->
      <%= if @grouped.active != [] do %>
        <div class="space-y-3">
          <%= if @show_section_headers do %>
            <div class="mb-3">
              <h3 class="text-lg font-bold text-turquoise-800 flex items-center gap-2">
                🛡️ Active for Conflict Checking
              </h3>
              <p class="text-sm text-turquoise-600 font-medium mt-1 ml-6">
                We'll check these calendars to prevent double bookings
              </p>
            </div>
          <% end %>

          <%= for integration <- @grouped.active do %>
            <.calendar_row
              integration={integration}
              provider_display_name={Helpers.format_provider_name(integration.provider)}
              validating_integration_id={@validating_integration_id}
              myself={@myself}
            />
          <% end %>
        </div>
      <% end %>

      <!-- Inactive Calendars -->
      <%= if @grouped.inactive != [] do %>
        <div class="space-y-3">
          <%= if @show_section_headers do %>
            <h3 class="text-lg font-semibold text-slate-600">Paused Calendars</h3>
          <% end %>

          <%= for integration <- @grouped.inactive do %>
            <.calendar_row
              integration={integration}
              provider_display_name={Helpers.format_provider_name(integration.provider)}
              validating_integration_id={@validating_integration_id}
              myself={@myself}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :integration, :map, required: true
  attr :provider_display_name, :string, required: true
  attr :validating_integration_id, :integer, required: true
  attr :myself, :any, required: true

  defp calendar_row(assigns) do
    ~H"""
    <div class={[
      "card-glass transition-all duration-200",
      !@integration.is_active && "card-glass-unavailable"
    ]}>
      <div class="flex items-start justify-between gap-6">
        <!-- Left: Info -->
        <div class="flex items-start gap-4 flex-1 min-w-0">
          <ProviderIcon.provider_icon provider={@integration.provider} size="compact" class="mt-1" />

          <div class="flex-1 min-w-0">
            <!-- Title -->
            <div class="flex items-center gap-2 mb-1">
              <h4 class="text-base font-bold text-slate-900 truncate">
                <%= if @integration.name == @provider_display_name do %>
                  {@provider_display_name}
                <% else %>
                  {@integration.name}
                <% end %>
              </h4>
            </div>

            <!-- Type Badge -->
            <div class="mb-2">
              <%= if @integration.is_active do %>
                <span class="text-xs font-semibold text-turquoise-700">
                  🛡️ Active for Conflict Checking
                </span>
              <% else %>
                <span class="text-xs font-semibold text-slate-500">
                  ⏸️ Paused
                </span>
              <% end %>
            </div>

            <!-- Details -->
            <div class="text-sm text-gray-600">
              <%= if @integration.is_active do %>
                <%= if @integration.calendar_list && length(@integration.calendar_list) > 0 do %>
                  <div class="flex flex-wrap gap-1.5">
                    <%= for calendar <- Enum.filter(@integration.calendar_list, &(&1["selected"] || &1[:selected])) do %>
                      <span class="inline-flex items-center px-2 py-1 rounded-token-lg bg-slate-100 text-slate-700 text-xs font-medium border border-slate-200">
                        <%= if calendar["color"] || calendar[:color] do %>
                          <span
                            class="w-2 h-2 rounded-full mr-1.5"
                            style={"background-color: #{calendar["color"] || calendar[:color]}"}
                          >
                          </span>
                        <% end %>
                        {Helpers.extract_calendar_display_name(calendar)}
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <%= if length(@integration.calendar_paths || []) > 0 do %>
                    <span>{length(@integration.calendar_paths)} calendars connected</span>
                  <% end %>
                <% end %>
              <% else %>
                <span class="text-gray-500 italic">Integration is currently disabled</span>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Right: Actions -->
        <div class="flex items-center gap-2 flex-shrink-0">
          <StatusSwitch.status_switch
            id={"calendar-toggle-#{@integration.id}"}
            checked={@integration.is_active}
            on_change="toggle_integration"
            target={@myself}
            phx_value_id={to_string(@integration.id)}
            size={:large}
            class="ring-2 ring-turquoise-300/50"
          />

          <%= if @integration.is_active do %>
            <button
              phx-click="manage_calendars"
              phx-value-id={@integration.id}
              phx-target={@myself}
              class="btn btn-sm btn-secondary"
              disabled={@validating_integration_id == @integration.id}
            >
              <%= if @validating_integration_id == @integration.id do %>
                <svg
                  class="animate-spin h-4 w-4 mr-1"
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <circle
                    class="opacity-25"
                    cx="12"
                    cy="12"
                    r="10"
                    stroke="currentColor"
                    stroke-width="4"
                  >
                  </circle>
                  <path
                    class="opacity-75"
                    fill="currentColor"
                    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                  >
                  </path>
                </svg>
                Connecting...
              <% else %>
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                Manage
              <% end %>
            </button>
          <% end %>

          <button
            phx-click="modal_action"
            phx-value-action="show"
            phx-value-modal="delete"
            phx-value-id={@integration.id}
            phx-target={@myself}
            class="text-gray-500 hover:text-red-600 transition-colors p-2"
            title="Delete Integration"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
              />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :available_calendar_providers, :list, required: true
  attr :myself, :any, required: true

  @spec available_providers_section(map()) :: Phoenix.LiveView.Rendered.t()
  def available_providers_section(assigns) do
    ~H"""
    <div class="space-y-8 mt-12">
      <div class="max-w-2xl">
        <h2 class="text-token-2xl font-black text-tymeslot-900 tracking-tight mb-3">Available Providers</h2>
        <p class="text-tymeslot-500 font-medium text-token-lg">
          Choose from our supported calendar providers to sync your availability and prevent double bookings automatically.
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        <%= for descp <- @available_calendar_providers do %>
          <% info = Helpers.provider_card_info(descp.type) %>
          <ProviderCard.provider_card
            provider={info.provider}
            title={descp.display_name}
            description={info.desc}
            button_text={info.btn}
            click_event={info.click}
            target={@myself}
            provider_value={info.provider}
          />
        <% end %>
      </div>
    </div>
    """
  end
end
