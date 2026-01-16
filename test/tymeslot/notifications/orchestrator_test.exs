defmodule Tymeslot.Notifications.OrchestratorTest do
  use Tymeslot.DataCase, async: true
  use Oban.Testing, repo: Tymeslot.Repo

  import Tymeslot.Factory

  alias Tymeslot.Notifications.Orchestrator
  alias Tymeslot.Workers.EmailWorker

  describe "schedule_reminder_notifications/1" do
    test "schedules a job for each reminder interval" do
      meeting =
        insert(:meeting,
          start_time: DateTime.add(DateTime.utc_now(), 2, :hour),
          reminders: [
            %{"value" => 30, "unit" => "minutes"},
            %{"value" => 1, "unit" => "hours"}
          ]
        )

      assert :ok = Orchestrator.schedule_reminder_notifications(meeting)

      assert_enqueued(
        worker: EmailWorker,
        args: %{
          "action" => "send_reminder_emails",
          "meeting_id" => meeting.id,
          "reminder_value" => 30,
          "reminder_unit" => "minutes"
        }
      )

      assert_enqueued(
        worker: EmailWorker,
        args: %{
          "action" => "send_reminder_emails",
          "meeting_id" => meeting.id,
          "reminder_value" => 1,
          "reminder_unit" => "hours"
        }
      )

      assert length(all_enqueued(worker: EmailWorker)) == 2
    end

    test "schedules reminders at the correct absolute time" do
      start_time = ~U[2026-01-20 12:00:00Z]

      meeting =
        insert(:meeting,
          start_time: start_time,
          reminders: [%{value: 1, unit: "hours"}]
        )

      Orchestrator.schedule_reminder_notifications(meeting)

      # Assert the job is scheduled exactly 1 hour before start_time
      expected_time = ~U[2026-01-20 11:00:00Z]

      assert_enqueued(
        worker: EmailWorker,
        scheduled_at: expected_time,
        args: %{
          "action" => "send_reminder_emails",
          "meeting_id" => meeting.id,
          "reminder_value" => 1,
          "reminder_unit" => "hours"
        }
      )
    end

    test "does not schedule reminders when list is empty" do
      meeting =
        insert(:meeting,
          start_time: DateTime.add(DateTime.utc_now(), 2, :hour),
          reminders: []
        )

      assert {:ok, :reminder_not_scheduled} = Orchestrator.schedule_reminder_notifications(meeting)
      assert all_enqueued(worker: EmailWorker) == []
    end
  end
end
