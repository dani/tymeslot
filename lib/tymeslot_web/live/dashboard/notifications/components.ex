defmodule TymeslotWeb.Dashboard.Notifications.Components do
  @moduledoc """
  UI components for notification settings.
  """
  use TymeslotWeb, :html

  alias TymeslotWeb.Components.Icons.IconComponents

  attr :webhook, :map, required: true
  attr :testing, :boolean, default: false
  attr :on_edit, :any, required: true
  attr :on_delete, :any, required: true
  attr :on_toggle, :any, required: true
  attr :on_test, :any, required: true
  attr :on_view_deliveries, :any, required: true

  @spec webhook_card(map()) :: Phoenix.LiveView.Rendered.t()
  def webhook_card(assigns) do
    ~H"""
    <div class="card-glass">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center gap-3 mb-2">
            <h3 class="text-token-xl font-black text-tymeslot-900"><%= @webhook.name %></h3>
            <%= if @webhook.is_active do %>
              <span class="bg-green-100 text-green-700 text-xs font-black px-2 py-1 rounded-full">ACTIVE</span>
            <% else %>
              <span class="bg-tymeslot-200 text-tymeslot-600 text-xs font-black px-2 py-1 rounded-full">INACTIVE</span>
            <% end %>
          </div>

          <div class="text-token-sm text-tymeslot-600 font-medium mb-3 font-mono truncate">
            <%= @webhook.url %>
          </div>

          <div class="flex flex-wrap gap-2 mb-4">
            <%= for event <- @webhook.events do %>
              <span class="bg-turquoise-50 text-turquoise-700 text-xs font-bold px-2 py-1 rounded-token-lg border border-turquoise-100">
                <%= event %>
              </span>
            <% end %>
          </div>

          <%= if @webhook.last_triggered_at do %>
            <div class="text-token-sm text-tymeslot-500">
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
            class="btn-secondary text-token-sm"
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

          <button phx-click={@on_view_deliveries} class="btn-secondary text-token-sm" title="View Deliveries">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Logs
          </button>

          <button phx-click={@on_toggle} class="btn-secondary text-token-sm" title={if @webhook.is_active, do: "Disable", else: "Enable"}>
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

          <button phx-click={@on_edit} class="btn-secondary text-token-sm" title="Edit">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
            </svg>
          </button>

          <button phx-click={@on_delete} class="btn-danger text-token-sm" title="Delete">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :on_create, :any, required: true

  @spec webhook_empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def webhook_empty_state(assigns) do
    ~H"""
    <div class="card-glass text-center py-16">
      <div class="w-20 h-20 bg-turquoise-50 rounded-token-3xl mx-auto mb-6 flex items-center justify-center border-2 border-turquoise-100">
        <IconComponents.icon name={:webhook} class="w-10 h-10 text-turquoise-600" />
      </div>

      <h3 class="text-token-2xl font-black text-tymeslot-900 mb-3">No Webhooks Yet</h3>
      <p class="text-tymeslot-600 font-medium mb-8 max-w-md mx-auto">
        Set up webhooks to automatically trigger actions in n8n, Zapier, or your custom tools when bookings are created, cancelled, or rescheduled.
      </p>

      <button phx-click={@on_create} class="btn-primary">
        Create Your First Webhook
      </button>
    </div>
    """
  end

  @spec webhook_documentation(map()) :: Phoenix.LiveView.Rendered.t()
  def webhook_documentation(assigns) do
    ~H"""
    <div class="card-glass space-y-6">
      <h3 class="text-token-2xl font-black text-tymeslot-900">Setting Up Webhooks</h3>

      <div class="space-y-4">
        <div>
          <h4 class="text-token-lg font-black text-tymeslot-900 mb-2">What are webhooks?</h4>
          <p class="text-tymeslot-600 font-medium">
            Webhooks send real-time notifications to your automation tools (like n8n, Zapier, Make) when booking events occur in Tymeslot.
          </p>
        </div>

        <div>
          <h4 class="text-token-lg font-black text-tymeslot-900 mb-2">Quick Setup with n8n</h4>
          <ol class="list-decimal list-inside space-y-2 text-tymeslot-600 font-medium ml-4">
            <li>Create a new workflow in n8n</li>
            <li>Add a "Webhook" trigger node and copy the URL</li>
            <li>Click "Add Webhook" above and paste the URL</li>
            <li>Select which events to listen for</li>
            <li>Click "Test Connection" to verify</li>
            <li>Build your automation workflow in n8n!</li>
          </ol>
        </div>

        <div>
          <h4 class="text-token-lg font-black text-tymeslot-900 mb-2">Available Events</h4>
          <ul class="space-y-2 text-tymeslot-600 font-medium">
            <li><span class="font-black">meeting.created</span> - When a new booking is made</li>
            <li><span class="font-black">meeting.cancelled</span> - When a booking is cancelled</li>
            <li><span class="font-black">meeting.rescheduled</span> - When a booking time is changed</li>
          </ul>
        </div>

        <div>
          <h4 class="text-token-lg font-black text-tymeslot-900 mb-2">Security</h4>
          <p class="text-tymeslot-600 font-medium mb-2">
            Webhooks can include a secret key for HMAC signature verification. The signature is sent in the <code class="bg-tymeslot-100 px-2 py-1 rounded text-token-sm">X-Tymeslot-Signature</code> header.
          </p>
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
  defp status_color(_), do: "text-tymeslot-600 font-medium"
end
