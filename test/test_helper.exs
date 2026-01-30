# Configure Swoosh for testing
Application.put_env(:swoosh, :api_client, false)
Application.put_env(:tymeslot, Tymeslot.Mailer, adapter: Swoosh.Adapters.Test)

# Enable test mode to skip sleep calls in workers
Application.put_env(:tymeslot, :test_mode, true)

# Start required applications
Application.ensure_all_started(:tzdata)

# Run migrations before tests
Mix.Task.run("ecto.create", ["--quiet"])
Mix.Task.run("ecto.migrate", ["--quiet"])

# Start PubSub for testing
{:ok, _} =
  Phoenix.PubSub.Supervisor.start_link(name: Tymeslot.TestPubSub, adapter: Phoenix.PubSub.PG2)

# Start Ecto sandbox - ensure Repo is ready first
{:ok, _} = Application.ensure_all_started(:tymeslot)
Ecto.Adapters.SQL.Sandbox.mode(Tymeslot.Repo, :manual)

# Define mocks
Mox.defmock(Tymeslot.CalendarMock,
  for: Tymeslot.Integrations.Calendar.CalendarBehaviour
)

Mox.defmock(Tymeslot.MiroTalkAPIMock,
  for: Tymeslot.Integrations.Video.MiroTalk.MiroTalkClientBehaviour
)

Mox.defmock(Tymeslot.RadicaleClientMock,
  for: Tymeslot.Integrations.Calendar.CalDAV.ClientBehaviour
)

Mox.defmock(Tymeslot.EmailServiceMock, for: Tymeslot.Emails.EmailServiceBehaviour)
Mox.defmock(Tymeslot.HTTPClientMock, for: Tymeslot.Infrastructure.HTTPClientBehaviour)

Mox.defmock(Tymeslot.GoogleOAuthHelperMock,
  for: Tymeslot.Integrations.Calendar.Auth.OAuthHelperBehaviour
)

Mox.defmock(Tymeslot.OutlookOAuthHelperMock,
  for: Tymeslot.Integrations.Calendar.Auth.OAuthHelperBehaviour
)

Mox.defmock(Tymeslot.TeamsOAuthHelperMock,
  for: Tymeslot.Integrations.Video.Teams.TeamsOAuthHelperBehaviour
)

Mox.defmock(GoogleCalendarAPIMock,
  for: Tymeslot.Integrations.Calendar.Google.CalendarAPIBehaviour
)

Mox.defmock(OutlookCalendarAPIMock,
  for: Tymeslot.Integrations.Calendar.Outlook.CalendarAPIBehaviour
)

Mox.defmock(Tymeslot.Payments.StripeMock,
  for: Tymeslot.Payments.Behaviours.StripeProvider
)

Mox.defmock(Tymeslot.Payments.SubscriptionManagerMock,
  for: Tymeslot.Payments.Behaviours.SubscriptionManager
)

Mox.defmock(Tymeslot.Auth.OAuth.ClientMock,
  for: Tymeslot.Auth.OAuth.ClientBehaviour
)

Mox.defmock(Tymeslot.Auth.OAuth.HelperMock,
  for: Tymeslot.Auth.OAuth.HelperBehaviour
)

Mox.defmock(Tymeslot.Auth.SessionMock,
  for: Tymeslot.Infrastructure.SessionBehaviour
)

# Stripe internal mocks for testing the wrapper
# We use the behaviours defined in Tymeslot.TestMocks
alias Tymeslot.TestMocks.{
  StripeCustomerBehaviour,
  StripeSessionBehaviour,
  StripeSubscriptionBehaviour,
  StripeChargeBehaviour,
  StripeWebhookBehaviour
}

Mox.defmock(StripeCustomerMock, for: StripeCustomerBehaviour)
Mox.defmock(StripeSessionMock, for: StripeSessionBehaviour)
Mox.defmock(StripeSubscriptionMock, for: StripeSubscriptionBehaviour)
Mox.defmock(StripeChargeMock, for: StripeChargeBehaviour)
Mox.defmock(StripeWebhookMock, for: StripeWebhookBehaviour)

max_cases =
  case System.get_env("TEST_MAX_CASES") do
    nil ->
      config = Application.get_env(:tymeslot, Tymeslot.Repo, [])
      pool_size = Keyword.get(config, :pool_size, 10)

      # Use at most half the pool size to leave headroom for sandbox overhead,
      # migrations, and multi-repo access patterns. Minimum of 2 for parallelism.
      max(div(pool_size, 2), 2)

    value ->
      case Integer.parse(value) do
        {int, _} -> int
        :error -> nil
      end
  end

ExUnit.start(exclude: [:backup_tests, :oauth_integration, :calendar_integration])

# Configure ExUnit to exclude backup tests, OAuth integration tests, and calendar
# integration tests by default. Integration tests now run by default.
exunit_config = [
  exclude: [
    backup_tests: true,
    oauth_integration: true,
    calendar_integration: true
  ]
]

exunit_config =
  if max_cases do
    Keyword.put(exunit_config, :max_cases, max_cases)
  else
    exunit_config
  end

ExUnit.configure(exunit_config)

# Helper functions for tests
defmodule Tymeslot.TestHelpers do
  @moduledoc """
  Test helper functions and utilities
  """

  @spec sample_appointment_data() :: map()
  def sample_appointment_data do
    %{
      uid: "test-appointment-123",
      organizer_name: "Luka Breitig",
      organizer_email: "luka@example.com",
      organizer_title: "CEO",
      attendee_name: "Jane Doe",
      attendee_email: "jane@example.com",
      attendee_phone: "+1-555-123-4567",
      attendee_company: "Test Company",
      attendee_message: "Looking forward to our discussion about the project.",
      date: ~D[2024-02-15],
      start_time: ~U[2024-02-15 14:00:00Z],
      end_time: ~U[2024-02-15 15:00:00Z],
      start_time_owner_tz: ~U[2024-02-15 16:00:00Z],
      end_time_owner_tz: ~U[2024-02-15 17:00:00Z],
      attendee_timezone: "America/New_York",
      start_time_attendee_tz: ~U[2024-02-15 09:00:00Z],
      end_time_attendee_tz: ~U[2024-02-15 10:00:00Z],
      duration: 60,
      location: "Conference Room A",
      location_details: "Conference Room A - 2nd Floor",
      meeting_type: "Project Discussion",
      meeting_url: "https://app.example.com/appointments/123/join",
      what_to_expect: "We'll discuss project goals and timeline.",
      preparation_notes: "Please bring project documents.",
      preparation_reminder: "Don't forget to review the agenda!",
      default_reminder_time: "15 minutes",
      custom_checklist: ["Review agenda", "Prepare questions"],
      what_to_bring: ["Project documents", "Laptop"],
      organizer_contact_info: "Phone: +1-555-000-0000",
      contact_info: "For questions, call +1-555-000-0000",
      allow_contact: true,
      reminder_time: "15 minutes",
      time_until_friendly: "fifteen minutes",
      view_url: "https://app.example.com/appointments/123",
      reschedule_url: "https://app.example.com/appointments/123/reschedule",
      cancel_url: "https://app.example.com/appointments/123/cancel"
    }
  end
end
