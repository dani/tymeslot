defmodule Tymeslot.Integrations.Calendar.CalendarBehaviour do
  @moduledoc """
  Behaviour for calendar operations to enable testing with mocks.
  """

  alias Tymeslot.DatabaseSchemas.MeetingSchema
  alias Tymeslot.DatabaseSchemas.MeetingTypeSchema

  @callback list_events_in_range(DateTime.t(), DateTime.t()) :: {:ok, list()} | {:error, any()}
  @callback get_events_for_range_fresh(pos_integer(), Date.t(), Date.t()) ::
              {:ok, list()} | {:error, any()}
  @callback get_events_for_month(pos_integer(), pos_integer(), pos_integer(), String.t()) ::
              {:ok, list()} | {:error, any()}
  @callback get_event(binary()) :: {:ok, any()} | {:error, any()}
  @callback create_event(map(), pos_integer() | MeetingSchema.t() | MeetingTypeSchema.t() | nil) ::
              {:ok, any()} | {:error, any()}
  @callback update_event(binary(), map(), pos_integer() | MeetingSchema.t() | nil) ::
              {:ok, any()} | {:error, any()}
  @callback delete_event(binary(), pos_integer() | MeetingSchema.t() | nil) ::
              {:ok, any()} | {:error, any()}
  @callback get_booking_integration_info(pos_integer() | MeetingTypeSchema.t()) ::
              {:ok, map()} | {:error, any()}
end
