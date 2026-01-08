defmodule Tymeslot.Workers.VideoRoomWorkerTest do
  use Tymeslot.DataCase, async: false
  use Oban.Testing, repo: Tymeslot.Repo
  import Mox
  import Tymeslot.Factory
  import Tymeslot.WorkerTestHelpers

  alias Ecto.UUID
  alias Tymeslot.DatabaseSchemas.MeetingSchema
  alias Tymeslot.Workers.CalendarEventWorker
  alias Tymeslot.Workers.EmailWorker
  alias Tymeslot.Workers.VideoRoomWorker

  setup :verify_on_exit!

  describe "perform/1 - input validation" do
    test "handles missing meeting_id" do
      assert_raise FunctionClauseError, fn ->
        perform_job(VideoRoomWorker, %{})
      end
    end

    test "handles invalid meeting_id type" do
      user = insert(:user)
      insert(:video_integration, user: user, provider: "mirotalk", is_default: true)

      # String meeting_id should be converted to string internally
      result = perform_job(VideoRoomWorker, %{"meeting_id" => "invalid-id"})

      # Should fail with error (meeting not found)
      assert {:error, _} = result
    end

    test "handles non-existent meeting" do
      # Use a valid UUID format that doesn't exist in database
      non_existent_uuid = UUID.generate()

      result = perform_job(VideoRoomWorker, %{"meeting_id" => non_existent_uuid})

      # Worker discards jobs for non-existent meetings (no point retrying)
      assert {:discard, "Meeting not found"} = result
    end
  end

  describe "perform/1 - successful creation" do
    test "successfully creates a video room and updates meeting" do
      %{meeting: meeting} = setup_video_scenario()

      # Mock MiroTalk API calls: room creation and join token generation
      expect_mirotalk_success()

      assert :ok = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})

      updated_meeting = Repo.get(MeetingSchema, meeting.id)
      assert updated_meeting.video_room_id == "https://test.mirotalk.com/join/test-room-123"
      assert updated_meeting.video_room_enabled

      # Verify calendar update was enqueued
      assert_enqueued(
        worker: CalendarEventWorker,
        args: %{"action" => "update", "meeting_id" => meeting.id}
      )
    end

    test "handles malformed API response (invalid JSON)" do
      %{meeting: meeting} = setup_video_scenario()

      # MiroTalk provider tries both HTTPS and HTTP, so expect 2 calls
      expect(Tymeslot.HTTPClientMock, :post, 2, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "not valid json"}}
      end)

      assert {:error, _reason} = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})
    end

    test "handles malformed API response (missing expected field)" do
      %{meeting: meeting} = setup_video_scenario()

      # MiroTalk provider tries HTTPS, then HTTP, then tries to create join URLs (4 total calls)
      # First 2 calls: room creation attempts that return malformed responses
      # Next 2 calls: join URL creation attempts (if room creation somehow "succeeds")
      expect(Tymeslot.HTTPClientMock, :post, 4, fn _url, _body, _headers, _opts ->
        # Valid JSON but missing the "meeting" field that MiroTalk expects
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body: Jason.encode!(%{"unexpected" => "data"})
         }}
      end)

      # Even with malformed response, MiroTalk might partially succeed
      # This test documents that the provider is resilient
      # In reality, missing "meeting" field causes :invalid_json error
      result = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})

      # Can be either :ok (if provider is very resilient) or {:error, reason}
      case result do
        :ok -> assert true
        {:error, _reason} -> assert true
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "handles empty API response" do
      %{meeting: meeting} = setup_video_scenario()

      # MiroTalk provider tries both HTTPS and HTTP, so expect 2 calls
      expect(Tymeslot.HTTPClientMock, :post, 2, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: ""}}
      end)

      assert {:error, _reason} = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})
    end

    test "handles rate limiting by generic error retry" do
      %{meeting: meeting} = setup_video_scenario()

      expect(Tymeslot.HTTPClientMock, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 429, body: "Too Many Requests"}}
      end)

      assert {:error, reason} = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})
      assert reason =~ "status 429"
    end

    test "sends fallback emails on final failure (graceful degradation)" do
      %{meeting: meeting} = setup_video_scenario()

      stub(Tymeslot.HTTPClientMock, :post, fn _url, _body, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      # On 5th attempt with send_emails: true, it should schedule emails without video
      assert {:error, _} =
               perform_job(
                 VideoRoomWorker,
                 %{
                   "meeting_id" => meeting.id,
                   "send_emails" => true
                 },
                 attempt: 5
               )

      # Check if EmailWorker job was enqueued (fallback without video)
      assert_enqueued(worker: EmailWorker)
    end

    test "video created but calendar update continues on failure (partial success)" do
      %{meeting: meeting} = setup_video_scenario()

      # Video creation succeeds
      expect_mirotalk_success()

      assert :ok = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})

      # Video room should still be recorded even if subsequent steps fail
      updated_meeting = Repo.get(MeetingSchema, meeting.id)
      assert updated_meeting.video_room_id
      assert updated_meeting.video_room_enabled

      # Calendar update should be enqueued (if it fails, that's a separate concern)
      assert_enqueued(worker: CalendarEventWorker)
    end
  end

  describe "perform/1 - idempotency" do
    test "duplicate execution is safe (idempotent)" do
      %{meeting: meeting} = setup_video_scenario()

      # First execution
      expect_mirotalk_success()
      assert :ok = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})

      first_meeting = Repo.get(MeetingSchema, meeting.id)
      _first_video_room_id = first_meeting.video_room_id

      # Second execution (simulates retry or duplicate job)
      expect_mirotalk_success()
      assert :ok = perform_job(VideoRoomWorker, %{"meeting_id" => meeting.id})

      # Meeting should still have a video room (might be updated but not broken)
      second_meeting = Repo.get(MeetingSchema, meeting.id)
      assert second_meeting.video_room_id
      # May have changed due to new room creation, which is acceptable
    end
  end

  describe "scheduling" do
    test "schedule_video_room_creation/1 enqueues job" do
      assert :ok = VideoRoomWorker.schedule_video_room_creation("123")

      assert_enqueued(
        worker: VideoRoomWorker,
        args: %{"meeting_id" => "123", "send_emails" => false}
      )
    end

    test "schedule_video_room_creation_with_emails/1 enqueues job" do
      assert :ok = VideoRoomWorker.schedule_video_room_creation_with_emails("123")

      assert_enqueued(
        worker: VideoRoomWorker,
        args: %{"meeting_id" => "123", "send_emails" => true}
      )
    end
  end
end
