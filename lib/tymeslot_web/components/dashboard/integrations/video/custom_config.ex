defmodule TymeslotWeb.Components.Dashboard.Integrations.Video.CustomConfig do
  @moduledoc """
  Component for configuring custom video integration setup.
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
    <div id="custom-video-config-modal" class="space-y-6">
      <div class="flex items-center gap-4 mb-2">
        <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center shadow-lg">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"
            />
          </svg>
        </div>
        <div>
          <h3 class="text-xl font-black text-slate-900 tracking-tight">Custom Video Link</h3>
          <p class="text-sm text-slate-500 font-medium">Connect any video platform</p>
        </div>
      </div>

      <form phx-submit="add_integration" phx-change="track_form_change" phx-target={@target} class="space-y-5">
        <input type="hidden" name="integration[provider]" value="custom" />

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <SharedForm.integration_name_field
            form_errors={@form_errors}
            value={Map.get(@form_values, "name", "My Custom Video")}
            target={@target}
          />

          <SharedForm.url_field
            id="custom_meeting_url"
            name="integration[custom_meeting_url]"
            label="Meeting URL"
            value={Map.get(@form_values, "custom_meeting_url", "")}
            placeholder="https://meet.example.com/your-room"
            form_errors={@form_errors}
            error_key={:custom_meeting_url}
            target={@target}
            helper_text="Enter the complete URL for your video meeting room"
          />
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
