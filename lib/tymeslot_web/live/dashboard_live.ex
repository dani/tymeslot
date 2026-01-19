defmodule TymeslotWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView for authenticated users.

  This module serves as the central hub for all dashboard functionality,
  including user settings, integrations, availability management, and more.

  ## Dashboard Extension System

  The dashboard is designed to be extensible, allowing external applications
  (such as the SaaS layer) to inject additional navigation items and components
  without modifying Core code. This maintains strict architectural separation
  while enabling powerful customization.

  ### How Extensions Work

  Extensions are registered via application configuration and consumed at runtime:

  1. **Navigation Extensions** - Add new sidebar menu items
  2. **Component Extensions** - Provide LiveComponents for custom actions

  ### Registering Extensions

  External applications should register extensions during startup using
  `Application.put_env/3`. This is typically done in the application's
  `start/2` callback:

      # In external_app/lib/external_app/application.ex
      defp configure_dashboard_extensions do
        # Register sidebar navigation items
        Application.put_env(:tymeslot, :dashboard_sidebar_extensions, [
          %{
            id: :my_feature,
            label: "My Feature",
            icon: :puzzle,
            path: "/dashboard/my-feature",
            action: :my_feature
          }
        ])

        # Register corresponding components
        Application.put_env(:tymeslot, :dashboard_action_components, %{
          my_feature: ExternalApp.Dashboard.MyFeatureComponent
        })
      end

  ### Extension Schema

  Each sidebar extension must be a map with the following keys:

  - `:id` (atom) - Unique identifier for this extension
  - `:label` (string) - Display text shown in the sidebar
  - `:icon` (atom) - Icon name from `TymeslotWeb.Components.Icons.IconComponents`
  - `:path` (string) - Route path (must start with "/")
  - `:action` (atom) - LiveView action for routing and highlighting

  See `Tymeslot.Dashboard.ExtensionSchema` for validation utilities.

  ### Extension Component Requirements

  Components registered via `:dashboard_action_components` must:

  1. Be a LiveComponent (`use Phoenix.LiveComponent`)
  2. Accept standard dashboard assigns in `update/2`:
     - `current_user` - The authenticated user
     - `profile` - The user's profile
     - `integration_status` - Integration connection status
     - `client_ip` - The client's IP address
     - `user_agent` - The client's User Agent string
     - `shared_data` - Shared dashboard statistics/data

  Example component:

      defmodule ExternalApp.Dashboard.MyFeatureComponent do
        use Phoenix.LiveComponent

        @impl true
        def update(assigns, socket) do
          {:ok, assign(socket, assigns)}
        end

        @impl true
        def render(assigns) do
          ~H\"\"\"
          <div>
            <h1>My Feature</h1>
            <p>User: {@current_user.email}</p>
          </div>
          \"\"\"
        end
      end

  ### Routing for Extensions

  External applications must also register routes. The recommended pattern is:

      # In external_app_web/router.ex
      scope "/dashboard" do
        pipe_through [:browser, :require_authenticated_user]

        live_session :external_dashboard,
          on_mount: [
            {Tymeslot.LiveHooks.AuthLiveSessionHook, :ensure_authenticated},
            TymeslotWeb.Hooks.ClientInfoHook
          ] do
          # Reuse Core's DashboardLive, but with your custom action
          live "/my-feature", TymeslotWeb.DashboardLive, :my_feature
        end
      end

      # Forward remaining routes to Core
      forward "/", TymeslotWeb.Router

  ### Extension Validation

  To ensure extensions are valid at startup:

      alias Tymeslot.Dashboard.ExtensionSchema

      extensions = Application.get_env(:tymeslot, :dashboard_sidebar_extensions, [])

      case ExtensionSchema.validate_all(extensions) do
        :ok -> :ok
        {:error, errors} ->
          Logger.error("Invalid dashboard extensions: \#{inspect(errors)}")
          raise "Dashboard extension validation failed"
      end

  ### Architecture Notes

  This extension system follows the "Dependency Inversion Principle":

  - **Core defines the interface** (config keys, expected structure)
  - **External apps implement the interface** (provide extensions)
  - **Core never knows about external apps** (no imports, no coupling)

  The Core application can run completely standalone without any extensions.
  Extensions are purely additive and optional.

  For more details on the architecture, see `CLAUDE.md` in the project root.
  """

  use TymeslotWeb, :live_view

  alias Tymeslot.Dashboard.DashboardContext
  alias Tymeslot.Integrations.Calendar
  alias Tymeslot.Profiles.Timezone
  alias TymeslotWeb.Components.DashboardLayout
  alias TymeslotWeb.Helpers.PageTitles
  alias TymeslotWeb.Live.InitHelpers

  # Alias dashboard components to satisfy aliasing rules and improve maintainability
  alias TymeslotWeb.Dashboard.{
    BookingsManagementComponent,
    CalendarSettingsComponent,
    DashboardOverviewComponent,
    NotificationSettingsComponent,
    ProfileSettingsComponent,
    ScheduleSettingsComponent,
    ServiceSettingsComponent,
    ThemeSettingsComponent,
    VideoSettingsComponent
  }

  alias TymeslotWeb.Live.Dashboard.EmbedSettingsComponent

  # Dashboard components are loaded dynamically based on the current action

  require Logger

  @impl true
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()} | {:ok, Phoenix.LiveView.Socket.t(), keyword()}
  def mount(_params, _session, socket) do
    InitHelpers.with_user_context(socket, fn socket ->
      connect_params = get_connect_params(socket) || %{}
      detected_timezone = connect_params["timezone"]
      user = socket.assigns.current_user

      socket =
        socket
        |> assign(shared_data: %{})
        |> assign(detected_timezone: detected_timezone)

      socket =
        if user do
          {:ok, socket} = DashboardHelpers.mount_dashboard_common(socket)
          socket
        else
          assign_dev_profile(socket)
        end

      {:ok, load_shared_data(socket)}
    end)
  end

  defp assign_dev_profile(socket) do
    assign(socket, :profile, %{
      id: 1,
      user_id: 1,
      username: "dev-user",
      full_name: "Development User",
      timezone: "Europe/Kyiv",
      buffer_minutes: 15,
      advance_booking_days: 90,
      min_advance_hours: 3,
      avatar: nil,
      booking_theme: "1"
    })
  end

  @impl true
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_params(_params, _url, socket) do
    action = socket.assigns.live_action

    socket =
      socket
      |> assign(:page_title, PageTitles.dashboard_title(action))
      |> load_section_specific_data(action)

    {:noreply, socket}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <DashboardLayout.dashboard_layout
      current_user={@current_user}
      profile={@profile}
      current_action={@live_action}
      integration_status={get_integration_status(assigns)}
    >
      <.flash_group flash={@flash} id="dashboard-flash-group" />

      <!-- Content -->
      <div class="dashboard-content">
        {render_section(assigns)}
      </div>
    </DashboardLayout.dashboard_layout>
    """
  end

  # Handle events from child components
  @impl true
  @spec handle_info({:profile_updated, map()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:profile_updated, profile}, socket) do
    # Invalidate cache when profile is updated
    DashboardContext.invalidate_integration_status(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(profile: profile)
     |> load_shared_data()}
  end

  @spec handle_info({:integration_added, any()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:integration_added, _type}, socket) do
    # Invalidate cache when integrations change
    DashboardContext.invalidate_integration_status(socket.assigns.current_user.id)

    {:noreply, load_shared_data(socket)}
  end

  @spec handle_info({:integration_removed, any()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:integration_removed, _type}, socket) do
    # Invalidate cache when integrations change
    DashboardContext.invalidate_integration_status(socket.assigns.current_user.id)

    {:noreply, load_shared_data(socket)}
  end

  @spec handle_info({:integration_updated, any()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:integration_updated, _type}, socket) do
    # Invalidate cache when integrations are enabled/disabled
    DashboardContext.invalidate_integration_status(socket.assigns.current_user.id)

    {:noreply, load_shared_data(socket)}
  end

  @spec handle_info({:meeting_type_changed}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:meeting_type_changed}, socket) do
    # Invalidate cache when meeting types change
    DashboardContext.invalidate_integration_status(socket.assigns.current_user.id)

    # Reload data based on current section
    if socket.assigns.live_action == :meeting_settings do
      # Force update the service settings component to reload its data
      send_update(ServiceSettingsComponent, id: to_string(:meeting_settings))
    end

    {:noreply, load_shared_data(socket)}
  end

  @spec handle_info({:flash, {atom(), String.t()}}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:flash, {type, message}}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  @spec handle_info({:user_updated, map()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:user_updated, user}, socket) do
    {:noreply, assign(socket, :current_user, user)}
  end

  @impl true
  def handle_info({:clear_reminder_confirmation, component_id}, socket) do
    send_update(TymeslotWeb.Dashboard.MeetingSettings.MeetingTypeForm,
      id: component_id,
      reminder_confirmation: nil
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:refresh_calendar_list, component_id, integration_id}, socket) do
    user_id = socket.assigns.current_user.id
    Calendar.refresh_calendar_list_async(integration_id, user_id, component_id)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:calendar_list_refreshed, component_id, _integration_id, calendars}, socket) do
    send_update(TymeslotWeb.Dashboard.MeetingSettings.MeetingTypeForm,
      id: component_id,
      refreshing_calendars: false,
      available_calendars: calendars
    )

    {:noreply, socket}
  end

  # Handle calendar OAuth redirects directly in the parent LiveView

  # Neutral redirect message from the Video settings component
  @spec handle_info({:video_redirect, String.t()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:video_redirect, url}, socket) when is_binary(url) do
    {:noreply, redirect(socket, external: url)}
  end

  # Generic external redirect message from components
  @spec handle_info({:external_redirect, String.t()}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:external_redirect, url}, socket) when is_binary(url) do
    {:noreply, redirect(socket, external: url)}
  end

  @spec handle_info({:reload_schedule}, Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info({:reload_schedule}, socket) do
    # Refresh the availability component after mutations from child components
    send_update(ScheduleSettingsComponent,
      id: "availability",
      profile: socket.assigns.profile
    )

    {:noreply, socket}
  end

  @spec handle_info(any(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(_msg, socket) do
    # Silently ignore unhandled messages
    {:noreply, socket}
  end

  # Private functions

  @spec render_section(map()) :: Phoenix.LiveView.Rendered.t()
  defp render_section(assigns) do
    assigns =
      assigns
      |> assign(:component_module, component_for_action(assigns.live_action))
      |> assign(:component_props, props_for_action(assigns))

    ~H"""
    <.live_component
      module={@component_module}
      id={to_string(@live_action)}
      current_user={@component_props.current_user}
      profile={@component_props[:profile]}
      shared_data={@component_props[:shared_data]}
      integration_status={@component_props[:integration_status]}
      client_ip={@component_props[:client_ip]}
      user_agent={@component_props[:user_agent]}
    />
    """
  end

  @spec component_for_action(atom()) :: module()
  defp component_for_action(:overview), do: DashboardOverviewComponent
  defp component_for_action(:settings), do: ProfileSettingsComponent

  defp component_for_action(:availability), do: ScheduleSettingsComponent

  defp component_for_action(:meeting_settings), do: ServiceSettingsComponent

  defp component_for_action(:calendar), do: CalendarSettingsComponent
  defp component_for_action(:video), do: VideoSettingsComponent
  defp component_for_action(:notifications), do: NotificationSettingsComponent
  defp component_for_action(:theme), do: ThemeSettingsComponent
  defp component_for_action(:meetings), do: BookingsManagementComponent
  defp component_for_action(:embed), do: EmbedSettingsComponent

  defp component_for_action(action) do
    # Check dynamic components registered via configuration (e.g., by SaaS)
    components = Application.get_env(:tymeslot, :dashboard_action_components, %{})
    Map.get(components, action, DashboardOverviewComponent)
  end

  @spec props_for_action(map()) :: map()
  defp props_for_action(%{live_action: action} = assigns) do
    base_props = %{
      current_user: assigns.current_user,
      profile: assigns.profile,
      integration_status: get_integration_status(assigns),
      client_ip: assigns.client_ip,
      user_agent: assigns.user_agent
    }

    case action do
      :overview ->
        Map.put(base_props, :shared_data, assigns.shared_data)

      :settings ->
        # Prefill timezone for settings using the same logic as onboarding, without persisting
        Map.put(base_props, :profile, apply_timezone_prefill(assigns))

      :availability ->
        # Prefill timezone for availability page using detected browser timezone
        Map.put(base_props, :profile, apply_timezone_prefill(assigns))

      _ ->
        base_props
    end
  end

  @spec apply_timezone_prefill(map()) :: map() | nil
  defp apply_timezone_prefill(assigns) do
    if assigns.profile do
      prefilled_tz =
        Timezone.prefill_timezone(assigns.profile.timezone, assigns[:detected_timezone])

      Map.put(assigns.profile, :timezone, prefilled_tz)
    else
      assigns.profile
    end
  end

  @spec load_shared_data(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp load_shared_data(socket) do
    user = socket.assigns.current_user
    user_id = if user, do: user.id, else: nil
    user_email = if user, do: user.email, else: nil
    action = socket.assigns[:live_action]

    shared_data = DashboardContext.get_data_for_action(action, user_id, user_email)
    assign(socket, :shared_data, shared_data)
  end

  @spec load_section_specific_data(Phoenix.LiveView.Socket.t(), atom()) ::
          Phoenix.LiveView.Socket.t()
  defp load_section_specific_data(socket, action) do
    # Shared data is now consistently loaded in mount or handle_params via load_shared_data
    # We only reload if action changed and data isn't sufficient
    if socket.assigns[:shared_data] && action != :overview &&
         Map.has_key?(socket.assigns.shared_data, :integration_status) do
      socket
    else
      load_shared_data(socket)
    end
  end

  @spec get_integration_status(map()) :: map()
  defp get_integration_status(assigns) do
    # Get integration status from shared_data if available
    if assigns[:shared_data] && assigns.shared_data[:integration_status] do
      assigns.shared_data.integration_status
    else
      # This shouldn't happen since load_shared_data now always sets integration_status
      %{
        has_calendar: false,
        has_video: false,
        has_meeting_types: false,
        calendar_count: 0,
        video_count: 0,
        meeting_types_count: 0
      }
    end
  end
end
