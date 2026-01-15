defmodule TymeslotWeb.Components.Dashboard.Integrations.Calendar.CalendarManagerModal do
  @moduledoc """
  Modal component for managing calendar integrations.
  Handles calendar selection, primary integration settings, and deletion.
  """
  use TymeslotWeb, :live_component

  alias Phoenix.LiveView
  alias TymeslotWeb.Components.CoreComponents
  alias TymeslotWeb.Dashboard.CalendarSettings.Helpers

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
                  {Helpers.format_provider_name(@managing_integration.provider)}
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
                <div class="p-5 bg-slate-50/50 border-2 border-slate-100 rounded-token-2xl">
                  <div class="flex items-center justify-between mb-3">
                    <h4 class="text-sm font-black text-tymeslot-900 flex items-center gap-2">
                      <CoreComponents.icon name="hero-check-circle" class="w-4 h-4 text-turquoise-600" />
                      Select calendars to sync
                    </h4>
                  </div>

                  <div class="flex flex-wrap gap-2 max-h-80 overflow-y-auto pr-2 custom-scrollbar">
                    <%= for calendar <- @managing_integration.calendar_list || [] do %>
                      <% calendar_id = calendar["id"] || calendar[:id] %>
                      <% calendar_name = Helpers.extract_calendar_display_name(calendar) %>
                      <% is_selected = calendar["selected"] || calendar[:selected] %>

                      <div class="relative group">
                        <!-- Clickable tag wrapper with checkbox inside -->
                        <label
                          class={[
                            "inline-flex items-center gap-2 px-3 py-2 rounded-token-xl border-2 cursor-pointer transition-all select-none",
                            is_selected &&
                              "bg-turquoise-50 border-turquoise-400 text-turquoise-900 shadow-sm",
                            !is_selected &&
                              "bg-white border-slate-200 text-slate-600 hover:border-slate-300 hover:bg-slate-50"
                          ]}
                        >
                          <!-- Hidden checkbox for form submission -->
                          <input
                            type="checkbox"
                            name="calendars[selected_calendars][]"
                            value={calendar_id}
                            checked={is_selected}
                            class="sr-only"
                          />

                          <!-- Calendar color indicator -->
                          <%= if calendar["color"] || calendar[:color] do %>
                            <span
                              class="w-2.5 h-2.5 rounded-full shrink-0"
                              style={"background-color: #{calendar["color"] || calendar[:color]}"}
                            >
                            </span>
                          <% end %>

                          <!-- Calendar name -->
                          <span class="text-sm font-bold">
                            {calendar_name}
                          </span>

                          <!-- Primary badge -->
                          <%= if calendar["primary"] || calendar[:primary] do %>
                            <span class="bg-slate-200 text-slate-700 text-[10px] font-black px-1.5 py-0.5 rounded uppercase tracking-wider">
                              Primary
                            </span>
                          <% end %>

                          <!-- Checkmark indicator -->
                          <%= if is_selected do %>
                            <svg
                              class="w-4 h-4 text-turquoise-600 transition-opacity"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                stroke-linecap="round"
                                stroke-linejoin="round"
                                stroke-width="2.5"
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                          <% end %>
                        </label>
                      </div>
                    <% end %>
                  </div>
                </div>
              </form>
            </div>
          <% end %>
        <% end %>

        <:footer>
          <div class="flex items-center justify-between gap-4 w-full">
            <!-- Left: Optional actions -->
            <%= if @managing_integration && @managing_integration.provider == "google" && Helpers.needs_scope_upgrade?(@managing_integration) do %>
              <CoreComponents.action_button
                variant={:outline}
                phx-click="upgrade_google_scope"
                phx-target={@parent}
                class="border-amber-200 text-amber-700 hover:bg-amber-50"
              >
                <CoreComponents.icon name="hero-bolt" class="w-4 h-4 mr-2" />
                Upgrade Scope
              </CoreComponents.action_button>
            <% else %>
              <div></div>
            <% end %>

            <!-- Right: Primary actions -->
            <div class="flex gap-3">
              <CoreComponents.action_button
                variant={:secondary}
                phx-click="hide_calendar_manager"
                phx-target={@parent}
              >
                Cancel
              </CoreComponents.action_button>
              <CoreComponents.action_button
                type="submit"
                form="calendar-selection-form"
                variant={:primary}
                disabled={@loading_calendars}
              >
                <CoreComponents.icon name="hero-check" class="w-4 h-4 mr-2" />
                Save Changes
              </CoreComponents.action_button>
            </div>
          </div>
        </:footer>
      </CoreComponents.modal>
    </div>
    """
  end
end
