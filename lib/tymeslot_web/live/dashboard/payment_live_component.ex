defmodule TymeslotWeb.Dashboard.PaymentLiveComponent do
  @moduledoc """
  Payment management component for the dashboard.

  This component provides a placeholder interface for upcoming Stripe payment integration,
  showing users what payment features will be available once implemented.
  """

  use TymeslotWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <.section_header icon={:credit_card} title="Payment Management" />

      <div class="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700">
        <!-- Coming Soon Notice -->
        <div class="bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-600 rounded-token-3xl p-10 lg:p-16 text-white shadow-2xl shadow-indigo-500/20 relative overflow-hidden group">
          <div class="absolute inset-0 bg-[radial-gradient(circle_at_30%_20%,rgba(255,255,255,0.15),transparent_50%)]"></div>
          <div class="absolute -right-20 -bottom-20 w-96 h-96 bg-white/10 rounded-full blur-3xl group-hover:scale-110 transition-transform duration-1000"></div>
          
          <div class="relative z-10 flex flex-col md:flex-row items-center gap-10">
            <div class="w-24 h-24 bg-white/20 rounded-[2.5rem] flex items-center justify-center backdrop-blur-xl border-4 border-white/30 shadow-2xl">
              <svg class="h-12 w-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <div class="text-center md:text-left flex-1">
              <h3 class="text-3xl lg:text-4xl font-black mb-4 tracking-tight">Payment Features Coming Soon</h3>
              <p class="text-token-xl text-white/90 font-medium leading-relaxed max-w-2xl">
                We're currently integrating <span class="font-black text-white">Stripe</span> to enable secure, global payment processing for your meetings. Monetize your expertise with zero friction.
              </p>
            </div>
          </div>
        </div>
        
    <!-- Features Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Planned Features -->
          <div class="card-glass h-full">
            <div class="flex items-center gap-4 mb-10">
              <div class="w-12 h-12 bg-emerald-50 rounded-token-xl flex items-center justify-center border border-emerald-100 shadow-sm">
                <svg class="h-6 w-6 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                </svg>
              </div>
              <h4 class="text-2xl font-black text-tymeslot-900 tracking-tight">Planned Features</h4>
            </div>

            <div class="grid gap-6">
              <%= for {title, desc} <- [
                {"Custom Pricing", "Set different prices for each meeting type automatically."},
                {"Pre-meeting Payments", "Require payment confirmation before bookings are finalized."},
                {"Automatic Refunds", "Securely process refunds for any cancelled appointments."},
                {"Revenue Analytics", "Detailed dashboards to track your earnings over time."}
              ] do %>
                <div class="flex items-start gap-4 p-4 rounded-token-2xl bg-tymeslot-50/50 border-2 border-tymeslot-50 hover:bg-white hover:border-turquoise-100 transition-all group">
                  <div class="w-6 h-6 rounded-full bg-emerald-50 flex items-center justify-center mt-1 flex-shrink-0 border border-emerald-100">
                    <svg class="w-3 h-3 text-emerald-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-tymeslot-900 font-black tracking-tight group-hover:text-turquoise-700 transition-colors">{title}</p>
                    <p class="text-tymeslot-500 font-medium text-token-sm leading-relaxed">{desc}</p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
          
    <!-- Stripe Benefits -->
          <div class="card-glass h-full">
            <div class="flex items-center gap-4 mb-10">
              <div class="w-12 h-12 bg-purple-50 rounded-token-xl flex items-center justify-center border border-purple-100 shadow-sm">
                <svg class="h-6 w-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
              </div>
              <h4 class="text-2xl font-black text-tymeslot-900 tracking-tight">Why Stripe?</h4>
            </div>

            <div class="grid gap-6">
              <%= for {title, desc} <- [
                {"Enterprise Security", "PCI-compliant with industry-leading fraud protection built-in."},
                {"Global Payments", "Support for 135+ currencies and all major local methods."},
                {"Financial Reporting", "Detailed exportable analytics and automated tax documents."},
                {"Instant Payouts", "Get your hard-earned money faster into your bank account."}
              ] do %>
                <div class="flex items-start gap-4 p-4 rounded-token-2xl bg-tymeslot-50/50 border-2 border-tymeslot-50 hover:bg-white hover:border-turquoise-100 transition-all group">
                  <div class="w-6 h-6 rounded-full bg-purple-50 flex items-center justify-center mt-1 flex-shrink-0 border border-purple-100">
                    <svg class="w-3 h-3 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M13 10V3L4 14h7v7l9-11h-7z" />
                    </svg>
                  </div>
                  <div>
                    <p class="text-tymeslot-900 font-black tracking-tight group-hover:text-turquoise-700 transition-colors">{title}</p>
                    <p class="text-tymeslot-500 font-medium text-token-sm leading-relaxed">{desc}</p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
