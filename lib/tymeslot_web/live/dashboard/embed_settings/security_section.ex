defmodule TymeslotWeb.Live.Dashboard.EmbedSettings.SecuritySection do
  @moduledoc """
  Renders the security settings section for the embed settings dashboard.
  """
  use Phoenix.Component

  @doc """
  Renders the security settings section.
  """
  attr :show_security_section, :boolean, required: true
  attr :allowed_domains_str, :string, required: true
  attr :myself, :any, required: true

  @spec security_section(map()) :: Phoenix.LiveView.Rendered.t()
  def security_section(assigns) do
    ~H"""
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
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
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
    """
  end
end
