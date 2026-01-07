defmodule TymeslotWeb.Dashboard.ThemeSettingsComponent do
  @moduledoc """
  Theme selection component for the dashboard.
  Allows users to select their booking page theme.
  """
  use TymeslotWeb, :live_component

  alias Tymeslot.Profiles
  alias Tymeslot.Scheduling.LinkAccessPolicy
  alias Tymeslot.Security.ThemeInputProcessor
  alias Tymeslot.Themes.Theme
  alias TymeslotWeb.Dashboard.ThemeCustomizationComponent
  alias TymeslotWeb.Live.Dashboard.Shared.DashboardHelpers

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:themes, Theme.theme_options())
     |> assign_new(:show_customization, fn -> false end)
     |> assign_new(:customization_theme_id, fn -> nil end)
     |> assign_new(:customization_timestamp, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <%= if @show_customization && @customization_theme_id do %>
        <div class="animate-in fade-in slide-in-from-bottom-4 duration-500">
          <.live_component
            module={ThemeCustomizationComponent}
            id={"theme-customization-#{@customization_theme_id}-#{@customization_timestamp}"}
            profile={@profile}
            theme_id={@customization_theme_id}
            parent_component={@myself}
            parent_uploads={@parent_uploads}
          />
        </div>
      <% else %>
        <div class="text-center max-w-2xl mx-auto mb-16">
          <h1 class="text-4xl lg:text-5xl font-black text-slate-900 tracking-tight mb-4 animate-in fade-in slide-in-from-top-4 duration-700">Choose Your Style</h1>
          <p class="text-xl text-slate-500 font-medium leading-relaxed animate-in fade-in slide-in-from-top-4 duration-700 delay-100">
            Select the interface that best represents your personal brand and creates the best experience for your clients.
          </p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-10">
          <%= for {theme_name, theme_id} <- @themes do %>
            <div class="group/theme space-y-6">
              <div
                class={[
                  "card-glass p-0 overflow-hidden cursor-pointer transition-all duration-500 border-2",
                  if(@profile.booking_theme == theme_id,
                    do: "border-turquoise-400 shadow-2xl shadow-turquoise-500/20 ring-4 ring-turquoise-50",
                    else: "border-slate-50 hover:border-turquoise-200 hover:shadow-xl hover:shadow-slate-200/50"
                  )
                ]}
                phx-click="select_theme"
                phx-value-theme={theme_id}
                phx-target={@myself}
              >
                <div class="booking-flow-preview h-64 relative overflow-hidden">
                  <.theme_preview theme_id={theme_id} />
                  
                  <div class="absolute inset-0 bg-gradient-to-t from-slate-900/60 via-transparent to-transparent opacity-60 group-hover/theme:opacity-40 transition-opacity"></div>
                  
                  <div class="absolute bottom-6 left-6 right-6 flex items-center justify-between">
                    <h3 class="text-2xl font-black text-white tracking-tight drop-shadow-md">{theme_name}</h3>
                    <%= if @profile.booking_theme == theme_id do %>
                      <div class="flex items-center gap-2 bg-turquoise-500 text-white px-4 py-1.5 rounded-full text-xs font-black uppercase tracking-wider shadow-lg">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                        </svg>
                        Current Style
                      </div>
                    <% end %>
                  </div>

                  <div
                    :if={!LinkAccessPolicy.can_link?(@profile, @integration_status)}
                    class="absolute inset-0 bg-slate-900/40 backdrop-blur-[2px] flex flex-col items-center justify-center cursor-not-allowed z-20"
                  >
                    <div class="w-12 h-12 bg-white/20 rounded-2xl flex items-center justify-center mb-3">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                      </svg>
                    </div>
                    <span class="text-white font-black text-xs uppercase tracking-widest">Connect Calendar to Preview</span>
                  </div>
                </div>

                <div class="p-8">
                  <p class="text-slate-600 font-medium leading-relaxed line-clamp-2">
                    {theme_description(theme_id)}
                  </p>
                </div>
              </div>

              <div class="flex gap-4">
                <%= if LinkAccessPolicy.can_link?(@profile, @integration_status) do %>
                  <button
                    type="button"
                    class="btn-secondary flex-1 py-4"
                    onclick={"window.open('#{LinkAccessPolicy.scheduling_path(@profile)}?theme=#{theme_id}', '_blank')"}
                  >
                    <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                    </svg>
                    Live Preview
                  </button>
                <% else %>
                  <button
                    type="button"
                    class="btn-secondary flex-1 py-4 opacity-50 cursor-not-allowed"
                    disabled
                  >
                    <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                    </svg>
                    Live Preview
                  </button>
                <% end %>
                <button
                  type="button"
                  class="btn-primary flex-1 py-4"
                  phx-click="show_customization"
                  phx-value-theme={theme_id}
                  phx-target={@myself}
                >
                  <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
                  </svg>
                  Customize Style
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <div class="mt-16 bg-slate-50 border-2 border-dashed border-slate-200 rounded-3xl p-8 relative overflow-hidden group">
          <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:rotate-12 transition-transform duration-700">
            <svg class="w-32 h-32 text-slate-900" fill="currentColor" viewBox="0 0 24 24">
              <path d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
            </svg>
          </div>
          <div class="relative z-10">
            <h4 class="text-2xl font-black text-slate-900 tracking-tight mb-2">More Styles Coming Soon</h4>
            <p class="text-slate-500 font-medium text-lg mb-6">
              Our design team is busy crafting new themes to help you express your unique professional style.
            </p>
            <div class="flex gap-2">
              <div class="w-2 h-2 bg-turquoise-400 rounded-full animate-bounce"></div>
              <div class="w-2 h-2 bg-turquoise-400 rounded-full animate-bounce [animation-delay:0.2s]"></div>
              <div class="w-2 h-2 bg-turquoise-400 rounded-full animate-bounce [animation-delay:0.4s]"></div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("show_customization", %{"theme" => theme_id}, socket) do
    send(self(), {:theme_customization_opened, theme_id})

    {:noreply,
     socket
     |> assign(:show_customization, true)
     |> assign(:customization_theme_id, theme_id)
     |> assign(:customization_timestamp, System.system_time())}
  end

  def handle_event("close_customization", _params, socket) do
    send(self(), :theme_customization_closed)

    {:noreply,
     socket
     |> assign(:show_customization, false)
     |> assign(:customization_theme_id, nil)}
  end

  def handle_event("select_theme", %{"theme" => theme_id}, socket) do
    metadata = get_security_metadata(socket)

    case ThemeInputProcessor.validate_theme_selection(%{"theme" => theme_id}, metadata: metadata) do
      {:ok, %{"theme" => validated_theme_id}} ->
        case Profiles.update_booking_theme(socket.assigns.profile, validated_theme_id) do
          {:ok, updated_profile} ->
            theme_name = Theme.get_theme_name(updated_profile.booking_theme)
            send(self(), {:profile_updated, updated_profile})

            {:noreply,
             socket
             |> assign(profile: updated_profile)
             |> put_flash(:info, "Theme updated to #{theme_name}")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update theme")}
        end

      {:error, _validation_errors} ->
        {:noreply, put_flash(socket, :error, "Invalid theme selection")}
    end
  end

  defp theme_description("1") do
    "Glass morphism design with elegant transparency effects and a 4-step booking flow."
  end

  defp theme_description("2") do
    "Modern sliding design with video background and a 4-slide booking flow."
  end

  defp theme_description(_) do
    "A beautiful theme for your booking page."
  end

  defp theme_preview(assigns) do
    ~H"""
    <%= case @theme_id do %>
      <% "1" -> %>
        <div class="w-full h-full bg-gray-100 rounded-lg overflow-hidden">
          <img
            src="/images/ui/theme-previews/quill-theme-preview.webp"
            alt="Quill Theme Preview - Glass morphism booking flow"
            class="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
            onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'"
          />
          <!-- Fallback content when image fails to load -->
          <div
            class="w-full h-full bg-gradient-to-br from-purple-100 to-teal-100 flex items-center justify-center"
            style="display: none;"
          >
            <div class="text-center p-4">
              <div class="w-12 h-12 bg-teal-500 rounded-lg mx-auto mb-3 flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
                  />
                </svg>
              </div>
              <p class="text-sm font-semibold text-gray-700">Quill Theme</p>
              <p class="text-xs text-gray-600">Glass morphism flow</p>
            </div>
          </div>
        </div>
      <% "2" -> %>
        <div class="w-full h-full bg-gray-100 rounded-lg overflow-hidden">
          <img
            src="/images/ui/theme-previews/rhythm-theme-preview.webp"
            alt="Rhythm Theme Preview - Video background sliding flow"
            class="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
            onerror="this.style.display='none'; this.nextElementSibling.style.display='flex'"
          />
          <!-- Fallback content when image fails to load -->
          <div
            class="w-full h-full bg-gradient-to-br from-purple-100 to-pink-100 flex items-center justify-center"
            style="display: none;"
          >
            <div class="text-center p-4">
              <div class="w-12 h-12 bg-purple-500 rounded-lg mx-auto mb-3 flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M7 4v16l13-8L7 4z"
                  />
                </svg>
              </div>
              <p class="text-sm font-semibold text-gray-700">Rhythm Theme</p>
              <p class="text-xs text-gray-600">Video sliding flow</p>
            </div>
          </div>
        </div>
      <% _ -> %>
        <div class="w-full h-full bg-gray-100 flex items-center justify-center rounded-lg">
          <div class="text-center text-gray-500">
            <svg class="w-12 h-12 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="1"
                d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2 2v12a2 2 0 002 2z"
              />
            </svg>
            <div class="text-sm">Theme Preview</div>
          </div>
        </div>
    <% end %>
    """
  end

  # Helper function to get security metadata
  defp get_security_metadata(socket) do
    DashboardHelpers.get_security_metadata(socket)
  end
end
