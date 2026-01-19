defmodule TymeslotWeb.Dashboard.NotificationSettingsComponent do
  @moduledoc """
  LiveComponent for managing notifications in the dashboard.
  Currently supports webhooks, with plans for Slack and other integrations.
  """
  use TymeslotWeb, :live_component

  require Logger

  alias Phoenix.LiveView.JS
  alias Tymeslot.Security.WebhookInputProcessor
  alias Tymeslot.Webhooks
  alias Tymeslot.Webhooks.Security, as: WebhookSecurity
  alias TymeslotWeb.Components.Icons.IconComponents
  alias TymeslotWeb.Dashboard.Notifications.Components
  alias TymeslotWeb.Dashboard.Notifications.Helpers, as: NotificationHelpers
  alias TymeslotWeb.Dashboard.Notifications.Modals

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    modal_configs = [
      {:delete, false},
      {:create, false},
      {:edit, false},
      {:deliveries, false}
    ]

    {:ok,
     socket
     |> ModalHook.mount_modal(modal_configs)
     |> assign(:webhooks, [])
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})
     |> assign(:saving, false)
     |> assign(:testing_connection, nil)
     |> assign(:webhook_to_delete, nil)
     |> assign(:webhook_to_edit, nil)
     |> assign(:selected_webhook, nil)
     |> assign(:deliveries, [])
     |> assign(:delivery_stats, nil)
     |> assign(:available_events, Webhooks.available_events())}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> load_webhooks()

    {:ok, socket}
  end

  @impl true
  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("show_create_modal", _params, socket) do
    {:noreply,
     socket
     |> ModalHook.show_modal(:create)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{
       "name" => "",
       "url" => "",
       "secret" => "",
       "events" => []
     })}
  end

  def handle_event("hide_create_modal", _params, socket) do
    {:noreply,
     socket
     |> ModalHook.hide_modal(:create)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  def handle_event("generate_secret", _params, socket) do
    secret = WebhookSecurity.generate_secret()
    form_values = Map.put(socket.assigns.form_values, "secret", secret)

    {:noreply, assign(socket, :form_values, form_values)}
  end

  def handle_event("validate_field", %{"field" => field, "value" => value}, socket) do
    metadata = NotificationHelpers.get_security_metadata(socket)

    updated_errors =
      NotificationHelpers.validate_field(
        socket.assigns.form_values,
        socket.assigns.form_errors,
        field,
        value,
        metadata
      )

    {:noreply,
     socket
     |> assign(:form_values, Map.put(socket.assigns.form_values, field, value))
     |> assign(:form_errors, updated_errors)}
  end

  def handle_event("toggle_event", %{"event" => event}, socket) do
    form_values = NotificationHelpers.toggle_event(socket.assigns.form_values, event)
    {:noreply, assign(socket, :form_values, form_values)}
  end

  def handle_event("create_webhook", %{"webhook" => params}, socket) do
    metadata = NotificationHelpers.get_security_metadata(socket)

    case WebhookInputProcessor.validate_webhook_form(params, metadata: metadata) do
      {:ok, sanitized} ->
        user_id = socket.assigns.current_user.id

        case Webhooks.create_webhook(user_id, sanitized) do
          {:ok, _webhook} ->
            Flash.info("Webhook created successfully")

            {:noreply,
             socket
             |> ModalHook.hide_modal(:create)
             |> assign(:form_errors, %{})
             |> assign(:form_values, %{})
             |> load_webhooks()}

          {:error, changeset} ->
            errors = NotificationHelpers.format_changeset_errors(changeset)
            Flash.error("Failed to create webhook")
            {:noreply, assign(socket, :form_errors, errors)}
        end

      {:error, errors} ->
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    webhook_id = NotificationHelpers.parse_id(id)

    case Webhooks.get_webhook(webhook_id, user_id) do
      {:ok, webhook} ->
        {:noreply,
         socket
         |> ModalHook.show_modal(:edit)
         |> assign(:webhook_to_edit, webhook)
         |> assign(:form_errors, %{})
         |> assign(:form_values, %{
           "name" => webhook.name,
           "url" => webhook.url,
           "secret" => webhook.secret || "",
           "events" => webhook.events
         })}

      {:error, _} ->
        Flash.error("Webhook not found")
        {:noreply, socket}
    end
  end

  def handle_event("hide_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> ModalHook.hide_modal(:edit)
     |> assign(:webhook_to_edit, nil)
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})}
  end

  def handle_event("update_webhook", %{"webhook" => params}, socket) do
    case socket.assigns.webhook_to_edit do
      nil ->
        {:noreply, socket}

      webhook ->
        metadata = NotificationHelpers.get_security_metadata(socket)

        case WebhookInputProcessor.validate_webhook_form(params, metadata: metadata) do
          {:ok, sanitized} ->
            case Webhooks.update_webhook(webhook, sanitized) do
              {:ok, _webhook} ->
                Flash.info("Webhook updated successfully")

                {:noreply,
                 socket
                 |> ModalHook.hide_modal(:edit)
                 |> assign(:webhook_to_edit, nil)
                 |> assign(:form_errors, %{})
                 |> assign(:form_values, %{})
                 |> load_webhooks()}

              {:error, changeset} ->
                errors = NotificationHelpers.format_changeset_errors(changeset)
                Flash.error("Failed to update webhook")
                {:noreply, assign(socket, :form_errors, errors)}
            end

          {:error, errors} ->
            {:noreply, assign(socket, :form_errors, errors)}
        end
    end
  end

  def handle_event("show_delete_modal", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> ModalHook.show_modal(:delete)
     |> assign(:webhook_to_delete, NotificationHelpers.parse_id(id))}
  end

  def handle_event("hide_delete_modal", _params, socket) do
    {:noreply,
     socket
     |> ModalHook.hide_modal(:delete)
     |> assign(:webhook_to_delete, nil)}
  end

  def handle_event("delete_webhook", _params, socket) do
    case socket.assigns.webhook_to_delete do
      nil ->
        {:noreply, socket}

      id ->
        user_id = socket.assigns.current_user.id

        case Webhooks.get_webhook(id, user_id) do
          {:ok, webhook} ->
            case Webhooks.delete_webhook(webhook) do
              {:ok, _} ->
                Flash.info("Webhook deleted successfully")

                {:noreply,
                 socket
                 |> ModalHook.hide_modal(:delete)
                 |> assign(:webhook_to_delete, nil)
                 |> load_webhooks()}

              {:error, _} ->
                Flash.error("Failed to delete webhook")
                {:noreply, socket}
            end

          {:error, _} ->
            Flash.error("Webhook not found")
            {:noreply, socket}
        end
    end
  end

  def handle_event("toggle_webhook", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    webhook_id = NotificationHelpers.parse_id(id)

    case Webhooks.get_webhook(webhook_id, user_id) do
      {:ok, webhook} ->
        case Webhooks.toggle_webhook(webhook) do
          {:ok, _} ->
            Flash.info("Webhook status updated")
            {:noreply, load_webhooks(socket)}

          {:error, _} ->
            Flash.error("Failed to update webhook status")
            {:noreply, socket}
        end

      {:error, _} ->
        Flash.error("Webhook not found")
        {:noreply, socket}
    end
  end

  def handle_event("test_connection", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    webhook_id = NotificationHelpers.parse_id(id)

    socket = assign(socket, :testing_connection, webhook_id)

    case Webhooks.get_webhook(webhook_id, user_id) do
      {:ok, webhook} ->
        case Webhooks.test_webhook_connection(webhook.url, webhook.secret) do
          :ok ->
            Flash.info("Webhook test successful! Check your endpoint.")
            {:noreply, assign(socket, :testing_connection, nil)}

          {:error, reason} ->
            Flash.error("Test failed: #{reason}")
            {:noreply, assign(socket, :testing_connection, nil)}
        end

      {:error, _} ->
        Flash.error("Webhook not found")
        {:noreply, assign(socket, :testing_connection, nil)}
    end
  end

  def handle_event("show_deliveries", %{"id" => id}, socket) do
    webhook_id = NotificationHelpers.parse_id(id)
    user_id = socket.assigns.current_user.id

    case Webhooks.get_webhook(webhook_id, user_id) do
      {:ok, webhook} ->
        deliveries = Webhooks.list_deliveries(webhook_id, limit: 50)
        stats = Webhooks.get_delivery_stats(webhook_id, days: 7)

        {:noreply,
         socket
         |> ModalHook.show_modal(:deliveries)
         |> assign(:selected_webhook, webhook)
         |> assign(:deliveries, deliveries)
         |> assign(:delivery_stats, stats)}

      {:error, _} ->
        Flash.error("Webhook not found")
        {:noreply, socket}
    end
  end

  def handle_event("hide_deliveries", _params, socket) do
    {:noreply,
     socket
     |> ModalHook.hide_modal(:deliveries)
     |> assign(:selected_webhook, nil)
     |> assign(:deliveries, [])
     |> assign(:delivery_stats, nil)}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <.section_header icon={:bell} title="Notifications" />

      <!-- Tabs Navigation -->
      <div class="flex flex-wrap gap-4 bg-tymeslot-50/50 p-2 rounded-[2rem] border-2 border-tymeslot-50 mb-10">
        <div 
          class="flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-token-2xl text-token-sm font-black uppercase tracking-widest transition-all duration-300 border-2 bg-white border-white text-turquoise-600 shadow-xl shadow-tymeslot-200/50 scale-[1.02] cursor-default"
        >
          <IconComponents.icon name={:webhook} class="w-5 h-5" />
          <span>Webhooks</span>
        </div>
        
        <div 
          class="flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-token-2xl text-token-sm font-black uppercase tracking-widest transition-all duration-300 border-2 bg-transparent border-transparent text-tymeslot-400 opacity-60 cursor-not-allowed"
        >
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M6 12.5C6 11.1193 7.11929 10 8.5 10C9.88071 10 11 11.1193 11 12.5C11 13.8807 9.88071 15 8.5 15C7.11929 15 6 13.8807 6 12.5Z" />
            <path fill-rule="evenodd" clip-rule="evenodd" d="M2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12ZM12 4C7.58172 4 4 7.58172 4 12C4 16.4183 7.58172 20 12 20C16.4183 20 20 16.4183 20 12C20 7.58172 16.4183 4 12 4Z" />
          </svg>
          <span>Slack</span>
          <span class="ml-2 text-[10px] bg-tymeslot-100 px-2 py-0.5 rounded-full uppercase tracking-tighter">Coming Soon</span>
        </div>
      </div>

      <!-- Create/Edit Webhook Modal -->
      <Modals.webhook_form_modal
        show={@show_create_modal || @show_edit_modal}
        mode={if @show_create_modal, do: :create, else: :edit}
        form_values={@form_values}
        form_errors={@form_errors}
        available_events={@available_events}
        saving={@saving}
        on_cancel={
          if @show_create_modal do
            JS.push("hide_create_modal", target: @myself)
          else
            JS.push("hide_edit_modal", target: @myself)
          end
        }
        on_submit={
          if @show_create_modal do
            JS.push("create_webhook", target: @myself)
          else
            JS.push("update_webhook", target: @myself)
          end
        }
        on_generate_secret={JS.push("generate_secret", target: @myself)}
        on_toggle_event={fn event -> JS.push("toggle_event", value: %{"event" => event}, target: @myself) end}
        on_validate_field={fn field, value -> JS.push("validate_field", value: %{"field" => field, "value" => value}, target: @myself) end}
        myself={@myself}
      />

      <!-- Delete Confirmation Modal -->
      <Modals.delete_webhook_modal
        show={@show_delete_modal}
        on_cancel={JS.push("hide_delete_modal", target: @myself)}
        on_confirm={JS.push("delete_webhook", target: @myself)}
      />

      <!-- Deliveries Modal -->
      <%= if @show_deliveries_modal do %>
        <Modals.deliveries_modal
          show={@show_deliveries_modal}
          webhook={@selected_webhook}
          deliveries={@deliveries}
          stats={@delivery_stats}
          on_close={JS.push("hide_deliveries", target: @myself)}
        />
      <% end %>

      <!-- Tab Content -->
      <div class="space-y-12">
        <!-- Connected Webhooks Section -->
        <%= if @webhooks != [] do %>
          <div class="space-y-6">
            <div class="flex items-center justify-between">
              <.section_header
                level={2}
                title="Your Webhooks"
                count={length(@webhooks)}
              />
              <button
                phx-click="show_create_modal"
                phx-target={@myself}
                class="btn-primary"
              >
                Create Webhook
              </button>
            </div>

            <div class="grid grid-cols-1 gap-6">
              <%= for webhook <- @webhooks do %>
                <Components.webhook_card
                  webhook={webhook}
                  testing={@testing_connection == webhook.id}
                  on_edit={JS.push("show_edit_modal", value: %{"id" => webhook.id}, target: @myself)}
                  on_delete={JS.push("show_delete_modal", value: %{"id" => webhook.id}, target: @myself)}
                  on_toggle={JS.push("toggle_webhook", value: %{"id" => webhook.id}, target: @myself)}
                  on_test={JS.push("test_connection", value: %{"id" => webhook.id}, target: @myself)}
                  on_view_deliveries={JS.push("show_deliveries", value: %{"id" => webhook.id}, target: @myself)}
                />
              <% end %>
            </div>
          </div>
        <% else %>
          <!-- Empty State -->
          <Components.webhook_empty_state on_create={JS.push("show_create_modal", target: @myself)} />
        <% end %>

        <!-- Documentation Section -->
        <Components.webhook_documentation />
      </div>

    </div>
    """
  end

  # Private functions

  defp load_webhooks(socket) do
    user_id = socket.assigns.current_user.id
    webhooks = Webhooks.list_webhooks(user_id)
    assign(socket, :webhooks, webhooks)
  end
end
