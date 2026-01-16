defmodule TymeslotWeb.Components.Dashboard.Integrations.Video.MirotalkConfig do
  @moduledoc """
  Component for configuring MiroTalk P2P video integration.
  """
  use TymeslotWeb, :live_component

  alias TymeslotWeb.Components.Dashboard.Integrations.Video.SharedFormComponents,
    as: SharedForm

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:form_values, %{})
     |> assign(:form_errors, %{})
     |> assign(:saving, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form_values, fn -> %{} end)
     |> assign_new(:form_errors, fn -> %{} end)
     |> assign_new(:saving, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="mirotalk-config-modal" class="space-y-6">
      <div class="flex items-center gap-4 mb-2">
        <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center shadow-lg">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
            />
          </svg>
        </div>
        <div>
          <h3 class="text-xl font-black text-slate-900 tracking-tight">MiroTalk P2P</h3>
          <p class="text-sm text-slate-500 font-medium">Self-hosted video conferencing</p>
        </div>
      </div>

      <form phx-submit="add_integration" phx-change="track_form_change" phx-target={@target} class="space-y-5">
        <input type="hidden" name="integration[provider]" value="mirotalk" />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <SharedForm.integration_name_field
            form_errors={@form_errors}
            value={Map.get(@form_values, "name", "My MiroTalk")}
            target={@target}
          />

          <SharedForm.url_field
            id="mirotalk_base_url"
            name="integration[base_url]"
            label="Server URL"
            value={Map.get(@form_values, "base_url", "")}
            placeholder="https://mirotalk.yourdomain.com"
            form_errors={@form_errors}
            error_key={:base_url}
            target={@target}
            helper_text="The full URL where your MiroTalk P2P instance is hosted"
          />

          <div class="md:col-span-2">
            <SharedForm.api_key_field
              id="mirotalk_api_key"
              name="integration[api_key]"
              value={Map.get(@form_values, "api_key", "")}
              placeholder="your-api-key-here"
              form_errors={@form_errors}
              target={@target}
              helper_text="Get your API key from your MiroTalk instance configuration"
            />
          </div>
        </div>

        <div class="flex justify-between items-center pt-4 border-t border-slate-100">
          <button type="button" phx-click="back_to_providers" phx-target={@target} class="btn-secondary">
            Cancel
          </button>
          <TymeslotWeb.Components.Dashboard.Integrations.Shared.UIComponents.form_submit_button saving={@saving} />
        </div>
      </form>
    </div>
    """
  end
end
