defmodule Tymeslot.Demo.NoOp do
  @moduledoc """
  No-op implementation of demo functionality for core-only deployments.

  All demo checks return false/nil, so core behavior proceeds normally
  without any demo special-casing.
  """
  @behaviour Tymeslot.Demo.Behaviour

  alias Tymeslot.Availability.WeeklySchedule
  alias Tymeslot.DatabaseQueries.UserQueries
  alias Tymeslot.DatabaseQueries.VideoIntegrationQueries
  alias Tymeslot.Integrations.Calendar
  alias Tymeslot.MeetingTypes
  alias Tymeslot.Profiles
  alias Tymeslot.ThemeCustomizations

  @impl true
  def get_profile_by_id(profile_id) when is_integer(profile_id) do
    Profiles.get_profile_by_id(profile_id)
  end

  @impl true
  def get_user_by_id(user_id) when is_integer(user_id) do
    case UserQueries.get_user(user_id) do
      {:ok, user} -> user
      {:error, :not_found} -> nil
    end
  end

  @impl true
  def get_profile_by_user_id(user_id) when is_integer(user_id) do
    Profiles.get_profile(user_id)
  end

  @impl true
  def demo_username?(_username), do: false

  @impl true
  def demo_profile?(_profile), do: false

  @impl true
  def demo_mode?(_socket), do: false

  @impl true
  def get_profile_by_username(username) when is_binary(username) do
    Profiles.get_profile_by_username(username)
  end

  @impl true
  def resolve_organizer_context(username) when is_binary(username) do
    Profiles.resolve_organizer_context(username)
  end

  @impl true
  def resolve_organizer_context_optimized(username) when is_binary(username) do
    Profiles.resolve_organizer_context_optimized(username)
  end

  @impl true
  def get_theme_customization(profile_id, theme_id)
      when is_integer(profile_id) and is_binary(theme_id) do
    ThemeCustomizations.get_by_profile_and_theme(profile_id, theme_id)
  end

  @impl true
  def get_weekly_schedule(profile_id) when is_integer(profile_id) do
    WeeklySchedule.get_weekly_schedule(profile_id)
  end

  @impl true
  def list_active_meeting_types(user_id) when is_integer(user_id) do
    MeetingTypes.get_active_meeting_types(user_id)
  end

  @impl true
  def get_active_video_integration(user_id) when is_integer(user_id) do
    case VideoIntegrationQueries.get_default_for_user(user_id) do
      {:ok, integration} -> integration
      {:error, :not_found} -> nil
    end
  end

  @impl true
  def list_calendar_integrations(user_id) when is_integer(user_id) do
    Calendar.list_integrations(user_id)
  end

  @impl true
  def avatar_url(profile, version \\ :original) do
    Profiles.avatar_url(profile, version)
  end

  @impl true
  def avatar_alt_text(profile) do
    Profiles.avatar_alt_text(profile)
  end

  @impl true
  def find_by_duration_string(user_id, duration_string)
      when is_integer(user_id) and is_binary(duration_string) do
    MeetingTypes.find_by_duration_string(user_id, duration_string)
  end

  @impl true
  def get_orchestrator(_socket), do: Tymeslot.Bookings.Orchestrator

  @impl true
  def get_available_slots(
        _date_string,
        _duration,
        _user_timezone,
        _organizer_user_id,
        _organizer_profile,
        _socket
      ) do
    # NoOp implementation returns empty list; caller should fall back to real logic
    {:ok, []}
  end

  @impl true
  def get_month_availability(
        _user_id,
        _year,
        _month,
        _user_timezone,
        _organizer_profile,
        _socket
      ) do
    # NoOp implementation returns empty map; caller should fall back to real logic
    {:ok, %{}}
  end

  @impl true
  def get_calendar_days(
        _user_timezone,
        _year,
        _month,
        _organizer_profile,
        _availability_map \\ nil
      ) do
    # NoOp implementation returns empty list; caller should fall back to real logic
    []
  end
end
