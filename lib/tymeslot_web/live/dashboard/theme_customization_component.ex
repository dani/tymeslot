defmodule TymeslotWeb.Dashboard.ThemeCustomizationComponent do
  @moduledoc """
  Theme customization component for advanced theme settings.
  Allows users to customize colors and backgrounds for their booking page.

  Assigns contract
  - Required (passed in):
    - profile: Tymeslot.DatabaseSchemas.ProfileSchema.t()
    - theme_id: String.t()
  - Provided/managed by this component (do not pass these in):
    - customization: map with current customization state (see customization_t())
    - presets: preset collections for color schemes and backgrounds (see presets_t())
    - defaults: map of default values for the theme
    - browsing_type: String.t() – which background category is currently browsed ("gradient" | "color" | "image" | "video")
    - parent_uploads: map() | nil – upload entries provided by parent LiveView (optional)
    - parent_component: term() – reference to parent component for close actions (optional)
  """
  use TymeslotWeb, :live_component

  import TymeslotWeb.Dashboard.ThemeCustomization.Pickers.ColorPicker, only: [color_picker: 1]

  import TymeslotWeb.Dashboard.ThemeCustomization.Pickers.GradientPicker,
    only: [gradient_picker: 1]

  import TymeslotWeb.Dashboard.ThemeCustomization.Pickers.ImagePicker, only: [image_picker: 1]
  import TymeslotWeb.Dashboard.ThemeCustomization.Pickers.VideoPicker, only: [video_picker: 1]

  alias Phoenix.LiveView.Socket
  alias Tymeslot.ThemeCustomizations

  @typedoc "Preset collections used by the component"
  @type presets_t :: %{
          required(:color_schemes) => %{optional(String.t()) => map()},
          required(:gradients) => %{
            optional(String.t()) => %{
              required(:name) => String.t(),
              required(:value) => String.t()
            }
          },
          required(:images) => %{
            optional(String.t()) => %{
              required(:name) => String.t(),
              required(:file) => String.t(),
              optional(:description) => String.t()
            }
          },
          required(:videos) => %{
            optional(String.t()) => %{
              required(:name) => String.t(),
              required(:file) => String.t(),
              required(:thumbnail) => String.t(),
              optional(:description) => String.t()
            }
          }
        }

  @typedoc "Customization map applied to the theme"
  @type customization_t :: %{
          required(:background_type) => String.t(),
          optional(:background_value) => String.t() | nil,
          optional(:background_image_path) => String.t() | nil,
          optional(:background_video_path) => String.t() | nil,
          optional(:color_scheme) => String.t()
        }

  @typedoc "Assigns contract for this component"
  @type assigns_t :: %{
          required(:profile) => Tymeslot.DatabaseSchemas.ProfileSchema.t(),
          required(:theme_id) => String.t(),
          required(:customization) => customization_t(),
          required(:presets) => presets_t(),
          required(:defaults) => map(),
          required(:browsing_type) => String.t(),
          optional(:parent_uploads) => map() | nil,
          optional(:parent_component) => term()
        }

  @impl true
  @spec mount(Socket.t()) :: {:ok, Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, :uploading, false)}
  end

  @impl true
  @spec update(map(), Socket.t()) :: {:ok, Socket.t()}
  def update(assigns, socket) do
    theme_id = assigns[:theme_id] || "1"

    # Initialize customization data from the domain
    %{
      customization: customization,
      original: _original_state,
      presets: presets,
      defaults: defaults
    } = ThemeCustomizations.initialize_customization(assigns.profile.id, theme_id)

    # Narrow assigns surface: expose a small, consistent contract
    {:ok,
     socket
     |> assign(:profile, assigns.profile)
     |> assign(:parent_component, assigns[:parent_component])
     |> assign(:parent_uploads, assigns[:parent_uploads] || nil)
     |> assign(:theme_id, theme_id)
     |> assign(:customization, customization)
     |> assign(:presets, presets)
     |> assign(:defaults, defaults)
     |> assign(:browsing_type, customization.background_type)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8" phx-hook="AutoUpload" id="theme-customization-uploads">
      <.toolbar profile={@profile} theme_id={@theme_id} parent_component={@parent_component} />

      <.color_scheme_section customization={@customization} presets={@presets} myself={@myself} />

      <.background_section
        browsing_type={@browsing_type}
        customization={@customization}
        presets={@presets}
        parent_uploads={@parent_uploads}
        myself={@myself}
      />
    </div>
    """
  end

  @impl true
  @spec handle_event(String.t(), map(), Socket.t()) :: {:noreply, Socket.t()}
  def handle_event("theme:select_color_scheme", %{"scheme" => scheme_id}, socket) do
    case ThemeCustomizations.apply_color_scheme_change(
           socket.assigns.profile.id,
           socket.assigns.theme_id,
           socket.assigns.customization,
           scheme_id
         ) do
      {:ok, updated_customization} ->
        {:noreply, assign(socket, :customization, updated_customization)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  def handle_event("theme:set_browsing_type", %{"type" => type}, socket) do
    # Only update the browsing type - this is just UI navigation, not a selection
    {:noreply, assign(socket, :browsing_type, type)}
  end

  def handle_event("theme:select_background", params, socket) do
    type = params["type"]
    value = params["id"] || params["value"]

    case ThemeCustomizations.apply_background_change(
           socket.assigns.profile.id,
           socket.assigns.theme_id,
           socket.assigns.customization,
           type,
           value
         ) do
      {:ok, updated_customization} ->
        {:noreply,
         socket
         |> assign(:customization, updated_customization)
         |> assign(:browsing_type, type)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  # ========== Function components (extracted) ==========

  defp toolbar(assigns) do
    ~H"""
    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-6 mb-10">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 bg-turquoise-50 rounded-xl flex items-center justify-center border border-turquoise-100 shadow-sm">
          <svg class="w-6 h-6 text-turquoise-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
          </svg>
        </div>
        <h2 class="text-3xl font-black text-slate-900 tracking-tight">Customize Style</h2>
      </div>

      <div class="flex items-center gap-3">
        <%= if @profile && @profile.username do %>
          <button
            type="button"
            class="btn-secondary py-2.5 px-5 text-sm"
            onclick={"window.open('/#{@profile.username}?theme=#{@theme_id}', '_blank')"}
          >
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            Live Preview
          </button>
        <% end %>
        <button
          phx-click="close_customization"
          phx-target={@parent_component}
          class="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-slate-50 text-slate-600 font-bold hover:bg-slate-100 transition-all border-2 border-transparent hover:border-slate-200"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
          </svg>
          Close
        </button>
      </div>
    </div>
    """
  end

  defp color_scheme_section(assigns) do
    ~H"""
    <div class="card-glass">
      <div class="flex flex-col sm:flex-row sm:items-center justify-between mb-8 gap-4">
        <div>
          <h3 class="text-xl font-black text-slate-900 tracking-tight">Color Palette</h3>
          <p class="text-sm text-slate-500 font-bold mt-1">Select the primary colors for your booking page interface.</p>
        </div>
        <% current_scheme = @presets.color_schemes[@customization.color_scheme] %>
        <%= if current_scheme do %>
          <div class="flex items-center gap-3 bg-slate-50 px-4 py-2 rounded-2xl border border-slate-100 shadow-inner">
            <span class="text-[10px] font-black uppercase tracking-widest text-slate-400">Current</span>
            <div class="flex items-center gap-1.5 bg-white p-1 rounded-lg border border-slate-100">
              <div class="w-3 h-3 rounded-full" style={"background-color: #{current_scheme.colors.primary}"}></div>
              <div class="w-3 h-3 rounded-full" style={"background-color: #{current_scheme.colors.secondary}"}></div>
              <div class="w-3 h-3 rounded-full" style={"background-color: #{current_scheme.colors.accent}"}></div>
            </div>
            <span class="text-sm font-black text-slate-700">{current_scheme.name}</span>
          </div>
        <% end %>
      </div>
      
      <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
        <%= for {scheme_id, scheme} <- @presets.color_schemes do %>
          <button
            type="button"
            class={[
              "group/scheme relative flex flex-col items-center p-4 rounded-2xl border-2 transition-all duration-300",
              if(@customization.color_scheme == scheme_id,
                do: "bg-turquoise-50 border-turquoise-400 shadow-xl shadow-turquoise-500/10",
                else: "bg-white border-slate-50 hover:border-turquoise-200 hover:shadow-lg"
              )
            ]}
            phx-click="theme:select_color_scheme"
            phx-value-scheme={scheme_id}
            phx-target={@myself}
          >
            <div class="flex items-center gap-2 mb-4 bg-slate-50/50 p-2 rounded-xl group-hover/scheme:scale-110 transition-transform">
              <div class="w-6 h-6 rounded-full shadow-sm border border-white" style={"background-color: #{scheme.colors.primary}"}></div>
              <div class="w-6 h-6 rounded-full shadow-sm border border-white" style={"background-color: #{scheme.colors.secondary}"}></div>
              <div class="w-6 h-6 rounded-full shadow-sm border border-white" style={"background-color: #{scheme.colors.accent}"}></div>
            </div>
            <p class={[
              "text-sm font-black uppercase tracking-widest transition-colors",
              if(@customization.color_scheme == scheme_id, do: "text-turquoise-700", else: "text-slate-400 group-hover/scheme:text-slate-600")
            ]}>{scheme.name}</p>
            
            <%= if @customization.color_scheme == scheme_id do %>
              <div class="absolute top-2 right-2 w-6 h-6 bg-turquoise-500 text-white rounded-full flex items-center justify-center shadow-lg animate-in zoom-in">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
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

  defp background_section(assigns) do
    ~H"""
    <div class="card-glass">
      <div class="mb-8">
        <h3 class="text-xl font-black text-slate-900 tracking-tight">Background Design</h3>
        <p class="text-sm text-slate-500 font-bold mt-1">Choose a visual style that matches your professional identity.</p>
      </div>

      <div class="space-y-10">
        <div class="flex flex-wrap gap-3 bg-slate-50/50 p-2 rounded-[1.5rem] border-2 border-slate-50">
          <%= for {type, icon_path, label} <- background_tabs() do %>
            <button
              type="button"
              class={[
                "flex-1 flex items-center justify-center gap-2 px-6 py-3 rounded-2xl text-sm font-black uppercase tracking-widest transition-all duration-300 border-2",
                if(@browsing_type == type,
                  do: "bg-white border-white text-turquoise-600 shadow-xl shadow-slate-200/50 scale-[1.02]",
                  else: "bg-transparent border-transparent text-slate-400 hover:text-slate-600 hover:bg-white/50"
                )
              ]}
              phx-click="theme:set_browsing_type"
              phx-value-type={type}
              phx-target={@myself}
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d={icon_path} />
              </svg>
              <span>{label}</span>
            </button>
          <% end %>
        </div>

        <div class="animate-in fade-in slide-in-from-top-4 duration-500">
          <%= case @browsing_type do %>
            <% "gradient" -> %>
              <.gradient_picker customization={@customization} presets={@presets} myself={@myself} />
            <% "color" -> %>
              <.color_picker customization={@customization} myself={@myself} />
            <% "image" -> %>
              <.image_picker
                customization={@customization}
                presets={@presets}
                parent_uploads={@parent_uploads}
                myself={@myself}
              />
            <% "video" -> %>
              <.video_picker
                customization={@customization}
                presets={@presets}
                parent_uploads={@parent_uploads}
                myself={@myself}
              />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp background_tabs do
    [
      {"gradient", "M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4", "Gradient"},
      {"color",
       "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a6 6 0 00-3-5.197M11 3h8a2 2 0 012 2v4a6 6 0 01-3 5.197",
       "Solid Color"},
      {"image",
       "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z",
       "Image"},
      {"video",
       "M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z",
       "Video"}
    ]
  end
end
