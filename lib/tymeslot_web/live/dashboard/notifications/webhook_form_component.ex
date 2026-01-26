defmodule TymeslotWeb.Dashboard.Notifications.WebhookFormComponent do
  @moduledoc """
  Component for creating and editing webhooks.
  Displays a full-page form similar to theme customization.
  """
  use TymeslotWeb, :live_component

  alias Phoenix.LiveView.JS
  alias Tymeslot.Webhooks
  alias TymeslotWeb.Components.CoreComponents

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_errors, %{})
     |> assign(:form_values, %{})
     |> assign(:saving, false)
     |> assign(:available_events, Webhooks.available_events())}
  end

  @impl true
  def update(assigns, socket) do
    mode = assigns[:mode] || :create
    webhook = assigns[:webhook]

    # Use form_values from assigns if provided (from parent), 
    # otherwise initialize from webhook or defaults
    form_values =
      cond do
        Map.has_key?(assigns, :form_values) ->
          assigns.form_values

        mode == :edit && webhook ->
          %{
            "name" => webhook.name,
            "url" => webhook.url,
            "secret" => webhook.secret || "",
            "events" => webhook.events
          }

        true ->
          %{
            "name" => "",
            "url" => "",
            "secret" => "",
            "events" => []
          }
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:mode, mode)
     |> assign(:webhook, webhook)
     |> assign(:form_values, form_values)
     |> assign(:form_errors, assigns[:form_errors] || %{})}
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :can_submit, can_submit?(assigns))

    ~H"""
    <div class="space-y-8 pb-20">
      <!-- Toolbar -->
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-6 mb-10">
        <.section_header
          icon={:webhook}
          title={if @mode == :create, do: "Create Webhook", else: "Edit Webhook"}
          class="mb-0"
        />

        <button
          phx-click="close_webhook_form"
          phx-target={@parent_component}
          class="flex items-center gap-2 px-5 py-2.5 rounded-token-xl bg-tymeslot-50 text-tymeslot-600 font-bold hover:bg-tymeslot-100 transition-all border-2 border-transparent hover:border-tymeslot-200"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Close
        </button>
      </div>

      <!-- Form -->
      <form
        id="webhook-form"
        phx-submit={
          if @mode == :create do
            JS.push("create_webhook", target: @parent_component)
          else
            JS.push("update_webhook", target: @parent_component)
          end
        }
        phx-target={@parent_component}
        class="space-y-8"
      >
        <!-- Name Field -->
        <div class="card-glass">
          <div class="mb-6">
            <h3 class="text-token-xl font-black text-tymeslot-900 tracking-tight">Webhook Details</h3>
            <p class="text-token-sm text-tymeslot-500 font-bold mt-1">
              Configure the basic information for your webhook.
            </p>
          </div>

          <div class="space-y-6">
            <div class="space-y-2">
              <label class="block text-token-sm font-black text-tymeslot-900">Webhook Name *</label>
              <input
                type="text"
                name="webhook[name]"
                value={Map.get(@form_values, "name", "")}
                phx-blur={JS.push("validate_field", value: %{"field" => "name"}, target: @parent_component)}
                class="input-base w-full text-tymeslot-900"
                placeholder="My n8n Automation"
                required
              />
              <%= if error = Map.get(@form_errors, :name) do %>
                <p class="text-token-sm text-red-600 font-medium"><%= error %></p>
              <% end %>
            </div>

            <div class="space-y-2">
              <label class="block text-token-sm font-black text-tymeslot-900">Webhook URL *</label>
              <input
                type="url"
                name="webhook[url]"
                value={Map.get(@form_values, "url", "")}
                phx-blur={JS.push("validate_field", value: %{"field" => "url"}, target: @parent_component)}
                class="input-base font-mono text-token-sm w-full text-tymeslot-900"
                placeholder="https://your-n8n-instance.com/webhook/..."
                required
              />
              <%= if error = Map.get(@form_errors, :url) do %>
                <p class="text-token-sm text-red-600 font-medium"><%= error %></p>
              <% end %>
            </div>

            <div class="space-y-2">
              <label class="block text-token-sm font-black text-tymeslot-900">
                Secret Key (Optional)
                <span class="text-tymeslot-500 font-medium">- for HMAC signature verification</span>
              </label>
              <div class="flex gap-2">
                <input
                  type="text"
                  name="webhook[secret]"
                  id="webhook_secret"
                  value={Map.get(@form_values, "secret", "")}
                  phx-change={JS.push("validate_field", value: %{"field" => "secret"}, target: @parent_component)}
                  class="input-base font-mono text-token-sm flex-1 text-tymeslot-900"
                  placeholder="Leave empty or generate a secure key"
                />
                <button
                  type="button"
                  phx-click={JS.push("generate_secret", target: @parent_component)}
                  class="whitespace-nowrap px-5 py-2.5 rounded-token-xl bg-tymeslot-50 text-tymeslot-600 font-bold hover:bg-tymeslot-100 transition-all border-2 border-transparent hover:border-tymeslot-200"
                >
                  Generate
                </button>
              </div>
              <p class="text-token-xs text-tymeslot-500 font-medium">
                The secret will be used to sign webhook payloads for security verification.
              </p>
            </div>
          </div>
        </div>

        <!-- Events Selection -->
        <div class="card-glass">
          <div class="mb-6">
            <h3 class="text-token-xl font-black text-tymeslot-900 tracking-tight">Event Subscriptions</h3>
            <p class="text-token-sm text-tymeslot-500 font-bold mt-1">
              Select which events should trigger this webhook.
            </p>
          </div>

          <div class="space-y-3">
            <%= for event <- @available_events do %>
              <label class="flex items-start gap-3 p-4 rounded-token-xl border-2 border-tymeslot-100 hover:border-turquoise-200 cursor-pointer transition-colors">
                <input
                  type="checkbox"
                  name="webhook[events][]"
                  value={event.value}
                  checked={event.value in Map.get(@form_values, "events", [])}
                  phx-click={JS.push("toggle_event", value: %{"event" => event.value}, target: @parent_component)}
                  class="mt-1 w-5 h-5 text-turquoise-600 rounded border-tymeslot-300 focus:ring-turquoise-500"
                />
                <div class="flex-1">
                  <div class="font-black text-tymeslot-900"><%= event.label %></div>
                  <div class="text-token-sm text-tymeslot-600 font-medium"><%= event.description %></div>
                </div>
              </label>
            <% end %>
          </div>
          <%= if error = Map.get(@form_errors, :events) do %>
            <p class="text-token-sm text-red-600 font-medium mt-3"><%= error %></p>
          <% end %>
        </div>

        <!-- Form Actions -->
        <div class="flex justify-end gap-3 pt-4">
          <CoreComponents.action_button
            variant={:secondary}
            phx-click="close_webhook_form"
            phx-target={@parent_component}
          >
            Cancel
          </CoreComponents.action_button>
          <CoreComponents.loading_button
            type="submit"
            variant={:primary}
            loading={@saving}
            loading_text="Saving..."
            disabled={!@can_submit}
            class={if !@can_submit, do: "opacity-50 cursor-not-allowed grayscale", else: ""}
            title={if !@can_submit, do: get_disabled_reason(assigns), else: ""}
          >
            <%= if @mode == :create, do: "Create Webhook", else: "Update Webhook" %>
          </CoreComponents.loading_button>
        </div>
      </form>
    </div>
    """
  end

  defp can_submit?(assigns) do
    values = assigns.form_values
    errors = assigns.form_errors

    has_name = Map.get(values, "name", "") |> String.trim() != ""
    has_url = Map.get(values, "url", "") |> String.trim() != ""
    has_events = Map.get(values, "events", []) |> Enum.any?()
    no_errors = Enum.empty?(errors)

    has_name && has_url && has_events && no_errors
  end

  defp get_disabled_reason(assigns) do
    values = assigns.form_values
    errors = assigns.form_errors

    cond do
      !Enum.empty?(errors) ->
        "Please fix the validation errors above."

      Map.get(values, "name", "") |> String.trim() == "" ->
        "Webhook name is required."

      Map.get(values, "url", "") |> String.trim() == "" ->
        "Webhook URL is required."

      !(Map.get(values, "events", []) |> Enum.any?()) ->
        "At least one event subscription is required."

      true ->
        ""
    end
  end
end
