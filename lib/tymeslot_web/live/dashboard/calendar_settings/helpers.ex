defmodule TymeslotWeb.Dashboard.CalendarSettings.Helpers do
  @moduledoc """
  Helper functions for calendar settings dashboard.
  """
  alias Tymeslot.Integrations.Calendar

  @spec format_provider_name(String.t() | atom()) :: String.t()
  def format_provider_name(provider) do
    Calendar.format_provider_display_name(provider)
  end

  @spec format_token_expiry(map()) :: String.t()
  def format_token_expiry(integration) do
    Calendar.format_token_expiry(integration)
  end

  @spec needs_scope_upgrade?(map()) :: boolean()
  def needs_scope_upgrade?(integration) do
    Calendar.needs_scope_upgrade?(integration)
  end

  @doc """
  Centralized provider metadata for rendering provider cards
  """
  @spec provider_card_info(atom()) :: map()
  def provider_card_info(:google),
    do: %{
      provider: "google",
      click: "connect_google_calendar",
      btn: "Connect Google",
      desc: "Full OAuth integration with Google Meet support"
    }

  def provider_card_info(:outlook),
    do: %{
      provider: "outlook",
      click: "connect_outlook_calendar",
      btn: "Connect Outlook",
      desc: "Microsoft 365 and Outlook.com integration"
    }

  def provider_card_info(:nextcloud),
    do: %{
      provider: "nextcloud",
      click: "connect_nextcloud_calendar",
      btn: "Connect Nextcloud",
      desc: "Self-hosted Nextcloud calendar sync"
    }

  def provider_card_info(:caldav),
    do: %{
      provider: "caldav",
      click: "connect_caldav_calendar",
      btn: "Connect CalDAV",
      desc: "Universal CalDAV server support"
    }

  def provider_card_info(:radicale),
    do: %{
      provider: "radicale",
      click: "connect_radicale_calendar",
      btn: "Connect Radicale",
      desc: "Lightweight self-hosted calendar server"
    }

  def provider_card_info(:demo),
    do: %{provider: "demo", click: nil, btn: "Demo Enabled", desc: "Homepage demo provider"}

  def provider_card_info(type),
    do: %{provider: Atom.to_string(type), click: nil, btn: "Connect", desc: ""}

  @doc """
  Helper to extract a friendly display name from a calendar
  Handles the case where Radicale calendars may have UUIDs as names
  """
  @spec extract_calendar_display_name(map()) :: String.t()
  def extract_calendar_display_name(calendar) do
    Calendar.extract_calendar_display_name(calendar)
  end
end
