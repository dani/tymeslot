defmodule TymeslotWeb.Dashboard.CalendarSettingsComponent do
  @moduledoc """
  LiveComponent for managing calendar integrations in the dashboard.
  """
  use TymeslotWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Tymeslot.Integrations.{Calendar, CalendarPrimary}
  alias Tymeslot.Utils.ChangesetUtils
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.CalendarManagerModal
  alias TymeslotWeb.Components.Dashboard.Integrations.Shared.DeleteIntegrationModal
  alias TymeslotWeb.Dashboard.CalendarSettings.{Components, Helpers}
  alias TymeslotWeb.Hooks.ModalHook
  alias TymeslotWeb.Live.Dashboard.Shared.DashboardHelpers
  alias TymeslotWeb.Live.Shared.Flash
  require Logger

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    modal_configs = [
      {:delete, false}
    ]

    {:ok,
     socket
     |> ModalHook.mount_modal(modal_configs)
     |> assign(:integrations, [])
     |> assign(:view, :providers)
     |> assign(:selected_provider, nil)
     |> assign(:discovered_calendars, [])
     |> assign(:show_calendar_selection, false)
     |> assign(:discovery_credentials, %{})
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})
     |> assign(:is_saving, false)
     |> assign(:testing_integration_id, nil)
     |> assign(:pending_delete_integration_id, nil)
     |> assign(:show_calendar_manager, false)
     |> assign(:managing_integration, nil)
     |> assign(:is_loading_calendars, false)
     |> assign(:validating_integration_id, nil)
     |> assign(:available_calendar_providers, Calendar.list_available_providers(:calendar))}
  end

  # Removed handle_info callbacks - events now come directly via phx-target

  @spec handle_info({:upgrade_google_scope, integer()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:upgrade_google_scope, integration_id}, socket) do
    handle_event("upgrade_google_scope", %{"id" => to_string(integration_id)}, socket)
  end

  @spec handle_info(:hide_calendar_manager, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(:hide_calendar_manager, socket) do
    handle_event("hide_calendar_manager", %{}, socket)
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    # First, assign incoming assigns and load integrations
    socket =
      socket
      |> assign(assigns)
      |> load_integrations()

    # Ensure security_metadata is available
    socket =
      assign_new(socket, :security_metadata, fn ->
        DashboardHelpers.get_security_metadata(socket)
      end)

    # Handle events from any parent-driven modal interactions
    socket =
      case {assigns[:event], assigns[:params]} do
        {"add_integration", %{"integration" => params}} ->
          {_, socket} = handle_event("add_integration", %{"integration" => params}, socket)
          socket

        {"save_calendar_selection", %{"calendars" => calendars_params}} ->
          {_, socket} =
            handle_event("save_calendar_selection", %{"calendars" => calendars_params}, socket)

          socket

        _ ->
          socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_event("back_to_providers", _params, socket) do
    {:noreply, reset_integration_form_state(socket)}
  end

  # Provider config state and validation are now owned by provider config components

  def handle_event("add_integration", %{"integration" => params} = full_params, socket) do
    socket = assign(socket, :is_saving, true)
    metadata = get_security_metadata(socket)
    socket = assign(socket, :form_values, params)

    processed_params = merge_selected_calendar_params(full_params, params, socket)

    case create_integration_with_validation(processed_params, metadata, socket) do
      {:ok, socket} -> {:noreply, socket}
      {:error, socket} -> {:noreply, socket}
    end
  end

  def handle_event("toggle_integration", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    # Capture primary before toggle
    before_primary_id =
      case CalendarPrimary.get_primary_calendar_integration(user_id) do
        {:ok, primary} -> primary.id
        _ -> nil
      end

    case Calendar.toggle_integration(to_int!(id), user_id) do
      {:ok, _integration} ->
        # Reload integrations and determine if primary changed
        after_primary = CalendarPrimary.get_primary_calendar_integration(user_id)

        Flash.info(Helpers.flash_message_for_primary_change(before_primary_id, after_primary))

        # Notify parent LiveView that integration status has changed
        send(self(), {:integration_updated, :calendar})
        {:noreply, load_integrations(socket)}
    end
  end

  def handle_event("modal_action", %{"action" => action, "modal" => modal} = params, socket) do
    case {action, modal} do
      {"show", "delete"} ->
        Logger.info("Showing delete modal for integration ID: #{params["id"]}")

        socket =
          socket
          |> ModalHook.show_modal("delete", params["id"])
          |> assign(:pending_delete_integration_id, String.to_integer(params["id"]))

        {:noreply, socket}

      {"hide", "delete"} ->
        {:noreply,
         socket
         |> ModalHook.hide_modal("delete")
         |> assign(:pending_delete_integration_id, nil)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    handle_event("modal_action", %{"action" => "show", "modal" => "delete", "id" => id}, socket)
  end

  def handle_event("hide_delete_modal", _params, socket) do
    handle_event("modal_action", %{"action" => "hide", "modal" => "delete"}, socket)
  end

  def handle_event("delete_integration", _params, socket) do
    case socket.assigns.pending_delete_integration_id do
      nil ->
        {:noreply, socket}

      id ->
        {:noreply, delete_integration_and_reset_ui(id, socket.assigns.current_user.id, socket)}
    end
  end

  def handle_event("connect_google_calendar", _params, socket) do
    user_id = socket.assigns.current_user.id

    case Calendar.initiate_google_oauth(user_id) do
      {:ok, authorization_url} ->
        send(self(), {:external_redirect, authorization_url})
        {:noreply, assign(socket, :show_provider_modal, false)}

      {:error, error_message} ->
        Flash.error(error_message)
        {:noreply, socket}
    end
  end

  def handle_event("connect_outlook_calendar", _params, socket) do
    user_id = socket.assigns.current_user.id

    case Calendar.initiate_outlook_oauth(user_id) do
      {:ok, authorization_url} ->
        send(self(), {:external_redirect, authorization_url})
        {:noreply, assign(socket, :show_provider_modal, false)}

      {:error, error_message} ->
        Flash.error(error_message)
        {:noreply, socket}
    end
  end

  def handle_event("connect_nextcloud_calendar", _params, socket) do
    {:noreply,
     socket
     |> assign(:view, :config)
     |> assign(:selected_provider, :nextcloud)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  def handle_event("connect_caldav_calendar", _params, socket) do
    {:noreply,
     socket
     |> assign(:view, :config)
     |> assign(:selected_provider, :caldav)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  def handle_event("connect_radicale_calendar", _params, socket) do
    {:noreply,
     socket
     |> assign(:view, :config)
     |> assign(:selected_provider, :radicale)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  def handle_event("test_connection", %{"id" => id}, socket) do
    socket = assign(socket, :testing_integration_id, to_int!(id))

    case Calendar.get_integration(to_int!(id), socket.assigns.current_user.id) do
      {:ok, integration} ->
        case Calendar.test_connection(integration) do
          {:ok, message} ->
            Flash.info(message)
            {:noreply, assign(socket, :testing_integration_id, nil)}

          {:error, reason} ->
            Flash.error("Connection test failed: #{inspect(reason)}")
            {:noreply, assign(socket, :testing_integration_id, nil)}
        end

      {:error, :not_found} ->
        {:noreply, assign(socket, :testing_integration_id, nil)}
    end
  end

  def handle_event("manage_calendars", %{"id" => id}, socket) do
    integration_id = to_int!(id)
    integration = Enum.find(socket.assigns.integrations, &(&1.id == integration_id))

    case integration do
      nil ->
        {:noreply, socket}

      integration ->
        # Set loading state for this specific integration
        socket = assign(socket, :validating_integration_id, integration_id)

        # Validate the calendar connection first
        case validate_calendar_connection(integration, socket) do
          {:ok, validated_integration} ->
            # Connection is good, proceed to open modal
            socket =
              socket
              |> assign(:validating_integration_id, nil)
              |> prepare_calendar_manager(validated_integration)
              |> discover_calendars(validated_integration)

            {:noreply, socket}

          {:error, reason} ->
            # Connection failed, show error and clear loading state
            error_message = Calendar.connection_error_message(reason)
            Flash.error(error_message)

            {:noreply, assign(socket, :validating_integration_id, nil)}
        end
    end
  end

  def handle_event("save_calendar_selection", %{"calendars" => params}, socket) do
    integration = socket.assigns.managing_integration

    case Calendar.update_calendar_selection(integration, params) do
      {:ok, _updated} ->
        Flash.info("Calendar selection updated successfully")

        {:noreply,
         socket
         |> assign(:show_calendar_manager, false)
         |> assign(:managing_integration, nil)
         |> load_integrations()}

      {:error, _reason} ->
        Flash.error("Failed to update calendar selection")
        {:noreply, socket}
    end
  end

  def handle_event("hide_calendar_manager", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_calendar_manager, false)
     |> assign(:managing_integration, nil)}
  end

  def handle_event("set_as_primary", %{"id" => id}, socket) do
    integration_id = to_int!(id)
    user_id = socket.assigns.current_user.id

    # Find the integration to see its provider
    _integration = Enum.find(socket.assigns.integrations, &(&1.id == integration_id))

    case Calendar.set_primary(user_id, integration_id) do
      {:ok, _integration} ->
        Flash.info("Primary calendar integration updated successfully")

        # Check if we're currently in the manage modal
        if socket.assigns.show_calendar_manager do
          # Update the managing_integration with new primary status
          updated_integration =
            Map.put(socket.assigns.managing_integration, :is_primary, true)

          {:noreply,
           discover_calendars(
             assign(
               assign(load_integrations(socket), :managing_integration, updated_integration),
               :is_loading_calendars,
               true
             ),
             updated_integration
           )}
        else
          # Called from card, auto-open manage modal for the new primary
          {:noreply,
           discover_calendars(
             assign(
               assign(
                 assign(
                   load_integrations(socket),
                   :managing_integration,
                   Enum.find(socket.assigns.integrations, &(&1.id == integration_id))
                 ),
                 :show_calendar_manager,
                 true
               ),
               :is_loading_calendars,
               true
             ),
             Enum.find(socket.assigns.integrations, fn int -> int.id == integration_id end)
           )}
        end

      {:error, _reason} ->
        Flash.error("Failed to set primary calendar integration")
        {:noreply, socket}
    end
  end

  def handle_event("upgrade_google_scope", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    integration_id = to_int!(id)

    case Calendar.initiate_google_scope_upgrade(user_id, integration_id) do
      {:ok, authorization_url} ->
        send(self(), {:external_redirect, authorization_url})
        {:noreply, socket}

      {:error, :invalid_provider} ->
        Flash.error("Integration is not a Google Calendar")
        {:noreply, socket}

      {:error, :not_found} ->
        Flash.error("Integration not found")
        {:noreply, socket}

      {:error, error_message} when is_binary(error_message) ->
        Flash.error(error_message)
        {:noreply, socket}
    end
  end

  defp merge_selected_calendar_params(full_params, params, socket) do
    case Map.get(full_params, "selected_calendars") do
      nil ->
        params

      [] ->
        Map.put(params, "calendar_paths", "")

      calendars when is_list(calendars) ->
        discovered_calendars = socket.assigns[:discovered_calendars] || []
        selection = Calendar.prepare_selection_params(calendars, discovered_calendars)
        Map.merge(params, selection)

      _ ->
        params
    end
  end

  defp create_integration_with_validation(params, metadata, socket) do
    user_id = socket.assigns.current_user.id

    case Calendar.create_integration_with_validation(user_id, params, metadata: metadata) do
      {:ok, integration} ->
        on_integration_created(integration, socket)

      {:error, {:form_errors, validation_errors}} ->
        {:error,
         socket
         |> assign(:form_errors, validation_errors)
         |> assign(:is_saving, false)}

      {:error, {:changeset, %Ecto.Changeset{} = changeset}} ->
        on_integration_create_error(changeset, socket)

      {:error, reason} ->
        {:error,
         socket
         |> assign(:form_errors, %{generic: [to_string(reason)]})
         |> assign(:is_saving, false)}
    end
  end

  defp on_integration_created(_integration, socket) do
    send(self(), {:integration_added, :calendar})
    Flash.info("Calendar integration added successfully")

    {:ok,
     socket
     |> reset_integration_form_state()
     |> assign(:is_saving, false)
     |> load_integrations()}
  end

  defp on_integration_create_error(changeset, socket) do
    errors = ChangesetUtils.get_first_error(changeset)

    {:error,
     socket
     |> assign(:form_errors, errors)
     |> assign(:is_saving, false)}
  end

  defp reset_integration_form_state(socket) do
    socket
    |> assign(:view, :providers)
    |> assign(:selected_provider, nil)
    |> assign(:discovered_calendars, [])
    |> assign(:show_calendar_selection, false)
    |> assign(:discovery_credentials, %{})
    |> assign(:form_errors, %{})
    |> assign(:form_values, %{})
  end

  defp delete_integration_and_reset_ui(id, user_id, socket) do
    case Calendar.delete_with_primary_reassignment_and_invalidate(user_id, id) do
      {:ok, _} ->
        send(self(), {:integration_removed, :calendar})
        Flash.info("Integration deleted successfully")

        socket
        |> load_integrations()
        |> assign(:show_delete_modal, false)
        |> assign(:pending_delete_integration_id, nil)
        |> assign(:show_calendar_manager, false)
        |> assign(:managing_integration, nil)

      {:error, :not_found} ->
        socket
        |> assign(:show_delete_modal, false)
        |> assign(:pending_delete_integration_id, nil)
        |> assign(:show_calendar_manager, false)
        |> assign(:managing_integration, nil)

      {:error, _} ->
        Flash.error("Failed to delete integration")

        socket
        |> assign(:show_delete_modal, false)
        |> assign(:pending_delete_integration_id, nil)
        |> assign(:show_calendar_manager, false)
        |> assign(:managing_integration, nil)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <!-- Shared Delete Modal for Calendar Integrations -->
      <DeleteIntegrationModal.delete_integration_modal
        id="delete-calendar-modal"
        show={@show_delete_modal}
        integration_type={:calendar}
        on_cancel={JS.push("hide_delete_modal", target: @myself)}
        on_confirm={JS.push("delete_integration", target: @myself)}
      />

      <%= if @view == :config do %>
        <Components.config_view
          selected_provider={@selected_provider}
          myself={@myself}
          security_metadata={@security_metadata}
          form_errors={@form_errors}
          is_saving={@is_saving}
        />
      <% else %>
        <!-- Providers List Mode -->
        <.section_header icon={:calendar} title="Calendar Integration" />

        <Components.connected_calendars_section
          integrations={@integrations}
          testing_integration_id={@testing_integration_id}
          validating_integration_id={@validating_integration_id}
          myself={@myself}
        />

        <Components.available_providers_section
          available_calendar_providers={@available_calendar_providers}
          myself={@myself}
        />
      <% end %>

      <!-- Calendar Management Modal -->
      <.live_component
        module={CalendarManagerModal}
        id="calendar-manager-modal"
        show={@show_calendar_manager}
        managing_integration={@managing_integration}
        loading_calendars={@is_loading_calendars}
        parent={@myself}
      />
    </div>
    """
  end

  # Private helper functions for view rendering

  defp prepare_calendar_manager(socket, integration) do
    socket
    |> assign(:managing_integration, integration)
    |> assign(:show_calendar_manager, true)
    |> assign(:is_loading_calendars, true)
  end

  defp discover_calendars(socket, integration) do
    case Calendar.update_integration_with_discovery(integration) do
      {:ok, updated_integration} ->
        socket
        |> assign(:managing_integration, updated_integration)
        |> assign(:is_loading_calendars, false)

      {:error, reason} ->
        Flash.error("Failed to discover calendars: #{inspect(reason)}")
        assign(socket, :is_loading_calendars, false)
    end
  end

  # Calendar connection validation
  defp validate_calendar_connection(integration, socket) do
    user_id = socket.assigns.current_user.id
    Calendar.validate_connection_with_timeout(integration, user_id, timeout: 10_000)
  end

  # Helper function to get security metadata
  defp get_security_metadata(socket) do
    DashboardHelpers.get_security_metadata(socket)
  end

  # Small utility for ID parsing
  defp to_int!(id) when is_binary(id), do: String.to_integer(id)
  defp to_int!(id) when is_integer(id), do: id

  # Load integrations from context and assign
  defp load_integrations(socket) do
    integrations = Calendar.list_integrations(socket.assigns.current_user.id)
    assign(socket, :integrations, integrations)
  end
end
