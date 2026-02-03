import Config

# Helper to safely parse integers from environment variables
parse_int = fn var, default ->
  case System.get_env(var) do
    nil ->
      default

    value ->
      case Integer.parse(value) do
        {int, _} -> int
        :error -> default
      end
  end
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/tymeslot start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :tymeslot, TymeslotWeb.Endpoint, server: true
end

if config_env() == :prod do
  # Set environment for runtime detection
  config :tymeslot, :environment, :prod

  # Database configuration based on deployment type (define early as it's used for URL scheme)
  # Defaults to "docker" if DEPLOYMENT_TYPE is not set or unknown
  deployment_type =
    case System.get_env("DEPLOYMENT_TYPE") do
      "cloudron" -> "cloudron"
      _ -> "docker"
    end

  # Configure upload directory for production
  config :tymeslot, :upload_directory, "/app/data/uploads"
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST")
  port = String.to_integer(System.get_env("PORT") || "4000")

  # Allowed origins for LiveView WebSocket (align with CSP 'connect-src' and site origin)
  allowed_origins =
    case System.get_env("WS_ALLOWED_ORIGINS") do
      nil ->
        [
          "https://#{host}",
          "http://#{host}",
          "http://localhost:4000",
          "https://localhost:4000"
        ]

      list ->
        list
        |> String.split(",")
        |> Enum.map(&String.trim/1)
    end

  config :tymeslot, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Determine the URL scheme based on deployment type
  url_scheme =
    case deployment_type do
      "cloudron" -> "https"
      "docker" -> "http"
    end

  # For Cloudron, use port 80 internally (reverse proxy is on 443)
  # For Docker, use standard HTTP port
  url_port =
    case deployment_type do
      "cloudron" -> 80
      "docker" -> parse_int.("PORT", 4000)
    end

  config :tymeslot, TymeslotWeb.Endpoint,
    url: [host: host, port: url_port, scheme: url_scheme],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base,
    check_origin: allowed_origins

  # Database configuration helper
  get_database_config = fn deployment_type, overrides ->
    base_config =
      case deployment_type do
        "cloudron" ->
          [
            url: System.get_env("CLOUDRON_POSTGRESQL_URL"),
            username: System.get_env("CLOUDRON_POSTGRESQL_USERNAME"),
            password: System.get_env("CLOUDRON_POSTGRESQL_PASSWORD"),
            hostname: System.get_env("CLOUDRON_POSTGRESQL_HOST"),
            port: System.get_env("CLOUDRON_POSTGRESQL_PORT"),
            database: System.get_env("CLOUDRON_POSTGRESQL_DATABASE"),
            pool_size: parse_int.("DATABASE_POOL_SIZE", 100),
            idle_interval: 60_000,
            queue_target: 5000,
            queue_interval: 10000
          ]

        "docker" ->
          # The embedded Postgres in Docker uses the default max_connections=100.
          # Keep the default pool size low to avoid exhausting connections during boot.
          [
            hostname: System.get_env("DATABASE_HOST", "localhost"),
            port: parse_int.("DATABASE_PORT", 5432),
            database: System.get_env("POSTGRES_DB", "tymeslot"),
            username: System.get_env("POSTGRES_USER", "tymeslot"),
            password:
              System.get_env("POSTGRES_PASSWORD") ||
                raise("POSTGRES_PASSWORD environment variable is missing"),
            pool_size: parse_int.("DATABASE_POOL_SIZE", 10),
            idle_interval: 60_000,
            queue_target: 5000,
            queue_interval: 10000
          ]
      end

    Keyword.merge(base_config, overrides)
  end

  config :tymeslot, Tymeslot.Repo, get_database_config.(deployment_type, [])

  # Remote IP handling: trust private/loopback proxies and read proxy headers
  # Cloudron uses x-forwarded-for header from its reverse proxy
  config :remote_ip, RemoteIp,
    headers: ~w[x-forwarded-for x-real-ip],
    proxies: ~w[
      127.0.0.0/8
      10.0.0.0/8
      172.16.0.0/12
      192.168.0.0/16
      ::1/128
      fc00::/7
      fd00::/8
    ]

  # Configure Oban for production
  config :tymeslot, Oban,
    repo: Tymeslot.Repo,
    plugins: [
      Oban.Plugins.Pruner,
      {Oban.Plugins.Cron,
       crontab: [
         # Run daily at 02:45 UTC for video room recovery scan
         {"45 2 * * *", Tymeslot.Workers.VideoRoomRecoveryScanWorker},
         # Run daily at 03:15 UTC
         {"15 3 * * *", Tymeslot.Workers.ExpiredSessionCleanupWorker},
         # Run daily at 04:00 UTC for webhook cleanup
         {"0 4 * * *", Tymeslot.Workers.WebhookCleanupWorker, args: %{retention_days: 60}}
       ]}
    ],
    queues: Application.get_env(:tymeslot, :oban_queues, [])

  # Configure tzdata to use writable directory in production
  tzdata_dir = "/app/data/tzdata"

  config :tzdata, :data_dir, tzdata_dir

  # Configure mailer based on EMAIL_ADAPTER setting
  # Default to smtp for self-hosted deployments
  # Can be overridden with EMAIL_ADAPTER environment variable
  email_adapter_default = Application.get_env(:tymeslot, :email_adapter_default, "smtp")
  email_adapter = System.get_env("EMAIL_ADAPTER", email_adapter_default)

  mailer_config =
    case email_adapter do
      "smtp" ->
        [
          adapter: Swoosh.Adapters.SMTP,
          relay: System.get_env("SMTP_HOST"),
          port: parse_int.("SMTP_PORT", 587),
          username: System.get_env("SMTP_USERNAME"),
          password: System.get_env("SMTP_PASSWORD"),
          tls: :if_available,
          auth: :if_available
        ]

      "postmark" ->
        [
          adapter: Swoosh.Adapters.Postmark,
          api_key: System.get_env("POSTMARK_API_KEY")
        ]

      "test" ->
        [
          adapter: Swoosh.Adapters.Test
        ]

      "local" ->
        # Local adapter only works in dev, fallback to test in production
        [
          adapter: Swoosh.Adapters.Test
        ]

      _ ->
        [
          adapter: Swoosh.Adapters.Test
        ]
    end

  config :tymeslot, Tymeslot.Mailer, mailer_config
