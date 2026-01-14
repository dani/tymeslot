defmodule TymeslotWeb.Components.Dashboard.Integrations.Calendar.CalendarManagerModal do
  @moduledoc """
  Modal component for managing calendar integrations.
  Handles calendar selection, primary integration settings, and deletion.
  """
  use TymeslotWeb, :live_component

  alias Phoenix.LiveView
  alias Tymeslot.Integrations.Calendar
  alias TymeslotWeb.Components.CoreComponents

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:loading_calendars, false)
     |> assign(:managing_integration, nil)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("update_calendar_selection", %{"calendars" => params}, socket) do
    # Update the calendar selection state in real-time for UI reactivity
    integration = socket.assigns.managing_integration
    selected_calendar_ids = params["selected_calendars"] || []

    # Update calendar_list with new selection state
    updated_calendar_list =
      Enum.map(integration.calendar_list || [], fn calendar ->
        calendar_id = calendar["id"] || calendar[:id]
        updated_selected = calendar_id in selected_calendar_ids

        calendar
        |> Map.put("selected", updated_selected)
        # Support both string and atom keys
        |> Map.put(:selected, updated_selected)
      end)

    updated_integration = %{integration | calendar_list: updated_calendar_list}

    {:noreply, assign(socket, :managing_integration, updated_integration)}
  end

  def handle_event("save_calendar_selection", %{"calendars" => form_params} = _params, socket) do
    # Build selection payload from current modal state and forward to parent component
    integration = socket.assigns.managing_integration

    selected_ids =
      (integration.calendar_list || [])
      |> Enum.filter(fn cal -> cal["selected"] || cal[:selected] end)
      |> Enum.map(fn cal -> cal["id"] || cal[:id] end)

    # Merge computed selections into the inner calendars form params
    calendars_params = Map.put(form_params, "selected_calendars", selected_ids)

    LiveView.send_update(
      TymeslotWeb.Dashboard.CalendarSettingsComponent,
      id: "calendar",
      event: "save_calendar_selection",
      params: %{"calendars" => calendars_params}
    )

    {:noreply, socket}
  end

  def handle_event("upgrade_google_scope", _params, socket) do
    send(self(), {:upgrade_google_scope, socket.assigns.managing_integration.id})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <CoreComponents.modal
        id="calendar-manager-modal"
        show={@show}
        on_cancel={JS.push("hide_calendar_manager", target: @parent)}
        size={:large}
      >
        <:header>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-turquoise-50 rounded-token-xl flex items-center justify-center border border-turquoise-100">
              <CoreComponents.icon name="hero-calendar" class="w-6 h-6 text-turquoise-600" />
            </div>
            <div class="flex flex-col">
              <span class="text-2xl font-black text-tymeslot-900 tracking-tight">Manage Integration</span>
              <%= if @managing_integration do %>
                <span class="text-tymeslot-500 font-medium text-token-sm">
                  {format_provider_name(@managing_integration.provider)}
                  <%= if Map.get(@managing_integration, :is_primary, false) do %>
                    • <span class="text-turquoise-600 font-bold">Booking Calendar</span>
                  <% end %>
                </span>
              <% end %>
            </div>
          </div>
        </:header>

        <%= if @managing_integration do %>
          <%= if @loading_calendars do %>
            <div class="text-center py-20">
              <CoreComponents.spinner />
              <p class="mt-4 text-tymeslot-600 font-medium">Discovering calendars...</p>
            </div>
          <% else %>
            <div class="space-y-8">
              <form
                id="calendar-selection-form"
                phx-submit="save_calendar_selection"
                phx-change="update_calendar_selection"
                phx-target={@myself}
              >
                <!-- Calendar Selection -->
                <div class="space-y-4">
                  <h4 class="text-token-base font-black text-tymeslot-900 flex items-center gap-2">
                    <CoreComponents.icon name="hero-check-circle" class="w-5 h-5 text-turquoise-600" />
                    Select calendars to sync
                  </h4>
                  <div class="space-y-2 max-h-80 overflow-y-auto pr-2 custom-scrollbar">
                    <%= for calendar <- @managing_integration.calendar_list || [] do %>
                      <label class="flex items-center p-4 rounded-token-2xl border-2 border-tymeslot-50 bg-white hover:border-turquoise-200 hover:bg-turquoise-50/10 cursor-pointer transition-all group">
                        <input
                          type="checkbox"
                          name="calendars[selected_calendars][]"
                          value={calendar["id"] || calendar[:id]}
                          checked={calendar["selected"] || calendar[:selected]}
                          class="h-5 w-5 text-turquoise-600 focus:ring-turquoise-500 border-tymeslot-300 rounded-token-lg transition-all"
                        />
                        <div class="ml-4 flex-1">
                          <div class="flex items-center gap-2">
                            <span class="font-black text-tymeslot-900">
                              {calendar["name"] || calendar[:name] || "Calendar"}
                            </span>
                            <%= if calendar["primary"] || calendar[:primary] do %>
                              <span class="bg-tymeslot-100 text-tymeslot-600 text-token-xs font-black px-2 py-0.5 rounded-full uppercase tracking-wider">Primary</span>
                            <% end %>
                          </div>
                          <%= if calendar["owner"] || calendar[:owner] do %>
                            <span class="text-token-xs text-tymeslot-500 font-medium">
                              Owner: {calendar["owner"] || calendar[:owner]}
                            </span>
                          <% end %>
                        </div>
                        <%= if calendar["color"] || calendar[:color] do %>
                          <div
                            class="w-5 h-5 rounded-full border-2 border-white shadow-sm shrink-0"
                            style={"background-color: #{calendar["color"] || calendar[:color]}"}
                          >
                          </div>
                        <% end %>
                      </label>
                    <% end %>
                  </div>
                </div>
                
                <!-- Booking Calendar Selection -->
                <div class="mt-8">
                  <%= if Map.get(@managing_integration, :is_primary, false) do %>
                    <div class="space-y-4">
                      <h4 class="text-token-base font-black text-tymeslot-900 flex items-center gap-2">
                        <CoreComponents.icon name="hero-plus-circle" class="w-5 h-5 text-turquoise-600" />
                        Where should new bookings be created?
                      </h4>
                      <div class="relative">
                        <select
                          name="calendars[default_booking_calendar]"
                          required
                          class="w-full pl-4 pr-10 py-4 rounded-token-2xl border-2 border-tymeslot-100 bg-tymeslot-50/50 text-tymeslot-900 font-medium focus:border-turquoise-400 focus:bg-white focus:ring-0 transition-all appearance-none"
                        >
                          <option value="">Select a calendar...</option>
                          <%= for calendar <- @managing_integration.calendar_list || [], 
                          calendar["selected"] || calendar[:selected] do %>
                            <option
                              value={calendar["id"] || calendar[:id]}
                              selected={
                                (calendar["id"] || calendar[:id]) ==
                                  @managing_integration.default_booking_calendar_id
                              }
                            >
                              {calendar["name"] || calendar[:name] || "Calendar"}
                              <%= if calendar["primary"] || calendar[:primary] do %>(Primary)<% end %>
                            </option>
                          <% end %>
                        </select>
                        <div class="absolute inset-y-0 right-0 flex items-center pr-4 pointer-events-none text-tymeslot-400">
                          <CoreComponents.icon name="hero-chevron-down" class="w-5 h-5" />
                        </div>
                      </div>
                      <p class="text-token-sm text-tymeslot-500 font-medium">
                        New meetings will be created in this calendar. You can change this anytime.
                      </p>
                    </div>
                  <% else %>
                    <div class="p-6 bg-turquoise-50/50 border-2 border-turquoise-100 rounded-token-2xl">
                      <div class="flex items-start gap-4">
                        <div class="w-10 h-10 bg-turquoise-100 rounded-token-xl flex items-center justify-center shrink-0">
                          <CoreComponents.icon name="hero-information-circle" class="w-6 h-6 text-turquoise-600" />
                        </div>
                        <div>
                          <h4 class="text-token-base font-black text-turquoise-900">Sync-Only Integration</h4>
                          <p class="text-turquoise-700 font-medium mt-1">
                            This integration checks for conflicts but doesn't receive new bookings.
                            To use it for creating bookings, click "Use for Bookings" in the header.
                          </p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
              </form>
            </div>
          <% end %>
        <% end %>

        <:footer>
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4 w-full">
            <div class="flex items-center gap-3 w-full sm:w-auto">
              <%= if @managing_integration && @managing_integration.provider == "google" && needs_scope_upgrade?(@managing_integration) do %>
                <CoreComponents.action_button
                  variant={:outline}
                  phx-click="upgrade_google_scope"
                  phx-target={@parent}
                  class="flex-1 sm:flex-none border-amber-200 text-amber-700 hover:bg-amber-50"
                >
                  <CoreComponents.icon name="hero-bolt" class="w-4 h-4 mr-2" />
                  Upgrade Scope
                </CoreComponents.action_button>
              <% end %>
              
              <%= if @managing_integration && @managing_integration.is_active && not Map.get(@managing_integration, :is_primary, false) do %>
                <CoreComponents.action_button
                  variant={:secondary}
                  phx-click="set_as_primary"
                  phx-target={@parent}
                  phx-value-id={@managing_integration.id}
                  class="flex-1 sm:flex-none border-emerald-200 text-emerald-700 hover:bg-emerald-50"
                >
                  <CoreComponents.icon name="hero-star" class="w-4 h-4 mr-2" />
                  Use for Bookings
                </CoreComponents.action_button>
              <% end %>
            </div>

            <div class="flex gap-3 w-full sm:w-auto">
              <CoreComponents.action_button
                variant={:secondary}
                phx-click="hide_calendar_manager"
                phx-target={@parent}
                class="flex-1 sm:flex-none"
              >
                Cancel
              </CoreComponents.action_button>
              <CoreComponents.action_button
                type="submit"
                form="calendar-selection-form"
                variant={:primary}
                disabled={@loading_calendars}
                class="flex-1 sm:flex-none"
              >
                Save Changes
              </CoreComponents.action_button>
            </div>
          </div>
        </:footer>
      </CoreComponents.modal>
    </div>
    """
  end

  defp format_provider_name(provider) do
    case provider do
      "google" -> "Google Calendar"
      "outlook" -> "Outlook Calendar"
      "nextcloud" -> "Nextcloud"
      "caldav" -> "CalDAV"
      _ -> String.capitalize(provider)
    end
  end

  defp needs_scope_upgrade?(integration) do
    Calendar.needs_scope_upgrade?(integration)
  end
end
