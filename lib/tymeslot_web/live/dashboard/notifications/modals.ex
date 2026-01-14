defmodule TymeslotWeb.Dashboard.Notifications.Modals do
  @moduledoc """
  Modal components for notification settings.
  """
  use TymeslotWeb, :html
  alias TymeslotWeb.Components.CoreComponents

  attr :show, :boolean, default: false
  attr :mode, :atom, required: true, values: [:create, :edit]
  attr :form_values, :map, required: true
  attr :form_errors, :map, required: true
  attr :available_events, :list, required: true
  attr :saving, :boolean, default: false
  attr :on_cancel, :any, required: true
  attr :on_submit, :any, required: true
  attr :on_generate_secret, :any, required: true
  attr :on_toggle_event, :any, required: true
  attr :on_validate_field, :any, required: true
  attr :myself, :any, required: true

  @spec webhook_form_modal(map()) :: Phoenix.LiveView.Rendered.t()
  def webhook_form_modal(assigns) do
    ~H"""
    <CoreComponents.modal
      id="webhook-form-modal"
      show={@show}
      on_cancel={@on_cancel}
      size={:medium}
    >
      <:header>
        <%= if @mode == :create, do: "Create Webhook", else: "Edit Webhook" %>
      </:header>

      <form phx-submit={@on_submit} phx-target={@myself}>
        <!-- Name Field -->
        <div class="space-y-2">
          <label class="block text-token-sm font-black text-tymeslot-900">Webhook Name *</label>
          <input
            type="text"
            name="webhook[name]"
            value={Map.get(@form_values, "name", "")}
            phx-blur={@on_validate_field.("name", "")}
            class="input-base"
            placeholder="My n8n Automation"
            required
          />
          <%= if error = Map.get(@form_errors, :name) do %>
            <p class="text-token-sm text-red-600 font-medium"><%= error %></p>
          <% end %>
        </div>

        <!-- URL Field -->
        <div class="space-y-2 mt-4">
          <label class="block text-token-sm font-black text-tymeslot-900">Webhook URL *</label>
          <input
            type="url"
            name="webhook[url]"
            value={Map.get(@form_values, "url", "")}
            phx-blur={@on_validate_field.("url", "")}
            class="input-base font-mono text-token-sm"
            placeholder="https://your-n8n-instance.com/webhook/..."
            required
          />
          <%= if error = Map.get(@form_errors, :url) do %>
            <p class="text-token-sm text-red-600 font-medium"><%= error %></p>
          <% end %>
        </div>

        <!-- Secret Field -->
        <div class="space-y-2 mt-4">
          <label class="block text-token-sm font-black text-tymeslot-900">
            Secret Key (Optional)
            <span class="text-tymeslot-500 font-medium">- for HMAC signature verification</span>
          </label>
          <div class="flex gap-2">
            <input
              type="text"
              name="webhook[secret]"
              value={Map.get(@form_values, "secret", "")}
              class="input-base font-mono text-token-sm flex-1"
              placeholder="Leave empty or generate a secure key"
            />
            <CoreComponents.action_button
              variant={:secondary}
              phx-click={@on_generate_secret}
              class="whitespace-nowrap"
            >
              Generate
            </CoreComponents.action_button>
          </div>
          <p class="text-token-xs text-tymeslot-500 font-medium">
            The secret will be used to sign webhook payloads for security verification.
          </p>
        </div>

        <!-- Events Selection -->
        <div class="space-y-3 mt-6">
          <label class="block text-token-sm font-black text-tymeslot-900">Events to Subscribe *</label>
          <div class="space-y-2">
            <%= for event <- @available_events do %>
              <label class="flex items-start gap-3 p-4 rounded-token-xl border-2 border-tymeslot-100 hover:border-turquoise-200 cursor-pointer transition-colors">
                <input
                  type="checkbox"
                  name="webhook[events][]"
                  value={event.value}
                  checked={event.value in Map.get(@form_values, "events", [])}
                  phx-click={@on_toggle_event.(event.value)}
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
            <p class="text-token-sm text-red-600 font-medium"><%= error %></p>
          <% end %>
        </div>

        <button type="submit" id="webhook-form-submit" class="hidden" />
      </form>

      <:footer>
        <div class="flex justify-end gap-3">
          <CoreComponents.action_button variant={:secondary} phx-click={@on_cancel}>
            Cancel
          </CoreComponents.action_button>
          <CoreComponents.loading_button
            type="submit"
            form="webhook-form-modal-form"
            phx-click={JS.dispatch("click", to: "#webhook-form-submit")}
            variant={:primary}
            loading={@saving}
            loading_text="Saving..."
          >
            <%= if @mode == :create, do: "Create Webhook", else: "Update Webhook" %>
          </CoreComponents.loading_button>
        </div>
      </:footer>
    </CoreComponents.modal>
    """
  end

  attr :show, :boolean, default: false
  attr :on_cancel, :any, required: true
  attr :on_confirm, :any, required: true

  @spec delete_webhook_modal(map()) :: Phoenix.LiveView.Rendered.t()
  def delete_webhook_modal(assigns) do
    ~H"""
    <CoreComponents.modal
      id="delete-webhook-modal"
      show={@show}
      on_cancel={@on_cancel}
      size={:small}
    >
      <:header>
        <div class="flex items-center gap-2">
          <svg class="w-5 h-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          Delete Webhook?
        </div>
      </:header>

      <div class="text-center sm:text-left">
        <p class="text-tymeslot-600 font-medium">
          This action cannot be undone. All delivery logs for this webhook will also be deleted.
        </p>
      </div>

      <:footer>
        <div class="flex gap-3">
          <CoreComponents.action_button
            variant={:secondary}
            phx-click={@on_cancel}
            class="flex-1"
          >
            Cancel
          </CoreComponents.action_button>
          <CoreComponents.action_button
            variant={:danger}
            phx-click={@on_confirm}
            class="flex-1"
          >
            Delete Webhook
          </CoreComponents.action_button>
        </div>
      </:footer>
    </CoreComponents.modal>
    """
  end

  attr :show, :boolean, default: false
  attr :webhook, :map, required: true
  attr :deliveries, :list, required: true
  attr :stats, :map, required: true
  attr :on_close, :any, required: true

  @spec deliveries_modal(map()) :: Phoenix.LiveView.Rendered.t()
  def deliveries_modal(assigns) do
    ~H"""
    <CoreComponents.modal
      id="deliveries-modal"
      show={@show}
      on_cancel={@on_close}
      size={:large}
    >
      <:header>
        <div class="flex flex-col">
          <span><%= @webhook.name %></span>
          <span class="text-tymeslot-500 font-medium font-mono text-token-xs mt-1"><%= @webhook.url %></span>
        </div>
      </:header>

      <div class="space-y-8">
        <!-- Stats -->
        <%= if @stats do %>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-tymeslot-50 rounded-token-2xl p-4 border border-tymeslot-100">
              <div class="text-token-xs font-black text-tymeslot-600 uppercase tracking-wider">Total</div>
              <div class="text-token-3xl font-black text-tymeslot-900 mt-1"><%= @stats.total %></div>
              <div class="text-token-xs text-tymeslot-500 font-medium mt-1">Last <%= @stats.period_days %> days</div>
            </div>
            <div class="bg-green-50 rounded-token-2xl p-4 border border-green-100">
              <div class="text-token-xs font-black text-green-600 uppercase tracking-wider">Success</div>
              <div class="text-token-3xl font-black text-green-700 mt-1"><%= @stats.successful %></div>
              <div class="text-token-xs text-green-600 font-medium mt-1"><%= @stats.success_rate %>% success rate</div>
            </div>
            <div class="bg-red-50 rounded-token-2xl p-4 border border-red-100">
              <div class="text-token-xs font-black text-red-600 uppercase tracking-wider">Failed</div>
              <div class="text-token-3xl font-black text-red-700 mt-1"><%= @stats.failed %></div>
              <div class="text-token-xs text-red-600 font-medium mt-1">Deliveries failed</div>
            </div>
          </div>
        <% end %>

        <!-- Deliveries List -->
        <div>
          <h3 class="text-lg font-black text-tymeslot-900 mb-4 flex items-center gap-2">
            <CoreComponents.icon name="hero-list-bullet" class="w-5 h-5" />
            Recent Deliveries
          </h3>
          <%= if @deliveries == [] do %>
            <div class="text-center py-12 bg-tymeslot-50 rounded-token-2xl border-2 border-dashed border-tymeslot-200">
              <p class="text-tymeslot-600 font-medium">No deliveries yet</p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for delivery <- @deliveries do %>
                <div class="border-2 border-tymeslot-100 rounded-token-2xl p-4 hover:border-turquoise-100 hover:bg-turquoise-50/10 transition-colors">
                  <div class="flex items-start justify-between">
                    <div class="flex-1">
                      <div class="flex flex-wrap items-center gap-3 mb-2">
                        <span class="bg-turquoise-50 text-turquoise-700 text-token-xs font-black px-2 py-1 rounded-token-lg border border-turquoise-100">
                          <%= delivery.event_type %>
                        </span>
                        <%= if delivery.response_status do %>
                          <span class={[
                            "text-token-xs font-black px-2 py-1 rounded-token-lg border",
                            if(delivery.response_status >= 200 and delivery.response_status < 300,
                              do: "bg-green-50 text-green-700 border-green-100",
                              else: "bg-red-50 text-red-700 border-red-100"
                            )
                          ]}>
                            <%= delivery.response_status %>
                          </span>
                        <% end %>
                        <span class="text-token-xs text-tymeslot-500 font-medium">
                          Attempt <%= delivery.attempt_count %>
                        </span>
                      </div>
                      <div class="text-token-sm text-tymeslot-600 font-medium flex items-center gap-1.5">
                        <CoreComponents.icon name="hero-clock" class="w-4 h-4" />
                        <%= format_datetime(delivery.inserted_at) %>
                      </div>
                      <%= if delivery.error_message do %>
                        <div class="text-token-sm text-red-600 font-medium mt-2 p-2 bg-red-50 rounded-token-lg border border-red-100">
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
      </div>

      <:footer>
        <div class="flex justify-end">
          <CoreComponents.action_button variant={:primary} phx-click={@on_close}>
            Close
          </CoreComponents.action_button>
        </div>
      </:footer>
    </CoreComponents.modal>
    """
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%B %d, %Y at %I:%M %p")
  end
end
