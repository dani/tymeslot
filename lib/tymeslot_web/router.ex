defmodule TymeslotWeb.Router do
  use TymeslotWeb, :router

  # =============================================================================
  # Healthcheck (early to avoid wildcard username routes)
  # =============================================================================

  scope "/", TymeslotWeb do
    pipe_through :api

    get "/healthcheck", HealthcheckController, :index
  end

  # =============================================================================
  # Webhook Routes
  # =============================================================================

  scope "/webhooks", TymeslotWeb do
    pipe_through :webhook

    post "/stripe", StripeWebhookController, :webhook
  end

  # =============================================================================
  # Core Root Route
  # =============================================================================

  scope "/", TymeslotWeb do
    pipe_through :browser

    get "/", RootRedirectController, :index
  end

  # =============================================================================
  # Authentication Routes
  # =============================================================================

  scope "/", TymeslotWeb do
    pipe_through :browser

    # LiveView authentication routes
    live "/auth/login", AuthLive, :login
    live "/auth/signup", AuthLive, :signup
    live "/auth/verify-email", AuthLive, :verify_email
    live "/auth/reset-password", AuthLive, :reset_password
    live "/auth/reset-password-sent", AuthLive, :reset_password_sent
    live "/auth/reset-password/:token", AuthLive, :reset_password_form
    live "/auth/complete-registration", AuthLive, :complete_registration
    live "/auth/password-reset-success", AuthLive, :password_reset_success

    # Email change verification route
    get "/email-change/:token", EmailChangeController, :verify

    # OAuth routes (must remain as controllers for external redirects)
    get "/auth/:provider", OAuthController, :request
    get "/auth/:provider/callback", OAuthController, :callback
    post "/auth/complete", OAuthController, :complete

    # Calendar OAuth routes
    get "/auth/google/calendar/callback", CalendarOAuthController, :google_callback
    get "/auth/outlook/calendar/callback", CalendarOAuthController, :outlook_callback

    # Video OAuth routes
    get "/auth/google/video/callback", VideoOAuthController, :google_callback
    get "/auth/teams/video/callback", VideoOAuthController, :teams_callback

    # Session management routes
    post "/auth/session", SessionController, :create
    delete "/auth/logout", SessionController, :delete
    get "/auth/verify-complete/:token", SessionController, :verify_and_login
  end

  # =============================================================================
  # Authenticated Routes
  # =============================================================================

  # Dashboard routes
  scope "/", TymeslotWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated,
      on_mount: [
        {TymeslotWeb.Hooks.AuthLiveSessionHook, :ensure_authenticated},
        TymeslotWeb.Hooks.ClientInfoHook,
        TymeslotWeb.Hooks.DashboardInitHook
      ] do
      live "/dashboard", DashboardLive, :overview
      live "/dashboard/settings", DashboardLive, :settings
      live "/dashboard/availability", DashboardLive, :availability
      live "/dashboard/account", AccountLive
      live "/dashboard/meeting-settings", DashboardLive, :meeting_settings
      live "/dashboard/calendar", DashboardLive, :calendar
      live "/dashboard/video", DashboardLive, :video
      live "/dashboard/automation", DashboardLive, :automation
      live "/dashboard/theme", DashboardLive, :theme
      live "/dashboard/theme/customize/:theme_id", DashboardLive, :theme_customization
      live "/dashboard/meetings", DashboardLive, :meetings
      live "/dashboard/embed", DashboardLive, :embed
    end
  end

  # Onboarding routes
  scope "/", TymeslotWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :onboarding,
      on_mount: [
        {TymeslotWeb.Hooks.AuthLiveSessionHook, :ensure_authenticated},
        TymeslotWeb.Hooks.ClientInfoHook
      ] do
      live "/onboarding", OnboardingLive, :welcome
      live "/onboarding/:step", OnboardingLive, :step
    end
  end

  # =============================================================================
  # Theme/Scheduling Routes
  # =============================================================================

  # Meeting management routes
  scope "/", TymeslotWeb do
    pipe_through :theme_browser

    live_session :meeting_management,
      on_mount: [
        TymeslotWeb.Hooks.LocaleHook,
        TymeslotWeb.Hooks.ThemeHook,
        TymeslotWeb.Hooks.ClientInfoHook
      ] do
      live "/:username/meeting/:meeting_uid/cancel", Themes.Core.Dispatcher, :cancel

      live "/:username/meeting/:meeting_uid/cancel-confirmed",
           Themes.Core.Dispatcher,
           :cancel_confirmed

      live "/:username/meeting/:meeting_uid/reschedule", Themes.Core.Dispatcher, :reschedule
    end
  end

  # Username-based scheduling routes (must be before catch-all)
  scope "/", TymeslotWeb do
    pipe_through :theme_browser

    live_session :username_scheduling,
      on_mount: [
        TymeslotWeb.Hooks.LocaleHook,
        TymeslotWeb.Hooks.ThemeHook,
        TymeslotWeb.Hooks.ClientInfoHook
      ] do
      live "/:username", Themes.Core.Dispatcher, :overview
      live "/:username/thank-you", Themes.Core.Dispatcher, :confirmation
      live "/:username/:slug", Themes.Core.Dispatcher, :schedule
      live "/:username/:slug/book", Themes.Core.Dispatcher, :booking
    end
  end

  # =============================================================================
  # API Routes
  # =============================================================================
  # =============================================================================
  # Development Routes
  # =============================================================================

  if Application.compile_env(:tymeslot, :dev_routes) do
    pipeline :local_only do
      plug TymeslotWeb.Plugs.EnsureLocalAccessPlug
    end

    # Swoosh mailbox preview
    scope "/dev" do
      pipe_through :browser
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    # Debug routes
    scope "/debug", TymeslotWeb do
      pipe_through [:browser, :local_only, :require_authenticated_user]

      live_session :debug_onboarding,
        on_mount: [{TymeslotWeb.Hooks.AuthLiveSessionHook, :ensure_authenticated}] do
        live "/onboarding", OnboardingLive, :debug_welcome
        live "/onboarding/:step", OnboardingLive, :debug_step
      end
    end
  end

  # =============================================================================
  # Catch-all Route
  # =============================================================================

  scope "/", TymeslotWeb do
    pipe_through :browser

    get "/*path", FallbackController, :index
  end
end
