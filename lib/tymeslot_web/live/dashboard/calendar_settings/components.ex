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
  attr :form_values, :map, required: true
  attr :discovered_calendars, :list, required: true
  attr :show_calendar_selection, :boolean, required: true
  attr :discovery_credentials, :map, required: true
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

        <.section_header
          level={2}
          icon={:calendar}
          title={"Setup #{case @selected_provider do
            :nextcloud -> "Nextcloud"
            :radicale -> "Radicale"
            :caldav -> "CalDAV"
            _ -> "Calendar"
          end}"}
        />
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
              form_values={@form_values}
              discovered_calendars={@discovered_calendars}
              show_calendar_selection={@show_calendar_selection}
              discovery_credentials={@discovery_credentials}
              saving={@is_saving}
            />
          <% :radicale -> %>
            <.live_component
              module={RadicaleConfig}
              id="radicale-config"
              target={@myself}
              metadata={@security_metadata}
              form_errors={@form_errors}
              form_values={@form_values}
              discovered_calendars={@discovered_calendars}
              show_calendar_selection={@show_calendar_selection}
              discovery_credentials={@discovery_credentials}
              saving={@is_saving}
            />
          <% :caldav -> %>
            <.live_component
              module={CaldavConfig}
              id="caldav-config"
              target={@myself}
              metadata={@security_metadata}
              form_errors={@form_errors}
              form_values={@form_values}
              discovered_calendars={@discovered_calendars}
              show_calendar_selection={@show_calendar_selection}
              discovery_credentials={@discovery_credentials}
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
  attr :is_refreshing, :boolean, required: true
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
          <div class="mb-3">
            <div class="flex items-center justify-between gap-4 flex-col md:flex-row">
              <h3 class="text-lg font-bold text-turquoise-800 flex items-center gap-2">
                Active for Conflict Checking
              </h3>
              <button
                phx-click="refresh_all_calendars"
                phx-target={@myself}
                class={[
                  "flex items-center gap-2 px-4 py-2 rounded-token-xl font-bold transition-all border-2 shrink-0",
                  @is_refreshing && "bg-turquoise-50 text-turquoise-400 border-turquoise-200 cursor-not-allowed",
                  !@is_refreshing &&
                    "bg-white text-turquoise-600 border-turquoise-50 hover:bg-turquoise-50 hover:border-turquoise-100"
                ]}
                disabled={@is_refreshing}
              >
                <svg
                  class={["w-5 h-5", @is_refreshing && "animate-spin"]}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2.5"
                    d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                  />
                </svg>
                <%= if @is_refreshing, do: "Refreshing...", else: "Refresh All" %>
              </button>
            </div>
            <p class="text-sm text-turquoise-600 font-medium mt-1 ml-6">
              We'll check these calendars to prevent double bookings
            </p>
          </div>

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
          <h3 class="text-lg font-semibold text-slate-600">Paused Calendars</h3>

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
                  Active for Conflict Checking
                </span>
              <% else %>
                <span class="text-xs font-semibold text-slate-500">
                  ⏸️ Paused
                </span>
              <% end %>
            </div>

            <!-- Details -->
            <div class="mt-4">
              <%= if @integration.is_active do %>
                <div class="flex flex-col gap-3">
                  <div class="flex items-center justify-between">
                    <h5 class="text-[10px] font-black uppercase tracking-wider text-slate-400">
                      Sync selection
                    </h5>
                  </div>

                  <div class="flex flex-wrap gap-2">
                    <%= for calendar <- @integration.calendar_list || [] do %>
                      <% calendar_id = calendar["id"] || calendar[:id] %>
                      <% calendar_name = Helpers.extract_calendar_display_name(calendar) %>
                      <% is_selected = calendar["selected"] || calendar[:selected] %>

                      <button
                        phx-click="toggle_calendar_selection"
                        phx-value-integration_id={@integration.id}
                        phx-value-calendar_id={calendar_id}
                        phx-target={@myself}
                        title={if is_selected, do: "Included in conflict checking", else: "Not included in conflict checking"}
                        class={[
                          "inline-flex items-center gap-2 px-2.5 py-1.5 rounded-token-lg border-2 transition-all select-none text-xs font-bold",
                          is_selected &&
                            "bg-turquoise-50 border-turquoise-400 text-turquoise-900 shadow-sm",
                          !is_selected &&
                            "bg-white border-slate-100 text-slate-500 hover:border-slate-200 hover:bg-slate-50"
                        ]}
                      >
                        <!-- Calendar color indicator - only show when selected -->
                        <%= if (calendar["color"] || calendar[:color]) && is_selected do %>
                          <span
                            class="w-2 h-2 rounded-full shrink-0"
                            style={"background-color: #{calendar["color"] || calendar[:color]}"}
                          >
                          </span>
                        <% end %>

                        <span>{calendar_name}</span>

                        <!-- Primary badge -->
                        <%= if calendar["primary"] || calendar[:primary] do %>
                          <span class="bg-slate-200 text-slate-700 text-[9px] font-black px-1 rounded uppercase tracking-tighter">
                            Primary
                          </span>
                        <% end %>

                        <!-- Checkmark indicator -->
                        <svg
                          :if={is_selected}
                          class="w-3 h-3 text-turquoise-600"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="3"
                            d="M5 13l4 4L19 7"
                          />
                        </svg>
                      </button>
                    <% end %>

                    <%= if !@integration.calendar_list || @integration.calendar_list == [] do %>
                      <p class="text-xs text-slate-500 italic">
                        No calendars discovered. Try refreshing.
                      </p>
                    <% end %>
                  </div>
                </div>
              <% else %>
                <span class="text-gray-500 italic text-sm">Integration is currently disabled</span>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Right: Actions -->
        <div class="flex items-center gap-2 flex-shrink-0">
          <%= if @integration.provider == "google" && Helpers.needs_scope_upgrade?(@integration) do %>
            <button
              phx-click="upgrade_google_scope"
              phx-value-id={@integration.id}
              phx-target={@myself}
              class="btn btn-sm border-amber-200 text-amber-700 hover:bg-amber-50 bg-white"
              title="Upgrade Google Calendar permissions"
            >
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M13 10V3L4 14h7v7l9-11h-7z"
                />
              </svg>
              Upgrade Scope
            </button>
          <% end %>

          <StatusSwitch.status_switch
            id={"calendar-toggle-#{@integration.id}"}
            checked={@integration.is_active}
            on_change="toggle_integration"
            target={@myself}
            phx_value_id={to_string(@integration.id)}
            size={:large}
            class="ring-2 ring-turquoise-300/50"
          />

          <button
            phx-click="show"
            phx-value-id={@integration.id}
            phx-target="#delete-calendar-modal"
            class="text-gray-400 hover:text-red-600 transition-colors p-2"
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
      <div class="max-w-4xl">
        <.section_header
          level={2}
          title="Available Providers"
        />
        <p class="text-tymeslot-500 font-medium text-token-lg ml-1">
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
