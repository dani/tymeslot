defmodule TymeslotWeb.Dashboard.ThemeCustomization.Pickers.ColorPicker do
  @moduledoc """
  Function component for selecting solid color backgrounds in theme customization.
  """
  use TymeslotWeb, :html

  @doc """
  Renders the color picker.
  Expects assigns: customization, myself
  """
  @spec color_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def color_picker(assigns) do
    ~H"""
    <div class="space-y-6">
      <p class="text-token-sm font-black text-tymeslot-400 uppercase tracking-widest">Select a solid color</p>
      <div class="flex flex-wrap gap-4">
        <%= for color <- ["#0f172a", "#1e1b4b", "#431407", "#082f49", "#052e16", "#4c0519", "#111827", "#1a202c"] do %>
          <button
            type="button"
            class={[
              "w-14 h-14 rounded-token-2xl border-4 transition-all duration-300 shadow-sm transform hover:scale-110",
              if(@customization.background_value == color,
                do: "border-turquoise-400 shadow-xl shadow-turquoise-500/20 scale-110",
                else: "border-white hover:border-turquoise-200"
              )
            ]}
            style={"background-color: #{color}"}
            phx-click="theme:select_background"
            phx-value-type="color"
            phx-value-id={color}
            phx-target={@myself}
          >
            <%= if @customization.background_value == color do %>
              <div class="bg-white rounded-full p-1 w-6 h-6 mx-auto flex items-center justify-center shadow-lg animate-in zoom-in">
                <svg class="w-4 h-4 text-turquoise-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                </svg>
              </div>
            <% end %>
          </button>
        <% end %>
      </div>
    </div>
    """
  end
end
