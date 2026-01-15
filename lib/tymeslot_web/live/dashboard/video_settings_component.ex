defmodule TymeslotWeb.Dashboard.VideoSettingsComponent do
  @moduledoc """
  LiveComponent for managing video integrations in the dashboard.
  """
  use TymeslotWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Tymeslot.Integrations.Providers.Directory
  alias Tymeslot.Integrations.Video, as: Video
  alias Tymeslot.Security.VideoInputProcessor
  alias Tymeslot.Utils.ChangesetUtils
  alias TymeslotWeb.Components.Dashboard.Integrations.ProviderCard
  alias TymeslotWeb.Components.Dashboard.Integrations.Shared.DeleteIntegrationModal
  alias TymeslotWeb.Components.Dashboard.Integrations.Video.CustomConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Video.MirotalkConfig
  alias TymeslotWeb.Components.Icons.ProviderIcon
  alias TymeslotWeb.Components.UI.StatusSwitch
  alias TymeslotWeb.Helpers.IntegrationProviders
  alias TymeslotWeb.Hooks.ModalHook
  alias TymeslotWeb.Live.Dashboard.Shared.DashboardHelpers
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
     |> assign(:view_mode, :providers)
     |> assign(:config_provider, nil)
     |> assign(:selected_provider, nil)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})
     |> assign(:saving, false)
     |> assign(:testing_connection, nil)
     |> assign(:integration_to_delete, nil)
     |> assign(:available_video_providers, Directory.list(:video))}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_integrations()

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("back_to_providers", _params, socket) do
    {:noreply,
     socket
     |> assign(:view_mode, :providers)
     |> assign(:config_provider, nil)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("setup_provider", %{"provider" => provider}, socket) do
    case provider do
      "google_meet" ->
        user_id = socket.assigns.current_user.id

        case Video.oauth_authorization_url(user_id, :google_meet) do
          {:ok, url} ->
            send(self(), {:external_redirect, url})
            {:noreply, assign(socket, :show_provider_modal, false)}

          {:error, error_message} ->
            send(self(), {:flash, {:error, error_message}})
            {:noreply, socket}
        end

      "teams" ->
        user_id = socket.assigns.current_user.id

        case Video.oauth_authorization_url(user_id, :teams) do
          {:ok, url} ->
            send(self(), {:external_redirect, url})
            {:noreply, assign(socket, :show_provider_modal, false)}

          {:error, error_message} ->
            send(self(), {:flash, {:error, error_message}})
            {:noreply, socket}
        end

      _ ->
        # For manual configuration providers, switch to config page mode
        {:noreply,
         socket
         |> assign(:view_mode, :config)
         |> assign(:config_provider, provider)
         |> assign(:form_errors, %{})
         |> assign(:form_values, %{})}
    end
  end

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("provider_changed", %{"value" => provider}, socket) do
    {:noreply, assign(socket, :config_provider, provider)}
  end

  # Field-specific validation handler
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("validate_field", %{"field" => field, "value" => value}, socket) do
    # Update only the specific field in form_values
    form_values = Map.put(socket.assigns.form_values || %{}, field, value)
    # Ensure provider is always included for validation
    form_values = Map.put_new(form_values, "provider", socket.assigns.config_provider)
    socket = assign(socket, :form_values, form_values)

    metadata = get_security_metadata(socket)

    # Validate all form values to get complete error state
    case VideoInputProcessor.validate_video_integration_form(form_values, metadata: metadata) do
      {:ok, _sanitized_params} ->
        {:noreply, assign(socket, :form_errors, %{})}

      {:error, errors} ->
        # Only show error for the field that was just validated
        field_atom = String.to_existing_atom(field)
        field_error = Map.get(errors, field_atom)

        current_errors = socket.assigns.form_errors || %{}

        updated_errors =
          if field_error do
            Map.put(current_errors, field_atom, field_error)
          else
            Map.delete(current_errors, field_atom)
          end

        {:noreply, assign(socket, :form_errors, updated_errors)}
    end
  rescue
    ArgumentError ->
      # If field doesn't exist as atom, just store the value
      {:noreply, socket}
  end

  def handle_event("add_integration", %{"integration" => params}, socket) do
    metadata = get_security_metadata(socket)

    # First validate the video integration form input
    case VideoInputProcessor.validate_video_integration_form(params, metadata: metadata) do
      {:ok, sanitized_params} ->
        # Merge sanitized params with original params (keeping other fields like provider)
        validated_params = Map.merge(params, sanitized_params)

        # Store form values before attempting to add integration
        socket = assign(socket, :form_values, params)

        user_id = socket.assigns.current_user.id
        provider = validated_params["provider"] || socket.assigns.config_provider

        case Video.create_integration(user_id, provider, map_keys_to_atoms(validated_params)) do
          {:ok, _integration} ->
            send(self(), {:flash, {:info, "Video integration added successfully"}})
            send(self(), {:integration_added, :video})

            {:noreply,
             socket
             |> reset_form_state()
             |> load_integrations()
             |> assign(:form_values, %{})}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply,
             socket
             |> assign(:form_errors, format_changeset_errors(changeset))
             |> assign(:saving, false)}

          {:error, reason} ->
            # Provider pre-validation error (e.g., connection test) returns a string or reason
            {:noreply,
             socket
             |> assign(:saving, false)
             |> put_provider_specific_error(reason)}
        end

      {:error, validation_errors} ->
        # Keep form values on validation error
        {:noreply,
         socket
         |> assign(:form_errors, validation_errors)
         |> assign(:form_values, params)}
    end
  end

  def handle_event("toggle_integration", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Video.toggle_integration(user_id, normalize_id(id)) do
      {:ok, _} ->
        send(self(), {:flash, {:info, "Integration status updated"}})
        send(self(), {:integration_updated, :video})
        {:noreply, load_integrations(socket)}

      {:error, _} ->
        send(self(), {:flash, {:error, "Failed to update integration status"}})
        {:noreply, socket}
    end
  end

  def handle_event("modal_action", %{"action" => action, "modal" => modal} = params, socket) do
    case {action, modal} do
      {"show", "delete"} ->
        # Standardize: store integration_to_delete as integer
        integration_id =
          case params["id"] do
            nil -> nil
            id when is_integer(id) -> id
            id when is_binary(id) -> String.to_integer(id)
          end

        socket =
          socket
          |> ModalHook.show_modal("delete", params["id"])
          |> assign(:integration_to_delete, integration_id)

        {:noreply, socket}

      {"hide", "delete"} ->
        {:noreply,
         socket
         |> ModalHook.hide_modal("delete")
         |> assign(:integration_to_delete, nil)}

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
    case socket.assigns.integration_to_delete do
      nil ->
        {:noreply, socket}

      id ->
        user_id = socket.assigns.current_user.id

        case Video.delete_integration(user_id, id) do
          {:ok, :deleted} ->
            send(self(), {:flash, {:info, "Integration deleted successfully"}})
            send(self(), {:integration_removed, :video})

            {:noreply,
             socket
             |> assign(:show_delete_modal, false)
             |> assign(:integration_to_delete, nil)
             |> load_integrations()}

          {:error, _} ->
            send(self(), {:flash, {:error, "Failed to delete integration"}})
            {:noreply, socket}
        end
    end
  end

  def handle_event("test_connection", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    id = normalize_id(id)
    socket = assign(socket, :testing_connection, id)

    case Video.test_connection(user_id, id) do
      {:ok, message} ->
        send(
          self(),
          {:flash, {:info, format_test_success_message(get_provider_name(socket, id), message)}}
        )

        {:noreply, assign(socket, :testing_connection, nil)}

      {:error, reason} when is_binary(reason) ->
        send(self(), {:flash, {:error, reason}})
        {:noreply, assign(socket, :testing_connection, nil)}

      {:error, reason} ->
        send(self(), {:flash, {:error, "Connection test failed: #{inspect(reason)}"}})
        {:noreply, assign(socket, :testing_connection, nil)}
    end
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <!-- Delete Confirmation Modal -->
      <DeleteIntegrationModal.delete_integration_modal
        id="delete-video-modal"
        show={@show_delete_modal}
        integration_type={:video}
        on_cancel={JS.push("hide_delete_modal", target: @myself)}
        on_confirm={JS.push("delete_integration", target: @myself)}
      />

      <%= if @view_mode == :config do %>
        <!-- Configuration Page Mode -->
        <div
          id="video-config-view"
          phx-hook="ScrollReset"
          data-action={@config_provider}
          class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500"
        >
          <div class="flex items-center gap-6 bg-white p-6 rounded-token-3xl border-2 border-tymeslot-50 shadow-sm">
            <button
              phx-click="back_to_providers"
              phx-target={@myself}
              class="flex items-center gap-2 px-4 py-2 rounded-token-xl bg-tymeslot-50 text-tymeslot-600 font-bold hover:bg-tymeslot-100 transition-all"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
              </svg>
              Back
            </button>

            <div class="h-8 w-px bg-tymeslot-100"></div>

            <div class="flex items-center gap-4">
              <div class="w-12 h-12 bg-turquoise-50 rounded-token-xl flex items-center justify-center border border-turquoise-100 shadow-sm">
                <svg class="w-6 h-6 text-turquoise-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </div>
              <h2 class="text-token-3xl font-black text-tymeslot-900 tracking-tight">
                Setup <%= case @config_provider do
                  "mirotalk" -> "MiroTalk"
                  "custom" -> "Custom Video"
                  _ -> "Video Integration"
                end %>
              </h2>
            </div>
          </div>

          <div class="card-glass">
            <%= case @config_provider do %>
              <% "mirotalk" -> %>
                <.live_component
                  module={MirotalkConfig}
                  id="mirotalk-config"
                  target={@myself}
                  form_errors={@form_errors}
                  form_values={@form_values}
                  saving={@saving}
                />
              <% "custom" -> %>
                <.live_component
                  module={CustomConfig}
                  id="custom-config"
                  target={@myself}
                  form_errors={@form_errors}
                  form_values={@form_values}
                  saving={@saving}
                />
              <% _ -> %>
                <p class="text-tymeslot-500 font-medium">Configuration form not available for this provider.</p>
            <% end %>
          </div>
        </div>
      <% else %>
        <!-- Providers List Mode -->
        <.section_header icon={:video} title="Video Integration" />
        
    <!-- Connected Video Providers Section -->
        <%= if @integrations != [] do %>
          <% {active_integrations, inactive_integrations} = Enum.split_with(@integrations, & &1.is_active) %>
          <% show_section_headers = active_integrations != [] and inactive_integrations != [] %>

          <div class="space-y-6">
            <!-- Active Video Integrations -->
            <%= if active_integrations != [] do %>
              <div class="space-y-3">
                <%= if show_section_headers do %>
                  <h3 class="text-lg font-bold text-turquoise-800">Active Video Integrations</h3>
                <% end %>

                <%= for integration <- active_integrations do %>
                  <.video_row
                    integration={integration}
                    provider_display_name={format_provider_name(integration.provider)}
                    testing_connection={@testing_connection}
                    myself={@myself}
                  />
                <% end %>
              </div>
            <% end %>

            <!-- Inactive Video Integrations -->
            <%= if inactive_integrations != [] do %>
              <div class="space-y-3">
                <%= if show_section_headers do %>
                  <h3 class="text-lg font-semibold text-slate-600">Inactive Video Integrations</h3>
                <% end %>

                <%= for integration <- inactive_integrations do %>
                  <.video_row
                    integration={integration}
                    provider_display_name={format_provider_name(integration.provider)}
                    testing_connection={@testing_connection}
                    myself={@myself}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
        
    <!-- Available Video Providers Section -->
        <div class="space-y-8 mt-12">
          <div class="max-w-2xl">
            <h2 class="text-token-2xl font-black text-tymeslot-900 tracking-tight mb-3">Available Providers</h2>
            <p class="text-tymeslot-500 font-medium text-token-lg">
              Choose from our supported video providers to enable seamless meeting experiences for your clients.
            </p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
            <%= for descp <- @available_video_providers do %>
              <% provider_atom = descp.type %>
              <% provider = Atom.to_string(provider_atom) %>
              <% name = descp.display_name %>
              <% {desc, btn} =
                case provider_atom do
                  :google_meet ->
                    {"Full OAuth integration with automatic room creation", "Connect Google Meet"}

                  :teams ->
                    {"Enterprise OAuth integration with organizational accounts", "Connect Teams"}

                  :mirotalk ->
                    {"Self-hosted peer-to-peer video meetings", "Connect MiroTalk"}

                  :custom ->
                    {"Any video platform with static meeting URLs", "Add Custom Link"}

                  _ ->
                    {"", "Connect"}
                end %>
              <ProviderCard.provider_card
                provider={provider}
                title={name}
                description={desc}
                button_text={btn}
                click_event="setup_provider"
                target={@myself}
                provider_value={provider}
              />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private render components

  defp video_row(assigns) do
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

            <!-- Provider Type -->
            <div class="text-xs text-gray-600 mb-2">
              <%= case @integration.provider do %>
                <% "google_meet" -> %>
                  <span class="font-semibold text-turquoise-700">OAuth Provider</span>
                <% "teams" -> %>
                  <span class="font-semibold text-turquoise-700">OAuth Provider</span>
                <% "mirotalk" -> %>
                  <span class="font-semibold text-blue-700">Self-Hosted</span>
                <% "custom" -> %>
                  <span class="font-semibold text-purple-700">Custom URL</span>
                <% _ -> %>
                  <span class="font-semibold text-gray-600">Video Provider</span>
              <% end %>
            </div>

            <!-- Details -->
            <div class="text-sm text-gray-600">
              <%= if @integration.is_active do %>
                <%= if @integration.provider in ["google_meet", "teams"] do %>
                  <span>Authenticated via OAuth</span>
                <% end %>
                <%= if @integration.base_url do %>
                  <span>{URI.parse(@integration.base_url).host}</span>
                <% end %>
                <%= if Map.get(@integration, :custom_meeting_url) do %>
                  <span>Static meeting URL configured</span>
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
            id={"video-toggle-#{@integration.id}"}
            checked={@integration.is_active}
            on_change="toggle_integration"
            target={@myself}
            phx_value_id={to_string(@integration.id)}
            size={:large}
            class="ring-2 ring-turquoise-300/50"
          />

          <%= if @integration.is_active do %>
            <button
              phx-click="test_connection"
              phx-value-id={@integration.id}
              phx-target={@myself}
              disabled={@testing_connection == @integration.id}
              class="btn btn-sm btn-secondary"
            >
              <%= if @testing_connection == @integration.id do %>
                <svg class="animate-spin h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24">
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
                Testing...
              <% else %>
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                Test
              <% end %>
            </button>
          <% end %>

          <button
            phx-click="show_delete_modal"
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

  # Private functions

  defp load_integrations(socket) do
    user_id = socket.assigns.current_user.id
    integrations = Video.list_integrations(user_id)
    assign(socket, :integrations, integrations)
  end

  defp reset_form_state(socket) do
    socket
    |> assign(:view_mode, :providers)
    |> assign(:config_provider, nil)
    |> assign(:form_errors, %{})
    |> assign(:saving, false)
  end

  defp map_keys_to_atoms(%{} = map) do
    for {k, v} <- map, into: %{} do
      key =
        cond do
          is_atom(k) ->
            k

          is_binary(k) ->
            try do
              String.to_existing_atom(k)
            rescue
              ArgumentError -> k
            end
        end

      {key, v}
    end
  end

  defp format_changeset_errors(%Ecto.Changeset{} = changeset) do
    ChangesetUtils.get_first_error(changeset)
  end

  defp put_provider_specific_error(socket, reason) do
    # Map a provider test error string to a field when possible (mirotalk)
    cond do
      is_binary(reason) and
          (String.contains?(reason, "Invalid API key") or
             String.contains?(reason, "Authentication failed")) ->
        assign(socket, :form_errors, %{api_key: reason})

      is_binary(reason) and
          (String.contains?(reason, "URL") or String.contains?(reason, "Domain") or
             String.contains?(reason, "endpoint")) ->
        assign(socket, :form_errors, %{base_url: reason})

      is_binary(reason) ->
        assign(socket, :form_errors, %{base_url: reason})

      true ->
        assign(socket, :form_errors, %{base_url: "Connection validation failed"})
    end
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)

  defp format_test_success_message(provider, message) do
    case provider do
      "mirotalk" -> "✓ MiroTalk connection verified - #{message}"
      "google_meet" -> "✓ Google Meet connection verified - #{message}"
      "teams" -> "✓ Microsoft Teams connection verified - #{message}"
      "custom" -> "✓ Custom provider configured - #{message}"
      _ -> message
    end
  end

  defp get_provider_name(socket, id) do
    case Enum.find(socket.assigns.integrations, &(&1.id == id)) do
      nil -> ""
      integration -> integration.provider
    end
  end

  defp format_provider_name(provider) do
    IntegrationProviders.format_provider_name(:video, provider)
  end

  # Helper function to get security metadata
  defp get_security_metadata(socket) do
    DashboardHelpers.get_security_metadata(socket)
  end
end