end

# Configure mailer for non-production environments
if config_env() != :prod do
  # Default to smtp for self-hosted deployments
  email_adapter_default = Application.get_env(:tymeslot, :email_adapter_default, "smtp")
  email_adapter = System.get_env("EMAIL_ADAPTER", email_adapter_default)

  mailer_config =
    case email_adapter do
      "smtp" ->
        if System.get_env("SMTP_HOST") do
          [
            adapter: Swoosh.Adapters.SMTP,
            relay: System.get_env("SMTP_HOST"),
            port: parse_int.("SMTP_PORT", 587),
            username: System.get_env("SMTP_USERNAME"),
            password: System.get_env("SMTP_PASSWORD"),
            tls: :if_available,
            auth: :if_available
          ]
        else
          [adapter: Swoosh.Adapters.Local]
        end

      "postmark" ->
        if System.get_env("POSTMARK_API_KEY") do
          [
            adapter: Swoosh.Adapters.Postmark,
            api_key: System.get_env("POSTMARK_API_KEY")
          ]
        else
          [adapter: Swoosh.Adapters.Local]
        end

      _ ->
        if System.get_env("POSTMARK_API_KEY") do
          [
            adapter: Swoosh.Adapters.Postmark,
            api_key: System.get_env("POSTMARK_API_KEY")
          ]
        else
          [adapter: Swoosh.Adapters.Local]
        end
    end

  config :tymeslot, Tymeslot.Mailer, mailer_config
end

# Configure email settings
from_email =
  System.get_env("EMAIL_FROM_ADDRESS") ||
    if config_env() == :prod,
      do: raise("environment variable EMAIL_FROM_ADDRESS is missing"),
      else: "hello@tymeslot.app"

from_name =
  System.get_env("EMAIL_FROM_NAME") ||
    if config_env() == :prod,
      do: raise("environment variable EMAIL_FROM_NAME is missing"),
      else: "Tymeslot"

phx_host =
  System.get_env("PHX_HOST") ||
    if config_env() == :prod,
      do: raise("environment variable PHX_HOST is missing"),
      else: "tymeslot.app"

config :tymeslot, :email,
  from_name: from_name,
  from_email: from_email,
  support_email: System.get_env("EMAIL_SUPPORT_ADDRESS") || from_email,
  contact_recipient: System.get_env("EMAIL_CONTACT_RECIPIENT") || from_email,
  domain: phx_host

# Stripe Payment Configuration
if config_env() == :prod do
  stripe_secret_key =
    System.get_env("STRIPE_SECRET_KEY") ||
      raise("STRIPE_SECRET_KEY environment variable is missing")

  config :stripity_stripe,
    api_key: stripe_secret_key

  # Stripe webhook secret (optional for development, required for production)
  stripe_webhook_secret = System.get_env("STRIPE_WEBHOOK_SECRET")

  if stripe_webhook_secret do
    config :tymeslot, :stripe_webhook_secret, stripe_webhook_secret
  else
    IO.warn("STRIPE_WEBHOOK_SECRET not set - webhook signature verification disabled")
  end

  # Trial period configuration (default 7 days)
  config :tymeslot, :trial_period_days, parse_int.("TRIAL_PERIOD_DAYS", 7)
end

# Development/test environment Stripe configuration
if config_env() in [:dev, :test] do
  config :stripity_stripe,
    api_key: System.get_env("STRIPE_SECRET_KEY", "sk_test_fake")

  config :tymeslot, :stripe_webhook_secret, System.get_env("STRIPE_WEBHOOK_SECRET")

  # Trial period configuration (default 7 days)
  config :tymeslot, :trial_period_days, parse_int.("TRIAL_PERIOD_DAYS", 7)
end

# Social Authentication Configuration
# These environment variables control whether social login is enabled
config :tymeslot, :social_auth,
  google_enabled: System.get_env("ENABLE_GOOGLE_AUTH", "false") == "true",
  github_enabled: System.get_env("ENABLE_GITHUB_AUTH", "false") == "true"

# reCAPTCHA configuration (runtime)
# Signup protection is configurable and will automatically disable itself if keys are missing.
# RECAPTCHA_SIGNUP_ENABLED is read directly by signup_enabled?() for runtime toggling support
# (useful for emergency disables during Google API outages without redeployment).

recaptcha_signup_min_score =
  case Float.parse(System.get_env("RECAPTCHA_SIGNUP_MIN_SCORE", "0.3")) do
    {score, _} -> score
    :error -> 0.3
  end

recaptcha_signup_action = System.get_env("RECAPTCHA_SIGNUP_ACTION", "signup_form")

recaptcha_expected_hostnames =
  System.get_env("RECAPTCHA_EXPECTED_HOSTNAMES", "")
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))

config :tymeslot, :recaptcha,
  signup_min_score: recaptcha_signup_min_score,
  signup_action: recaptcha_signup_action,
  expected_hostnames: recaptcha_expected_hostnames
