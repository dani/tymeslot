import Config

# =============================================================================
# TYMESLOT CORE: BASE CONFIGURATION
# =============================================================================
# Core provides the infrastructure and default behaviors for a standalone
# scheduling engine. All advanced features are disabled by default.
config :tymeslot,
  ecto_repos: [Tymeslot.Repo],
  generators: [timestamp_type: :utc_datetime],

  # --- Mode Detection ---
  # Enables specific behaviors when running in a distributed environment
  saas_mode: false,

  # Controls whether users must accept T&C/Privacy during registration
  enforce_legal_agreements: false,
  legal_terms_url: nil,
  legal_privacy_url: nil,

  # Navigation: Where the logo/home link points to
  site_home_path: "/dashboard",
  repo: Tymeslot.Repo,
  contact_url: nil,
  privacy_policy_url: nil,
  terms_and_conditions_url: nil,

  # --- Integration & Routing ---
  # The primary router to use for the application
  router: TymeslotWeb.Router,

  # Default email settings for standalone use
  email_adapter_default: "smtp",
  contact_form_template: nil,
  support_request_template: nil,
  trial_ending_reminder_template: nil,
  refund_processed_template: nil,
  dispute_alert_template: nil,

  # Theme protection plugs - empty by default (external layers can add restrictions)
  extra_theme_protection_plugs: [],

  # Theme extensions - empty by default (external layers can add overlays/branding)
  theme_extensions: [],

  # Demo provider - no-op by default (can be provided by external layers)
  demo_provider: Tymeslot.Demo.NoOp,

  # Subscription manager - nil by default (can be provided by external layers)
  subscription_manager: nil,

  # Admin alerts module - nil by default (can be provided by external layers)
  admin_alerts: nil,

  # Dashboard Extensions
  dashboard_sidebar_extensions: [],
  dashboard_action_components: %{}


# Webhook configuration
config :tymeslot, :webhook_paths, ["/webhooks/stripe"]

# =============================================================================
# INTERNATIONALIZATION (I18N) CONFIGURATION
# =============================================================================

# Configure Gettext locales
config :tymeslot, TymeslotWeb.Gettext,
  default_locale: "en",
  locales: ~w(en de uk)

# Locale metadata for UI rendering
config :tymeslot, :locales,
  supported: [
    %{code: "en", name: "English", country_code: :gbr},
    %{code: "de", name: "Deutsch", country_code: :deu},
    %{code: "uk", name: "Українська", country_code: :ukr}
  ],
  default: "en"

# =============================================================================
# SHARED INFRASTRUCTURE CONFIGURATION
# =============================================================================

# Configure HTTP client timeouts
config :tymeslot, :http_timeouts, %{
  get: [timeout: 30_000, recv_timeout: 30_000],
  put: [timeout: 45_000, recv_timeout: 45_000],
  delete: [timeout: 45_000, recv_timeout: 45_000],
  report: [timeout: 60_000, recv_timeout: 60_000]
}

# Configures the endpoint
config :tymeslot, TymeslotWeb.Endpoint,
  url: [host: "localhost", scheme: "http"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TymeslotWeb.ErrorHTML, json: TymeslotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tymeslot.PubSub

# Configures the mailer
config :tymeslot, Tymeslot.Mailer, adapter: Swoosh.Adapters.Local

# Configure Swoosh API client
config :swoosh, :api_client, Swoosh.ApiClient.Hackney

# Configure esbuild
config :esbuild,
  version: "0.17.11",
  tymeslot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../../../deps", __DIR__)}
  ]

# Configure tailwind
config :tailwind,
  version: "3.4.3",
  tymeslot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ],
  scheduling: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/scheduling.css
      --output=../priv/static/assets/scheduling.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ],
  quill: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/scheduling/themes/quill/theme.css
      --output=../priv/static/assets/scheduling-theme-quill.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ],
  rhythm: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/scheduling/themes/rhythm/theme.css
      --output=../priv/static/assets/scheduling-theme-rhythm.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n"

import_config "logger_metadata.exs"

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure timezone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

# Authentication configuration
config :tymeslot, :auth, success_redirect_path: "/dashboard"

# Input validation configuration
config :tymeslot, :field_validation,
  email_max_length: 254,
  name_min_length: 2,
  name_max_length: 100,
  universal_max_length: 10_000,
  password_min_length: 8,
  password_max_length: 80,
  full_name_max_length: 100

# Social Authentication Configuration
config :tymeslot, :social_auth,
  google_enabled: System.get_env("ENABLE_GOOGLE_AUTH", "false") == "true",
  github_enabled: System.get_env("ENABLE_GITHUB_AUTH", "false") == "true"

# Provider enable/disable switches
config :tymeslot, :video_providers, %{
  mirotalk: [enabled: true],
  google_meet: [enabled: true],
  teams: [enabled: true],
  custom: [enabled: true]
}

config :tymeslot, :calendar_providers, %{
  caldav: [enabled: true],
  radicale: [enabled: true],
  nextcloud: [enabled: true],
  google: [enabled: true],
  outlook: [enabled: true]
}

# Integration locking configuration
config :tymeslot, :integration_locks,
  default_timeout: 90_000,
  google: 60_000,
  outlook: 60_000,
  teams: 120_000
