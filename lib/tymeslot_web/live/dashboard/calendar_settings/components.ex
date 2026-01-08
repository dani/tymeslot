defmodule TymeslotWeb.Dashboard.CalendarSettings.Components do
  @moduledoc """
  Functional components for the calendar settings dashboard.
  """
  use TymeslotWeb, :html

  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.CaldavConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.NextcloudConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.RadicaleConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.IntegrationCard
  alias TymeslotWeb.Components.Dashboard.Integrations.ProviderCard
  alias TymeslotWeb.Dashboard.CalendarSettings.Helpers

  attr :selected_provider, :atom, required: true
  attr :myself, :any, required: true
  attr :security_metadata, :map, required: true
  attr :form_errors, :map, required: true
  attr :is_saving, :boolean, required: true

  @spec config_view(map()) :: Phoenix.LiveView.Rendered.t()
  def config_view(assigns) do
    ~H"""
    <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div class="flex items-center justify-between bg-white p-6 rounded-token-3xl border-2 border-tymeslot-50 shadow-sm">
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
    ~H"""
    <div :if={@integrations != []} class="space-y-6">
      <div class="flex items-center gap-3">
        <h2 class="text-token-2xl font-black text-tymeslot-900 tracking-tight">Connected Calendars</h2>
        <span class="bg-turquoise-100 text-turquoise-700 text-xs font-black px-3 py-1 rounded-full uppercase tracking-wider">
          {length(@integrations)} active
        </span>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        <%= for integration <- @integrations do %>
          <IntegrationCard.integration_card
            integration={integration}
            integration_type={:calendar}
            provider_display_name={Helpers.format_provider_name(integration.provider)}
            token_expiry_text={Helpers.format_token_expiry(integration)}
            needs_scope_upgrade={Helpers.needs_scope_upgrade?(integration)}
            testing_connection={@testing_integration_id}
            checking_connection={@validating_integration_id}
            myself={@myself}
          />
        <% end %>
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
