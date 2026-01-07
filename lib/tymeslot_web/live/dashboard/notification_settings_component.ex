defmodule TymeslotWeb.Dashboard.NotificationSettingsComponent do
  @moduledoc """
  LiveComponent for managing notifications in the dashboard.
  Currently supports webhooks, with plans for Slack and other integrations.
  """
  use TymeslotWeb, :live_component

  require Logger

  alias Ecto.Changeset
  alias Phoenix.LiveView.JS
  alias Tymeslot.Security.WebhookInputProcessor
  alias Tymeslot.Webhooks
  alias Tymeslot.Webhooks.Security, as: WebhookSecurity
  alias TymeslotWeb.Components.DashboardComponents
  alias TymeslotWeb.Components.Icons.IconComponents
  alias TymeslotWeb.Hooks.ModalHook
  alias TymeslotWeb.Live.Dashboard.Shared.DashboardHelpers

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
    form_values = Map.put(socket.assigns.form_values, field, value)
    socket = assign(socket, :form_values, form_values)

    metadata = get_security_metadata(socket)

    case WebhookInputProcessor.validate_webhook_form(form_values, metadata: metadata) do
      {:ok, _sanitized} ->
        {:noreply, assign(socket, :form_errors, %{})}

      {:error, errors} ->
        field_atom = String.to_existing_atom(field)
        field_error = Map.get(errors, field_atom)
        current_errors = socket.assigns.form_errors

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
      {:noreply, socket}
  end

  def handle_event("toggle_event", %{"event" => event}, socket) do
    current_events = Map.get(socket.assigns.form_values, "events", [])

    new_events =
      if event in current_events do
        List.delete(current_events, event)
      else
        [event | current_events]
      end

    form_values = Map.put(socket.assigns.form_values, "events", new_events)

    {:noreply, assign(socket, :form_values, form_values)}
  end

  def handle_event("create_webhook", %{"webhook" => params}, socket) do
    metadata = get_security_metadata(socket)

    case WebhookInputProcessor.validate_webhook_form(params, metadata: metadata) do
      {:ok, sanitized} ->
        user_id = socket.assigns.current_user.id

        case Webhooks.create_webhook(user_id, sanitized) do
          {:ok, _webhook} ->
            send(self(), {:flash, {:info, "Webhook created successfully"}})

            {:noreply,
             socket
             |> ModalHook.hide_modal(:create)
             |> assign(:form_errors, %{})
             |> assign(:form_values, %{})
             |> load_webhooks()}

          {:error, changeset} ->
            errors = extract_changeset_errors(changeset)
            send(self(), {:flash, {:error, "Failed to create webhook"}})
            {:noreply, assign(socket, :form_errors, errors)}
        end

      {:error, errors} ->
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("show_edit_modal", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Webhooks.get_webhook(String.to_integer(id), user_id) do
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
        send(self(), {:flash, {:error, "Webhook not found"}})
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
        metadata = get_security_metadata(socket)

        case WebhookInputProcessor.validate_webhook_form(params, metadata: metadata) do
          {:ok, sanitized} ->
            case Webhooks.update_webhook(webhook, sanitized) do
              {:ok, _webhook} ->
                send(self(), {:flash, {:info, "Webhook updated successfully"}})

                {:noreply,
                 socket
                 |> ModalHook.hide_modal(:edit)
                 |> assign(:webhook_to_edit, nil)
                 |> assign(:form_errors, %{})
                 |> assign(:form_values, %{})
                 |> load_webhooks()}

              {:error, changeset} ->
                errors = extract_changeset_errors(changeset)
                send(self(), {:flash, {:error, "Failed to update webhook"}})
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
     |> assign(:webhook_to_delete, String.to_integer(id))}
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
                send(self(), {:flash, {:info, "Webhook deleted successfully"}})

                {:noreply,
                 socket
                 |> ModalHook.hide_modal(:delete)
                 |> assign(:webhook_to_delete, nil)
                 |> load_webhooks()}

              {:error, _} ->
                send(self(), {:flash, {:error, "Failed to delete webhook"}})
                {:noreply, socket}
            end

          {:error, _} ->
            send(self(), {:flash, {:error, "Webhook not found"}})
            {:noreply, socket}
        end
    end
  end

  def handle_event("toggle_webhook", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Webhooks.get_webhook(String.to_integer(id), user_id) do
      {:ok, webhook} ->
        case Webhooks.toggle_webhook(webhook) do
          {:ok, _} ->
            send(self(), {:flash, {:info, "Webhook status updated"}})
            {:noreply, load_webhooks(socket)}

          {:error, _} ->
            send(self(), {:flash, {:error, "Failed to update webhook status"}})
            {:noreply, socket}
        end

      {:error, _} ->
        send(self(), {:flash, {:error, "Webhook not found"}})
        {:noreply, socket}
    end
  end

  def handle_event("test_connection", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    webhook_id = String.to_integer(id)

    socket = assign(socket, :testing_connection, webhook_id)

    case Webhooks.get_webhook(webhook_id, user_id) do
      {:ok, webhook} ->
        case Webhooks.test_webhook_connection(webhook.url, webhook.secret) do
          :ok ->
            send(self(), {:flash, {:info, "Webhook test successful! Check your endpoint."}})
            {:noreply, assign(socket, :testing_connection, nil)}

          {:error, reason} ->
            send(self(), {:flash, {:error, "Test failed: #{reason}"}})
            {:noreply, assign(socket, :testing_connection, nil)}
        end

      {:error, _} ->
        send(self(), {:flash, {:error, "Webhook not found"}})
        {:noreply, assign(socket, :testing_connection, nil)}
    end
  end

  def handle_event("show_deliveries", %{"id" => id}, socket) do
    webhook_id = String.to_integer(id)
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
        send(self(), {:flash, {:error, "Webhook not found"}})
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
      <!-- Create/Edit Webhook Modal -->
      <%= if @show_create_modal || @show_edit_modal do %>
        <.webhook_form_modal
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
      <% end %>

      <!-- Delete Confirmation Modal -->
      <%= if @show_delete_modal do %>
        <.delete_webhook_modal
          show={@show_delete_modal}
          on_cancel={JS.push("hide_delete_modal", target: @myself)}
          on_confirm={JS.push("delete_webhook", target: @myself)}
        />
      <% end %>

      <!-- Deliveries Modal -->
      <%= if @show_deliveries_modal do %>
        <.deliveries_modal
          show={@show_deliveries_modal}
          webhook={@selected_webhook}
          deliveries={@deliveries}
          stats={@delivery_stats}
          on_close={JS.push("hide_deliveries", target: @myself)}
        />
      <% end %>

      <!-- Header -->
      <DashboardComponents.section_header
        icon={:bell}
        title="Notifications"
      />

      <!-- Tabs Navigation -->
      <div class="flex flex-wrap gap-4 bg-slate-50/50 p-2 rounded-[2rem] border-2 border-slate-50 mb-10">
        <div 
          class="flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all duration-300 border-2 bg-white border-white text-turquoise-600 shadow-xl shadow-slate-200/50 scale-[1.02] cursor-default"
        >
          <IconComponents.icon name={:webhook} class="w-5 h-5" />
          <span>Webhooks</span>
        </div>
        
        <div 
          class="flex-1 flex items-center justify-center gap-3 px-6 py-4 rounded-2xl text-sm font-black uppercase tracking-widest transition-all duration-300 border-2 bg-transparent border-transparent text-slate-400 opacity-60 cursor-not-allowed"
        >
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
            <path d="M6 12.5C6 11.1193 7.11929 10 8.5 10C9.88071 10 11 11.1193 11 12.5C11 13.8807 9.88071 15 8.5 15C7.11929 15 6 13.8807 6 12.5Z" />
            <path fill-rule="evenodd" clip-rule="evenodd" d="M2 12C2 6.47715 6.47715 2 12 2C17.5228 2 22 6.47715 22 12C22 17.5228 17.5228 22 12 22C6.47715 22 2 17.5228 2 12ZM12 4C7.58172 4 4 7.58172 4 12C4 16.4183 7.58172 20 12 20C16.4183 20 20 16.4183 20 12C20 7.58172 16.4183 4 12 4Z" />
          </svg>
          <span>Slack</span>
          <span class="ml-2 text-[10px] bg-slate-100 px-2 py-0.5 rounded-full uppercase tracking-tighter">Coming Soon</span>
        </div>
      </div>

      <!-- Tab Content -->
      <div class="space-y-12">
        <!-- Connected Webhooks Section -->
        <%= if @webhooks != [] do %>
          <div class="space-y-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <h2 class="text-2xl font-black text-slate-900 tracking-tight">Your Webhooks</h2>
                <span class="bg-turquoise-100 text-turquoise-700 text-xs font-black px-3 py-1 rounded-full uppercase tracking-wider">
                  <%= length(@webhooks) %> configured
                </span>
              </div>
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
                <.webhook_card
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
          <.webhook_empty_state on_create={JS.push("show_create_modal", target: @myself)} />
        <% end %>

        <!-- Documentation Section -->
        <.webhook_documentation />
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

  defp get_security_metadata(socket) do
    DashboardHelpers.get_security_metadata(socket)
  end

  defp extract_changeset_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # Component functions

  defp webhook_card(assigns) do
    ~H"""
    <div class="card-glass">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center gap-3 mb-2">
            <h3 class="text-xl font-black text-slate-900"><%= @webhook.name %></h3>
            <%= if @webhook.is_active do %>
              <span class="bg-green-100 text-green-700 text-xs font-black px-2 py-1 rounded-full">ACTIVE</span>
            <% else %>
              <span class="bg-slate-200 text-slate-600 text-xs font-black px-2 py-1 rounded-full">INACTIVE</span>
            <% end %>
          </div>

          <div class="text-sm text-slate-600 font-medium mb-3 font-mono truncate">
            <%= @webhook.url %>
          </div>

          <div class="flex flex-wrap gap-2 mb-4">
            <%= for event <- @webhook.events do %>
              <span class="bg-turquoise-50 text-turquoise-700 text-xs font-bold px-2 py-1 rounded-lg border border-turquoise-100">
                <%= event %>
              </span>
            <% end %>
          </div>

          <%= if @webhook.last_triggered_at do %>
            <div class="text-sm text-slate-500">
              Last triggered: <%= format_datetime(@webhook.last_triggered_at) %>
              <%= if @webhook.last_status do %>
                (<span class={status_color(@webhook.last_status)}><%= @webhook.last_status %></span>)
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex items-center gap-2 ml-4">
          <button
            phx-click={@on_test}
            disabled={@testing}
            class="btn-secondary text-sm"
            title="Test Connection"
          >
            <%= if @testing do %>
              <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            <% else %>
              <IconComponents.icon name={:webhook} class="w-4 h-4" />
            <% end %>
            Test
          </button>

          <button phx-click={@on_view_deliveries} class="btn-secondary text-sm" title="View Deliveries">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Logs
          </button>

          <button phx-click={@on_toggle} class="btn-secondary text-sm" title={if @webhook.is_active, do: "Disable", else: "Enable"}>
            <%= if @webhook.is_active do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            <% end %>
          </button>

          <button phx-click={@on_edit} class="btn-secondary text-sm" title="Edit">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
          </button>

          <button phx-click={@on_delete} class="btn-danger text-sm" title="Delete">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp webhook_empty_state(assigns) do
    ~H"""
    <div class="card-glass text-center py-16">
      <div class="w-20 h-20 bg-turquoise-50 rounded-3xl mx-auto mb-6 flex items-center justify-center border-2 border-turquoise-100">
        <IconComponents.icon name={:webhook} class="w-10 h-10 text-turquoise-600" />
      </div>

      <h3 class="text-2xl font-black text-slate-900 mb-3">No Webhooks Yet</h3>
      <p class="text-slate-600 font-medium mb-8 max-w-md mx-auto">
        Set up webhooks to automatically trigger actions in n8n, Zapier, or your custom tools when bookings are created, cancelled, or rescheduled.
      </p>

      <button phx-click={@on_create} class="btn-primary">
        Create Your First Webhook
      </button>
    </div>
    """
  end

  defp webhook_documentation(assigns) do
    ~H"""
    <div class="card-glass space-y-6">
      <h3 class="text-2xl font-black text-slate-900">Setting Up Webhooks</h3>

      <div class="space-y-4">
        <div>
          <h4 class="text-lg font-black text-slate-900 mb-2">What are webhooks?</h4>
          <p class="text-slate-600 font-medium">
            Webhooks send real-time notifications to your automation tools (like n8n, Zapier, Make) when booking events occur in Tymeslot.
          </p>
        </div>

        <div>
          <h4 class="text-lg font-black text-slate-900 mb-2">Quick Setup with n8n</h4>
          <ol class="list-decimal list-inside space-y-2 text-slate-600 font-medium ml-4">
            <li>Create a new workflow in n8n</li>
            <li>Add a "Webhook" trigger node and copy the URL</li>
            <li>Click "Add Webhook" above and paste the URL</li>
            <li>Select which events to listen for</li>
            <li>Click "Test Connection" to verify</li>
            <li>Build your automation workflow in n8n!</li>
          </ol>
        </div>

        <div>
          <h4 class="text-lg font-black text-slate-900 mb-2">Available Events</h4>
          <ul class="space-y-2 text-slate-600 font-medium">
            <li><span class="font-black">meeting.created</span> - When a new booking is made</li>
            <li><span class="font-black">meeting.cancelled</span> - When a booking is cancelled</li>
            <li><span class="font-black">meeting.rescheduled</span> - When a booking time is changed</li>
          </ul>
        </div>

        <div>
          <h4 class="text-lg font-black text-slate-900 mb-2">Security</h4>
          <p class="text-slate-600 font-medium mb-2">
            Webhooks can include a secret key for HMAC signature verification. The signature is sent in the <code class="bg-slate-100 px-2 py-1 rounded text-sm">X-Tymeslot-Signature</code> header.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp webhook_form_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      phx-click={@on_cancel}
      id="webhook-form-modal"
    >
      <div class="flex items-center justify-center min-h-screen px-4">
        <div class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm transition-opacity"></div>

        <div
          class="relative bg-white rounded-3xl shadow-2xl max-w-2xl w-full p-8 space-y-6"
          phx-click="stop_propagation"
        >
          <!-- Header -->
          <div class="flex items-center justify-between">
            <h2 class="text-3xl font-black text-slate-900">
              <%= if @mode == :create, do: "Create Webhook", else: "Edit Webhook" %>
            </h2>
            <button
              phx-click={@on_cancel}
              class="text-slate-400 hover:text-slate-600 transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <form phx-submit={@on_submit} phx-target={@myself}>
            <!-- Name Field -->
            <div class="space-y-2">
              <label class="block text-sm font-black text-slate-900">Webhook Name *</label>
              <input
                type="text"
                name="webhook[name]"
                value={Map.get(@form_values, "name", "")}
                phx-blur={JS.push("validate_field", value: %{"field" => "name", "value" => ""}, target: @myself)}
                class="input-base"
                placeholder="My n8n Automation"
                required
              />
              <%= if error = Map.get(@form_errors, :name) do %>
                <p class="text-sm text-red-600 font-medium"><%= error %></p>
              <% end %>
            </div>

            <!-- URL Field -->
            <div class="space-y-2 mt-4">
              <label class="block text-sm font-black text-slate-900">Webhook URL *</label>
              <input
                type="url"
                name="webhook[url]"
                value={Map.get(@form_values, "url", "")}
                phx-blur={JS.push("validate_field", value: %{"field" => "url", "value" => ""}, target: @myself)}
                class="input-base font-mono text-sm"
                placeholder="https://your-n8n-instance.com/webhook/..."
                required
              />
              <%= if error = Map.get(@form_errors, :url) do %>
                <p class="text-sm text-red-600 font-medium"><%= error %></p>
              <% end %>
            </div>

            <!-- Secret Field -->
            <div class="space-y-2 mt-4">
              <label class="block text-sm font-black text-slate-900">
                Secret Key (Optional)
                <span class="text-slate-500 font-medium">- for HMAC signature verification</span>
              </label>
              <div class="flex gap-2">
                <input
                  type="text"
                  name="webhook[secret]"
                  value={Map.get(@form_values, "secret", "")}
                  class="input-base font-mono text-sm flex-1"
                  placeholder="Leave empty or generate a secure key"
                />
                <button
                  type="button"
                  phx-click={@on_generate_secret}
                  class="btn-secondary whitespace-nowrap"
                >
                  Generate
                </button>
              </div>
              <p class="text-xs text-slate-500 font-medium">
                The secret will be used to sign webhook payloads for security verification.
              </p>
            </div>

            <!-- Events Selection -->
            <div class="space-y-3 mt-6">
              <label class="block text-sm font-black text-slate-900">Events to Subscribe *</label>
              <div class="space-y-2">
                <%= for event <- @available_events do %>
                  <label class="flex items-start gap-3 p-4 rounded-xl border-2 border-slate-100 hover:border-turquoise-200 cursor-pointer transition-colors">
                    <input
                      type="checkbox"
                      name="webhook[events][]"
                      value={event.value}
                      checked={event.value in Map.get(@form_values, "events", [])}
                      phx-click={@on_toggle_event.(event.value)}
                      class="mt-1 w-5 h-5 text-turquoise-600 rounded border-slate-300 focus:ring-turquoise-500"
                    />
                    <div class="flex-1">
                      <div class="font-black text-slate-900"><%= event.label %></div>
                      <div class="text-sm text-slate-600 font-medium"><%= event.description %></div>
                    </div>
                  </label>
                <% end %>
              </div>
              <%= if error = Map.get(@form_errors, :events) do %>
                <p class="text-sm text-red-600 font-medium"><%= error %></p>
              <% end %>
            </div>

            <!-- Actions -->
            <div class="flex justify-end gap-3 mt-8">
              <button type="button" phx-click={@on_cancel} class="btn-secondary">
                Cancel
              </button>
              <button type="submit" class="btn-primary" disabled={@saving}>
                <%= if @saving do %>
                  <svg class="w-5 h-5 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Saving...
                <% else %>
                  <%= if @mode == :create, do: "Create Webhook", else: "Update Webhook" %>
                <% end %>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp delete_webhook_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      phx-click={@on_cancel}
      id="delete-webhook-modal"
    >
      <div class="flex items-center justify-center min-h-screen px-4">
        <div class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm transition-opacity"></div>

        <div
          class="relative bg-white rounded-3xl shadow-2xl max-w-md w-full p-8 space-y-6"
          phx-click="stop_propagation"
        >
          <div class="flex items-center justify-center w-16 h-16 mx-auto bg-red-100 rounded-full">
            <svg class="w-8 h-8 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
          </div>

          <div class="text-center">
            <h3 class="text-2xl font-black text-slate-900 mb-2">Delete Webhook?</h3>
            <p class="text-slate-600 font-medium">
              This action cannot be undone. All delivery logs for this webhook will also be deleted.
            </p>
          </div>

          <div class="flex gap-3">
            <button
              phx-click={@on_cancel}
              class="flex-1 btn-secondary"
            >
              Cancel
            </button>
            <button
              phx-click={@on_confirm}
              class="flex-1 btn-danger"
            >
              Delete Webhook
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp deliveries_modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 overflow-y-auto"
      phx-click={@on_close}
      id="deliveries-modal"
    >
      <div class="flex items-center justify-center min-h-screen px-4">
        <div class="fixed inset-0 bg-slate-900/50 backdrop-blur-sm transition-opacity"></div>

        <div
          class="relative bg-white rounded-3xl shadow-2xl max-w-4xl w-full p-8 space-y-6 max-h-[90vh] overflow-y-auto"
          phx-click="stop_propagation"
        >
          <!-- Header -->
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-3xl font-black text-slate-900"><%= @webhook.name %></h2>
              <p class="text-slate-600 font-medium font-mono text-sm"><%= @webhook.url %></p>
            </div>
            <button
              phx-click={@on_close}
              class="text-slate-400 hover:text-slate-600 transition-colors"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Stats -->
          <%= if @stats do %>
            <div class="grid grid-cols-3 gap-4">
              <div class="bg-slate-50 rounded-2xl p-4">
                <div class="text-sm font-black text-slate-600 uppercase tracking-wider">Total</div>
                <div class="text-3xl font-black text-slate-900 mt-1"><%= @stats.total %></div>
                <div class="text-xs text-slate-500 font-medium mt-1">Last <%= @stats.period_days %> days</div>
              </div>
              <div class="bg-green-50 rounded-2xl p-4">
                <div class="text-sm font-black text-green-600 uppercase tracking-wider">Success</div>
                <div class="text-3xl font-black text-green-700 mt-1"><%= @stats.successful %></div>
                <div class="text-xs text-green-600 font-medium mt-1"><%= @stats.success_rate %>% success rate</div>
              </div>
              <div class="bg-red-50 rounded-2xl p-4">
                <div class="text-sm font-black text-red-600 uppercase tracking-wider">Failed</div>
                <div class="text-3xl font-black text-red-700 mt-1"><%= @stats.failed %></div>
                <div class="text-xs text-red-600 font-medium mt-1">Deliveries failed</div>
              </div>
            </div>
          <% end %>

          <!-- Deliveries List -->
          <div>
            <h3 class="text-lg font-black text-slate-900 mb-4">Recent Deliveries</h3>
            <%= if @deliveries == [] do %>
              <div class="text-center py-12 bg-slate-50 rounded-2xl">
                <p class="text-slate-600 font-medium">No deliveries yet</p>
              </div>
            <% else %>
              <div class="space-y-3">
                <%= for delivery <- @deliveries do %>
                  <div class="border-2 border-slate-100 rounded-2xl p-4 hover:border-slate-200 transition-colors">
                    <div class="flex items-start justify-between">
                      <div class="flex-1">
                        <div class="flex items-center gap-3 mb-2">
                          <span class="bg-turquoise-50 text-turquoise-700 text-xs font-black px-2 py-1 rounded-lg">
                            <%= delivery.event_type %>
                          </span>
                          <%= if delivery.response_status do %>
                            <span class={[
                              "text-xs font-black px-2 py-1 rounded-lg",
                              if(delivery.response_status >= 200 and delivery.response_status < 300,
                                do: "bg-green-100 text-green-700",
                                else: "bg-red-100 text-red-700"
                              )
                            ]}>
                              <%= delivery.response_status %>
                            </span>
                          <% end %>
                          <span class="text-xs text-slate-500 font-medium">
                            Attempt <%= delivery.attempt_count %>
                          </span>
                        </div>
                        <div class="text-sm text-slate-600 font-medium">
                          <%= format_datetime(delivery.inserted_at) %>
                        </div>
                        <%= if delivery.error_message do %>
                          <div class="text-sm text-red-600 font-medium mt-2">
                            Error: <%= delivery.error_message %>
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="flex justify-end">
            <button phx-click={@on_close} class="btn-primary">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")
  end

  defp status_color("success"), do: "text-green-600 font-bold"
  defp status_color("failed"), do: "text-red-600 font-bold"
  defp status_color(_), do: "text-slate-600 font-medium"
end
