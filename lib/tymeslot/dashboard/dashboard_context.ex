defmodule Tymeslot.Dashboard.DashboardContext do
  @moduledoc """
  Context module for dashboard business logic.
  Extracted from dashboard_live.ex to improve separation of concerns.
  """

  alias Tymeslot.DatabaseQueries.MeetingTypeQueries
  alias Tymeslot.DatabaseQueries.VideoIntegrationQueries
  alias Tymeslot.Infrastructure.DashboardCache
  alias Tymeslot.Integrations.CalendarManagement
  alias Tymeslot.MeetingTypes

  @doc """
  Gets just the integration status for a user (lighter query for sidebar notifications).
  """
  @spec get_integration_status(integer()) :: %{
          has_calendar: boolean(),
          has_video: boolean(),
          has_meeting_types: boolean(),
          calendar_count: non_neg_integer(),
          video_count: non_neg_integer(),
          meeting_types_count: non_neg_integer()
        }
  def get_integration_status(user_id) when is_integer(user_id) do
    # Use cache for integration status
    DashboardCache.get_or_compute(
      DashboardCache.integration_status_key(user_id),
      fn ->
        # Check integration status
        # Use only active integrations for status
        calendar_integrations = CalendarManagement.list_active_calendar_integrations(user_id)
        video_integrations = VideoIntegrationQueries.list_active_for_user(user_id)
        meeting_types = MeetingTypeQueries.list_active_meeting_types(user_id)

        %{
          has_calendar: length(calendar_integrations) > 0,
          has_video: length(video_integrations) > 0,
          has_meeting_types: length(meeting_types) > 0,
          calendar_count: length(calendar_integrations),
          video_count: length(video_integrations),
          meeting_types_count: length(meeting_types)
        }
      end,
      # Cache for 5 minutes since integrations don't change often
      :timer.minutes(5)
    )
  end

  @spec get_integration_status(nil | any()) :: %{
          has_calendar: boolean(),
          has_video: boolean(),
          has_meeting_types: boolean(),
          calendar_count: non_neg_integer(),
          video_count: non_neg_integer(),
          meeting_types_count: non_neg_integer()
        }
  def get_integration_status(_user_id) do
    # Mock data for development when user_id is nil
    %{
      has_calendar: false,
      has_video: false,
      has_meeting_types: false,
      calendar_count: 0,
      video_count: 0,
      meeting_types_count: 0
    }
  end

  @doc """
  Invalidates the cached integration status for a user.
  """
  @spec invalidate_integration_status(integer()) :: :ok
  def invalidate_integration_status(user_id) do
    DashboardCache.invalidate(DashboardCache.integration_status_key(user_id))
    :ok
  end

  @doc """
  Gather meeting settings data for a user (meeting types and video integrations).
  """
  @spec get_meeting_settings_data(integer()) :: %{
          meeting_types: list(),
          video_integrations: list(),
          calendar_integrations: list()
        }
  def get_meeting_settings_data(user_id) when is_integer(user_id) do
    %{
      meeting_types: MeetingTypes.get_all_meeting_types(user_id),
      video_integrations: VideoIntegrationQueries.list_active_for_user_public(user_id),
      calendar_integrations: CalendarManagement.list_active_calendar_integrations(user_id)
    }
  end

  @spec get_meeting_settings_data(nil | any()) :: %{
          meeting_types: list(),
          video_integrations: list(),
          calendar_integrations: list()
        }
  def get_meeting_settings_data(_user_id),
    do: %{meeting_types: [], video_integrations: [], calendar_integrations: []}
end
