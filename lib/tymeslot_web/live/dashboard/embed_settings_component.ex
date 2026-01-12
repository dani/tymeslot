defmodule TymeslotWeb.Live.Dashboard.EmbedSettingsComponent do
  @moduledoc """
  Dashboard component for embedding options.
  Shows users different ways to embed their booking page with live previews.
  """
  use TymeslotWeb, :live_component

  alias Ecto.Changeset
  alias Tymeslot.Profiles
  alias Tymeslot.Scheduling.LinkAccessPolicy
  alias Tymeslot.Security.RateLimiter
  alias TymeslotWeb.Endpoint
  alias TymeslotWeb.Live.Shared.Flash

  require Logger

  import Phoenix.LiveView, only: [push_event: 3]

  @impl true
  def update(assigns, socket) do
    # Extract props from parent
    profile = assigns.profile
    base_url = Endpoint.url()
    username = profile.username
    theme_id = profile.booking_theme || "1"

    # Check if user is ready for scheduling
    scheduling_readiness = LinkAccessPolicy.check_public_readiness(profile)
    is_ready = match?({:ok, :ready}, scheduling_readiness)
    error_reason = if is_ready, do: nil, else: elem(scheduling_readiness, 1)

    # Format allowed domains for display
    allowed_domains_str =
      case profile.allowed_embed_domains do
        nil -> ""
        [] -> ""
        domains -> Enum.join(domains, ", ")
      end

    # Only reload from DB if:
    # 1. First mount (no __embed_initialized__ flag), OR
    # 2. Profile ID changed (user switched accounts)
    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:profile, profile)
      |> assign(:current_user, assigns.current_user)
      |> assign(:base_url, base_url)
      |> assign(:username, username)
      |> assign(:theme_id, theme_id)
      |> assign(:booking_url, "#{base_url}/#{username}")
      |> assign(:embed_url, "#{base_url}/embed/#{username}")
      |> assign(:is_ready, is_ready)
      |> assign(:error_reason, error_reason)
      |> assign(:allowed_domains_str, allowed_domains_str)
      |> assign(:__embed_initialized__, true)
      |> assign(:__profile_id__, profile.id)
      |> assign_new(:selected_embed_type, fn -> "inline" end)
      |> assign_new(:show_preview, fn -> false end)
      |> assign_new(:embed_script_url, fn -> ~p"/embed.js" end)
      |> assign_new(:show_security_section, fn -> false end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <!-- Header -->
      <.section_header
        icon={:code}
        title="Embed & Share"
        class="mb-4"
      />

      <p class="text-tymeslot-600 mb-10">
        Add your booking page to any website. Choose the option that works best for you.
      </p>

      <!-- Embed Options -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Option 1: Inline Embed -->
        <div
          class={["embed-option-card cursor-pointer group relative", @selected_embed_type == "inline" && "border-turquoise-500 shadow-md"]}
          phx-click="select_embed_type"
          phx-value-type="inline"
          phx-target={@myself}
        >
          <div :if={@selected_embed_type == "inline"} class="absolute -top-3 -right-3 w-8 h-8 bg-turquoise-600 rounded-full flex items-center justify-center text-white shadow-lg z-10">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="text-token-xl font-bold text-tymeslot-900">Inline Embed</h3>
                <p class="text-token-sm text-tymeslot-600 mt-1">Embed directly into your webpage</p>
              </div>
              <span class="px-3 py-1 text-token-xs font-semibold bg-turquoise-100 text-turquoise-700 rounded-full">
                Recommended
              </span>
            </div>

            <!-- Preview -->
            <div class="mb-4 bg-tymeslot-50 rounded-token-lg p-4 border-2 border-tymeslot-200">
              <div class="bg-white rounded shadow-sm p-4">
                <div class="flex items-center space-x-2 mb-3">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="space-y-2">
                  <div class="h-2 bg-tymeslot-200 rounded w-3/4"></div>
                  <div class="h-2 bg-tymeslot-200 rounded w-1/2"></div>
                  <div class="mt-4 p-3 bg-gradient-to-br from-turquoise-50 to-cyan-50 border-2 border-turquoise-200 rounded-token-lg">
                    <div class="flex items-center space-x-2">
                      <svg class="w-4 h-4 text-turquoise-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                      </svg>
                      <div class="text-token-xs font-semibold text-turquoise-700">Your booking widget here</div>
                    </div>
                  </div>
                  <div class="h-2 bg-tymeslot-200 rounded w-2/3"></div>
                </div>
              </div>
            </div>

            <!-- Code Snippet -->
          <div class="relative">
            <pre class="bg-tymeslot-900 text-tymeslot-100 rounded-token-lg p-4 text-token-xs overflow-x-auto"><code>&lt;div id="tymeslot-booking" 
                  data-username="<%= @username %>"&gt;&lt;/div&gt;
                &lt;script src="<%= @base_url %>/embed.js"&gt;&lt;/script&gt;</code></pre>
            <button
                type="button"
                phx-click="copy_code"
                phx-value-type="inline"
                phx-target={@myself}
                class="absolute top-2 right-2 px-3 py-1 bg-turquoise-600 hover:bg-turquoise-700 text-white text-token-xs font-semibold rounded transition-colors"
              >
                Copy
              </button>
            </div>

            <div class="mt-4 flex items-start space-x-2 text-token-xs text-tymeslot-600">
              <svg class="w-4 h-4 text-turquoise-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>Embeds seamlessly into your page content. Works with WordPress, Webflow, Wix, and custom sites.</span>
            </div>
          </div>
        </div>

        <!-- Option 2: Popup Button -->
        <div
          class={["embed-option-card cursor-pointer group relative", @selected_embed_type == "popup" && "border-turquoise-500 shadow-md"]}
          phx-click="select_embed_type"
          phx-value-type="popup"
          phx-target={@myself}
        >
          <div :if={@selected_embed_type == "popup"} class="absolute -top-3 -right-3 w-8 h-8 bg-turquoise-600 rounded-full flex items-center justify-center text-white shadow-lg z-10">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="text-token-xl font-bold text-tymeslot-900">Popup Modal</h3>
                <p class="text-token-sm text-tymeslot-600 mt-1">Trigger a modal overlay with a button</p>
              </div>
              <span class="px-3 py-1 text-token-xs font-semibold bg-blue-100 text-blue-700 rounded-full">
                Popular
              </span>
            </div>

            <!-- Preview -->
            <div class="mb-4 bg-tymeslot-50 rounded-token-lg p-4 border-2 border-tymeslot-200">
              <div class="bg-white rounded shadow-sm p-4">
                <div class="flex items-center space-x-2 mb-3">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="space-y-2">
                  <div class="h-2 bg-tymeslot-200 rounded w-3/4"></div>
                  <div class="h-2 bg-tymeslot-200 rounded w-1/2"></div>
                  <div class="mt-4 flex justify-center">
                    <div 
                      class="px-4 py-2 text-white text-token-xs font-bold rounded-token-lg shadow-lg bg-turquoise-600"
                    >
                      Book a Meeting →
                    </div>
                  </div>
                  <div class="h-2 bg-tymeslot-200 rounded w-2/3"></div>
                </div>
              </div>
            </div>

            <!-- Code Snippet -->
            <div class="relative">
              <pre class="bg-tymeslot-900 text-tymeslot-100 rounded-token-lg p-4 text-token-xs overflow-x-auto"><code>&lt;button onclick="TymeslotBooking.open('<%= @username %>')"&gt;
                  Book a Meeting
                &lt;/button&gt;
                &lt;script src="<%= @base_url %>/embed.js"&gt;&lt;/script&gt;</code></pre>
              <button
                type="button"
                phx-click="copy_code"
                phx-value-type="popup"
                phx-target={@myself}
                class="absolute top-2 right-2 px-3 py-1 bg-turquoise-600 hover:bg-turquoise-700 text-white text-token-xs font-semibold rounded transition-colors"
              >
                Copy
              </button>
            </div>

            <div class="mt-4 flex items-start space-x-2 text-token-xs text-tymeslot-600">
              <svg class="w-4 h-4 text-turquoise-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>Opens booking in a fullscreen modal. Great for CTAs and hero sections.</span>
            </div>
          </div>
        </div>

        <!-- Option 3: Direct Link -->
        <div
          class={["embed-option-card cursor-pointer group relative", @selected_embed_type == "link" && "border-turquoise-500 shadow-md"]}
          phx-click="select_embed_type"
          phx-value-type="link"
          phx-target={@myself}
        >
          <div :if={@selected_embed_type == "link"} class="absolute -top-3 -right-3 w-8 h-8 bg-turquoise-600 rounded-full flex items-center justify-center text-white shadow-lg z-10">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="text-token-xl font-bold text-tymeslot-900">Direct Link</h3>
                <p class="text-token-sm text-tymeslot-600 mt-1">Simple link to your booking page</p>
              </div>
              <span class="px-3 py-1 text-token-xs font-semibold bg-tymeslot-100 text-tymeslot-700 rounded-full">
                Easiest
              </span>
            </div>

            <!-- Preview -->
            <div class="mb-4 bg-tymeslot-50 rounded-token-lg p-4 border-2 border-tymeslot-200">
              <div class="bg-white rounded shadow-sm p-4">
                <div class="flex items-center space-x-2 mb-3">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="space-y-2">
                  <div class="h-2 bg-tymeslot-200 rounded w-3/4"></div>
                  <div class="h-2 bg-tymeslot-200 rounded w-1/2"></div>
                  <div class="mt-4">
                    <div class="text-token-xs text-turquoise-600 underline font-medium">
                      Schedule a meeting with me →
                    </div>
                  </div>
                  <div class="h-2 bg-tymeslot-200 rounded w-2/3"></div>
                </div>
              </div>
            </div>

            <!-- Code Snippet -->
            <div class="relative">
              <pre class="bg-tymeslot-900 text-tymeslot-100 rounded-token-lg p-4 text-token-xs overflow-x-auto"><code>&lt;a href="<%= @booking_url %>"&gt;
                  Schedule a meeting
                &lt;/a&gt;</code></pre>
              <button
                type="button"
                phx-click="copy_code"
                phx-value-type="link"
                phx-target={@myself}
                class="absolute top-2 right-2 px-3 py-1 bg-turquoise-600 hover:bg-turquoise-700 text-white text-token-xs font-semibold rounded transition-colors"
              >
                Copy
              </button>
            </div>

            <div class="mt-4 flex items-start space-x-2 text-token-xs text-tymeslot-600">
              <svg class="w-4 h-4 text-turquoise-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>Share in emails, social media, or anywhere you can paste a link.</span>
            </div>
          </div>
        </div>

        <!-- Option 4: Floating Widget -->
        <div
          class={["embed-option-card cursor-pointer group relative", @selected_embed_type == "floating" && "border-turquoise-500 shadow-md"]}
          phx-click="select_embed_type"
          phx-value-type="floating"
          phx-target={@myself}
        >
          <div :if={@selected_embed_type == "floating"} class="absolute -top-3 -right-3 w-8 h-8 bg-turquoise-600 rounded-full flex items-center justify-center text-white shadow-lg z-10">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"></path>
            </svg>
          </div>
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="text-token-xl font-bold text-tymeslot-900">Floating Button</h3>
                <p class="text-token-sm text-tymeslot-600 mt-1">Fixed button in corner of page</p>
              </div>
              <span class="px-3 py-1 text-token-xs font-semibold bg-purple-100 text-purple-700 rounded-full">
                Pro
              </span>
            </div>

            <!-- Preview -->
            <div class="mb-4 bg-tymeslot-50 rounded-token-lg p-4 border-2 border-tymeslot-200 relative">
              <div class="bg-white rounded shadow-sm p-4">
                <div class="flex items-center space-x-2 mb-3">
                  <div class="w-3 h-3 rounded-full bg-red-400"></div>
                  <div class="w-3 h-3 rounded-full bg-yellow-400"></div>
                  <div class="w-3 h-3 rounded-full bg-green-400"></div>
                </div>
                <div class="space-y-2">
                  <div class="h-2 bg-tymeslot-200 rounded w-3/4"></div>
                  <div class="h-2 bg-tymeslot-200 rounded w-1/2"></div>
                  <div class="h-2 bg-tymeslot-200 rounded w-2/3"></div>
                </div>
              </div>
              <!-- Floating button preview -->
              <div class="absolute bottom-6 right-6">
                <div 
                  class="w-12 h-12 rounded-full shadow-lg flex items-center justify-center bg-turquoise-600"
                >
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Code Snippet -->
            <div class="relative">
              <pre class="bg-tymeslot-900 text-tymeslot-100 rounded-token-lg p-4 text-token-xs overflow-x-auto"><code>&lt;script src="<%= @base_url %>/assets/embed.js"&gt;&lt;/script&gt;
                &lt;script&gt;
                  TymeslotBooking.initFloating('<%= @username %>');
                &lt;/script&gt;</code></pre>
              <button
                type="button"
                phx-click="copy_code"
                phx-value-type="floating"
                phx-target={@myself}
                class="absolute top-2 right-2 px-3 py-1 bg-turquoise-600 hover:bg-turquoise-700 text-white text-token-xs font-semibold rounded transition-colors"
              >
                Copy
              </button>
            </div>

            <div class="mt-4 flex items-start space-x-2 text-token-xs text-tymeslot-600">
              <svg class="w-4 h-4 text-turquoise-600 flex-shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <span>Always visible on every page. Like a chat widget for booking meetings.</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Security Settings Section -->
      <div class="bg-white rounded-token-2xl border-2 border-tymeslot-200 p-8">
        <div class="flex items-start justify-between mb-6">
          <div class="flex-1">
            <div class="flex items-center space-x-3 mb-2">
              <svg class="w-6 h-6 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
              </svg>
              <h3 class="text-token-2xl font-bold text-tymeslot-900">Security & Domain Control</h3>
            </div>
            <p class="text-tymeslot-600">
              Control which websites can embed your booking page
            </p>
          </div>
          <button
            type="button"
            phx-click="toggle_security_section"
            phx-target={@myself}
            class="px-4 py-2 text-token-sm font-semibold text-turquoise-700 hover:bg-turquoise-50 rounded-token-lg transition-colors"
          >
            <%= if @show_security_section, do: "Hide", else: "Configure" %>
          </button>
        </div>

        <div :if={@show_security_section} class="space-y-6">
          <!-- Explanation -->
          <div class="bg-gradient-to-r from-blue-50 to-cyan-50 border-2 border-blue-200 rounded-token-xl p-6">
            <div class="flex items-start space-x-3">
              <svg class="w-6 h-6 text-blue-600 flex-shrink-0 mt-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
              </svg>
              <div class="space-y-2 text-token-sm">
                <p class="font-semibold text-blue-900">How Domain Whitelisting Works</p>
                <p class="text-blue-800">
                  By default, anyone can embed your booking page on their website if they know your username. 
                  This is similar to how YouTube videos work - public and embeddable everywhere.
                </p>
                <p class="text-blue-800">
                  For security, you can <strong>optionally restrict embedding</strong> to only specific domains you trust. 
                  This prevents your booking page from appearing on unauthorized websites.
                </p>
                <ul class="list-disc list-inside text-blue-800 space-y-1 mt-2">
                  <li><strong>Leave empty</strong> to allow embedding on any website (default)</li>
                  <li><strong>Add domains</strong> to restrict embedding to only those sites</li>
                  <li>Example: <code class="bg-blue-100 px-2 py-0.5 rounded">example.com, myportfolio.net</code></li>
                </ul>
              </div>
            </div>
          </div>

          <!-- Domain Input Form -->
          <form phx-submit="save_embed_domains" phx-target={@myself} class="space-y-4">
            <div>
              <label for="allowed_domains" class="block text-token-sm font-semibold text-tymeslot-700 mb-2">
                Allowed Domains (Optional)
              </label>
              <input
                type="text"
                id="allowed_domains"
                name="allowed_domains"
                value={@allowed_domains_str}
                placeholder="example.com, myportfolio.net (leave empty to allow all)"
                class="w-full px-4 py-3 border-2 border-tymeslot-300 rounded-token-lg focus:ring-2 focus:ring-turquoise-500 focus:border-turquoise-500 transition-colors"
              />
              <p class="mt-2 text-token-xs text-tymeslot-600">
                Enter domains separated by commas. Don't include <code class="bg-tymeslot-100 px-1 py-0.5 rounded">https://</code> or paths.
              </p>
            </div>

            <!-- Current Status -->
            <div class="bg-tymeslot-50 rounded-token-lg p-4 border-2 border-tymeslot-200">
              <p class="text-token-sm font-semibold text-tymeslot-700 mb-2">Current Status:</p>
              <div class="flex items-center space-x-2">
                <%= if @allowed_domains_str == "" do %>
                  <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                  </svg>
                  <span class="text-token-sm text-tymeslot-700">
                    <strong>Open:</strong> Anyone can embed your booking page (default)
                  </span>
                <% else %>
                  <svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"></path>
                  </svg>
                  <span class="text-token-sm text-tymeslot-700">
                    <strong>Restricted:</strong> Only <%= @allowed_domains_str %> can embed
                  </span>
                <% end %>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex space-x-3">
              <button
                type="submit"
                class="px-6 py-3 bg-gradient-to-r from-turquoise-600 to-cyan-600 hover:from-turquoise-700 hover:to-cyan-700 text-white font-bold rounded-token-xl shadow-lg transition-all transform hover:scale-105"
              >
                Save Security Settings
              </button>
              <%= if @allowed_domains_str != "" do %>
                <button
                  type="button"
                  phx-click="clear_embed_domains"
                  phx-target={@myself}
                  class="px-6 py-3 bg-tymeslot-200 hover:bg-tymeslot-300 text-tymeslot-700 font-semibold rounded-token-xl transition-colors"
                >
                  Clear & Allow All
                </button>
              <% end %>
            </div>
          </form>

        </div>
      </div>

      <!-- Live Preview Section -->
      <div class="bg-gradient-to-br from-tymeslot-50 to-tymeslot-100 rounded-token-2xl border-2 border-tymeslot-200 p-8">
        <div class="flex items-center justify-between mb-6">
          <div>
            <h3 class="text-token-2xl font-bold text-tymeslot-900">Test It Live</h3>
            <p class="text-tymeslot-600 mt-1">Try your booking widget in action</p>
          </div>
          <button
            type="button"
            phx-click="toggle_preview"
            phx-target={@myself}
            class="px-6 py-3 bg-gradient-to-r from-turquoise-600 to-cyan-600 hover:from-turquoise-700 hover:to-cyan-700 text-white font-bold rounded-token-xl shadow-lg transition-all transform hover:scale-105"
          >
            <%= if @show_preview, do: "Hide Preview", else: "Show Preview" %>
          </button>
        </div>

        <div :if={@show_preview} class="bg-white rounded-token-xl p-6 border-2 border-tymeslot-300 shadow-xl">
          <div class="text-center text-tymeslot-600 mb-4">
            <p class="font-semibold text-turquoise-700">Previewing: <%= String.capitalize(@selected_embed_type) %> Mode</p>
            <p class="text-token-sm">This is how your booking widget will appear on external sites</p>
          </div>

          <!-- Readiness Warning -->
          <div :if={!@is_ready} class="mb-6 p-4 bg-amber-50 border-2 border-amber-200 rounded-token-xl flex items-start space-x-3">
            <svg class="w-6 h-6 text-amber-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>
            </svg>
            <div>
              <p class="text-token-sm font-bold text-amber-900">Link Deactivated</p>
              <p class="text-token-xs text-amber-800">
                <%= LinkAccessPolicy.reason_to_message(@error_reason) %>
              </p>
            </div>
          </div>

          <!-- The actual booking widget will be loaded here via JavaScript -->
          <div
            id="live-preview-container"
            phx-hook="EmbedPreview"
            data-username={@username}
            data-base-url={@base_url}
            data-embed-script-url={@embed_script_url}
            data-embed-type={@selected_embed_type}
            data-is-ready={to_string(@is_ready)}
            class="min-h-[400px] border-2 border-dashed border-tymeslot-200 rounded-token-lg flex items-center justify-center bg-tymeslot-50 overflow-hidden"
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("copy_code", %{"type" => type}, socket) do
    code =
      case type do
        "inline" ->
          """
          <div id="tymeslot-booking" data-username="#{socket.assigns.username}"></div>
          <script src="#{socket.assigns.base_url}/embed.js"></script>
          """

        "popup" ->
          """
          <button onclick="TymeslotBooking.open('#{socket.assigns.username}')">Book a Meeting</button>
          <script src="#{socket.assigns.base_url}/embed.js"></script>
          """

        "link" ->
          """
          <a href="#{socket.assigns.booking_url}">Schedule a meeting</a>
          """

        "floating" ->
          """
          <script src="#{socket.assigns.base_url}/embed.js"></script>
          <script>
            TymeslotBooking.initFloating('#{socket.assigns.username}');
          </script>
          """

        _ ->
          ""
      end

    {:noreply,
     socket
     |> push_event("copy-to-clipboard", %{text: String.trim(code)})
     |> then(fn s ->
       Flash.info("Code copied to clipboard!")
       s
     end)}
  end

  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  def handle_event("select_embed_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_embed_type, type)}
  end

  def handle_event("toggle_security_section", _params, socket) do
    {:noreply, assign(socket, :show_security_section, !socket.assigns.show_security_section)}
  end

  def handle_event("save_embed_domains", %{"allowed_domains" => domains_str}, socket) do
    perform_domain_update(socket, domains_str, "Security settings saved successfully!")
  end

  def handle_event("clear_embed_domains", _params, socket) do
    perform_domain_update(socket, [], "Embedding is now allowed on all domains")
  end

  defp perform_domain_update(socket, domains_payload, success_message) do
    user_id = socket.assigns.current_user.id

    # Rate limit: 10 updates per hour per user
    case RateLimiter.check_rate(
           "embed_domain_update:#{user_id}",
           60_000 * 60,
           10
         ) do
      {:allow, _count} ->
        case Profiles.update_allowed_embed_domains(socket.assigns.profile, domains_payload) do
          {:ok, updated_profile} ->
            # Format the domains for display
            allowed_domains_str =
              case updated_profile.allowed_embed_domains do
                nil -> ""
                [] -> ""
                domains -> Enum.join(domains, ", ")
              end

            {:noreply,
             socket
             |> assign(:profile, updated_profile)
             |> assign(:allowed_domains_str, allowed_domains_str)
             |> then(fn s ->
               Flash.info(success_message)
               s
             end)}

          {:error, %Changeset{} = changeset} ->
            errors =
              Enum.map_join(
                Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end),
                "; ",
                fn {field, messages} ->
                  "#{field}: #{Enum.join(messages, ", ")}"
                end
              )

            Flash.error("Failed to save: #{errors}")
            {:noreply, socket}
        end

      {:deny, _limit} ->
        Logger.warning("Embed domain update rate limit exceeded", user_id: user_id)

        Flash.error("Too many updates. Please wait a moment before trying again.")
        {:noreply, socket}
    end
  end
end
