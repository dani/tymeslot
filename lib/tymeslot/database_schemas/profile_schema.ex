defmodule Tymeslot.DatabaseSchemas.ProfileSchema do
  @moduledoc """
  Schema for user profiles containing calendar and appointment settings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.DatabaseSchemas.ThemeCustomizationSchema
  alias Tymeslot.Security.UniversalSanitizer
  alias Tymeslot.Utils.TimezoneUtils
  alias TymeslotWeb.Themes.Core.Registry

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          username: String.t() | nil,
          full_name: String.t() | nil,
          timezone: String.t(),
          buffer_minutes: integer(),
          advance_booking_days: integer(),
          min_advance_hours: integer(),
          avatar: String.t() | nil,
          booking_theme: String.t() | nil,
          has_custom_theme: boolean(),
          allowed_embed_domains: [String.t()] | nil,
          primary_calendar_integration_id: integer() | nil,
          user: Tymeslot.DatabaseSchemas.UserSchema.t() | Ecto.Association.NotLoaded.t(),
          primary_calendar_integration:
            Tymeslot.DatabaseSchemas.CalendarIntegrationSchema.t()
            | Ecto.Association.NotLoaded.t()
            | nil,
          theme_customization:
            ThemeCustomizationSchema.t() | Ecto.Association.NotLoaded.t() | nil,
          meeting_types: [Tymeslot.DatabaseSchemas.MeetingTypeSchema.t()] | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "profiles" do
    field(:username, :string)
    field(:full_name, :string)
    field(:timezone, :string, default: "Europe/Kyiv")
    field(:buffer_minutes, :integer, default: 15)
    field(:advance_booking_days, :integer, default: 90)
    field(:min_advance_hours, :integer, default: 3)
    field(:avatar, :string)
    field(:booking_theme, :string, default: Registry.default_theme_id())
    field(:has_custom_theme, :boolean, default: false)
    field(:allowed_embed_domains, {:array, :string}, default: [])
    field(:meeting_types, {:array, :map}, virtual: true)
    belongs_to(:user, Tymeslot.DatabaseSchemas.UserSchema)
    belongs_to(:primary_calendar_integration, Tymeslot.DatabaseSchemas.CalendarIntegrationSchema)
    has_one(:theme_customization, ThemeCustomizationSchema, foreign_key: :profile_id)

    timestamps()
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [
      :user_id,
      :username,
      :full_name,
      :timezone,
      :buffer_minutes,
      :advance_booking_days,
      :min_advance_hours,
      :avatar,
      :booking_theme,
      :has_custom_theme,
      :allowed_embed_domains,
      :primary_calendar_integration_id
    ])
    |> validate_required([:user_id, :timezone])
    |> validate_username()
    |> validate_timezone()
    |> validate_booking_theme()
    |> validate_embed_domains()
    |> validate_number(:buffer_minutes, greater_than_or_equal_to: 0, less_than_or_equal_to: 120)
    |> validate_number(:advance_booking_days,
      greater_than_or_equal_to: 1,
      less_than_or_equal_to: 365
    )
    |> validate_number(:min_advance_hours,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 168
    )
    |> unique_constraint(:username)
  end

  defp validate_username(changeset) do
    changeset
    |> validate_format(:username, ~r/^[a-z0-9][a-z0-9_-]{2,29}$/,
      message:
        "must be 3-30 characters long, start with a letter or number, and contain only lowercase letters, numbers, underscores, and hyphens"
    )
    |> validate_length(:username, min: 3, max: 30)
    |> validate_username_not_reserved()
  end

  defp validate_username_not_reserved(changeset) do
    reserved_usernames = [
      "admin",
      "api",
      "app",
      "auth",
      "blog",
      "dashboard",
      "dev",
      "docs",
      "help",
      "home",
      "login",
      "logout",
      "meeting",
      "meetings",
      "profile",
      "register",
      "schedule",
      "settings",
      "signup",
      "static",
      "support",
      "test",
      "user",
      "users",
      "www",
      "healthcheck",
      "assets",
      "images",
      "css",
      "js",
      "fonts",
      "about",
      "contact",
      "privacy",
      "terms"
    ]

    case get_change(changeset, :username) do
      nil ->
        changeset

      username ->
        if username in reserved_usernames do
          add_error(changeset, :username, "is reserved")
        else
          changeset
        end
    end
  end

  defp validate_timezone(changeset) do
    case get_change(changeset, :timezone) do
      nil ->
        changeset

      timezone ->
        # Check if timezone is in our list of valid options
        valid_timezones =
          Enum.map(TimezoneUtils.get_all_timezone_options(), fn {_label, value} -> value end)

        if timezone in valid_timezones do
          changeset
        else
          add_error(changeset, :timezone, "is not a valid timezone")
        end
    end
  end

  defp validate_booking_theme(changeset) do
    valid_theme_ids = Registry.valid_theme_ids()

    validate_inclusion(changeset, :booking_theme, valid_theme_ids,
      message: "must be a valid theme"
    )
  end

  defp validate_embed_domains(changeset) do
    case get_change(changeset, :allowed_embed_domains) do
      nil ->
        changeset

      domains when is_list(domains) ->
        do_validate_embed_domains(changeset, domains)

      _ ->
        add_error(changeset, :allowed_embed_domains, "must be a list of domains")
    end
  end

  defp do_validate_embed_domains(changeset, domains) do
    max_domains = 20

    if length(domains) > max_domains do
      add_error(
        changeset,
        :allowed_embed_domains,
        "cannot have more than #{max_domains} domains (currently #{length(domains)})"
      )
    else
      {invalid_domains, too_long_domains} = validate_domain_list(domains)
      add_domain_errors(changeset, invalid_domains, too_long_domains)
    end
  end

  defp validate_domain_list(domains) do
    Enum.reduce(domains, {[], []}, fn domain, {invalid_acc, too_long_acc} ->
      case validate_single_domain(domain) do
        :ok -> {invalid_acc, too_long_acc}
        :too_long -> {invalid_acc, [domain | too_long_acc]}
        :invalid -> {[domain | invalid_acc], too_long_acc}
      end
    end)
  end

  defp validate_single_domain(domain) do
    if byte_size(domain) > 255 do
      :too_long
    else
      case UniversalSanitizer.sanitize_and_validate(domain,
             allow_html: false,
             max_length: 255,
             on_too_long: :error,
             log_events: false
           ) do
        {:ok, sanitized_domain} ->
          if valid_domain?(sanitized_domain), do: :ok, else: :invalid

        {:error, _} ->
          :invalid
      end
    end
  end

  defp add_domain_errors(changeset, invalid_domains, too_long_domains) do
    cond do
      too_long_domains != [] ->
        add_error(
          changeset,
          :allowed_embed_domains,
          "domains exceed maximum length of 255 characters: #{format_error_list(too_long_domains)}"
        )

      invalid_domains != [] ->
        add_error(
          changeset,
          :allowed_embed_domains,
          "contains invalid domains: #{format_error_list(invalid_domains)}"
        )

      true ->
        changeset
    end
  end

  defp format_error_list(list) do
    "#{Enum.join(Enum.take(list, 3), ", ")}#{if length(list) > 3, do: "...", else: ""}"
  end

  # Validates a single domain format
  # Accepts: example.com, subdomain.example.com, localhost (for dev)
  # Rejects: https://, paths, ports, wildcards
  # Note: Unicode/emoji domains are sanitized before validation, so this only needs to validate ASCII
  defp valid_domain?(domain) when is_binary(domain) do
    domain = String.trim(domain)

    # Basic validations
    cond do
      domain == "" ->
        false

      # Reject URLs with protocols, paths, query strings, or fragments
      String.contains?(domain, ["://", "/", "?", "#", "@"]) ->
        false

      # Reject domains with ports
      String.match?(domain, ~r/:\d+$/) ->
        false

      # Allow localhost for development
      domain == "localhost" ->
        true

      # Standard domain validation (ASCII only after sanitization)
      # Each label must be 1-63 chars, can contain letters, numbers, hyphens (not at start/end)
      # Domain must have at least one dot (unless localhost)
      true ->
        labels = String.split(domain, ".")

        length(labels) >= 2 and
          Enum.all?(labels, fn label ->
            # Standard label validation
            byte_size(label) > 0 and
              byte_size(label) <= 63 and
              String.match?(label, ~r/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i)
          end)
    end
  end

  defp valid_domain?(_), do: false
end
