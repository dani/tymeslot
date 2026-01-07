defmodule Tymeslot.Workers.WebhookWorker do
  @moduledoc """
  Oban worker for delivering webhook notifications.

  Handles:
  - HTTP POST delivery with timeout protection
  - HMAC signature generation
  - Exponential backoff retry logic
  - Circuit breaker (auto-disable after consecutive failures)
  - Delivery logging and metrics
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    priority: 2

  require Logger

  alias Tymeslot.DatabaseQueries.{MeetingQueries, WebhookQueries}
  alias Tymeslot.DatabaseSchemas.WebhookSchema
  alias Tymeslot.Webhooks.{PayloadBuilder, Security}

  # 10 second timeout for webhook delivery
  @delivery_timeout_ms 10_000

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"webhook_id" => webhook_id, "event_type" => event_type, "meeting_id" => meeting_id},
        attempt: attempt
      }) do
    with {:ok, webhook} <- WebhookQueries.get_webhook(webhook_id),
         {:ok, meeting} <- MeetingQueries.get_meeting(meeting_id),
         {:ok, _delivery} <- deliver_webhook(webhook, event_type, meeting, attempt) do
      # Record success
      WebhookQueries.record_success(webhook, DateTime.utc_now())
      :ok
    else
      {:error, :not_found} ->
        Logger.warning("Webhook or meeting not found",
          webhook_id: webhook_id,
          meeting_id: meeting_id
        )

        {:discard, "Webhook or meeting not found"}

      {:error, :disabled} ->
        Logger.info("Webhook is disabled, discarding job", webhook_id: webhook_id)
        {:discard, "Webhook is disabled"}

      {:error, reason} = error ->
        Logger.warning("Webhook delivery failed",
          webhook_id: webhook_id,
          event_type: event_type,
          attempt: attempt,
          reason: inspect(reason)
        )

        # Record failure and check if we should retry
        case WebhookQueries.get_webhook(webhook_id) do
          {:ok, webhook} ->
            WebhookQueries.record_failure(webhook, inspect(reason))

          _ ->
            :ok
        end

        error
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error("WebhookWorker job missing required parameters",
      args: inspect(args)
    )

    {:discard, "Missing required parameters"}
  end

  @doc """
  Schedules a webhook delivery via Oban.
  """
  @spec schedule_delivery(integer(), String.t(), binary()) :: :ok | {:error, term()}
  def schedule_delivery(webhook_id, event_type, meeting_id) do
    result =
      %{
        "webhook_id" => webhook_id,
        "event_type" => event_type,
        "meeting_id" => meeting_id
      }
      |> new(
        queue: :webhooks,
        priority: 2,
        unique: [
          # 5 minute uniqueness window
          period: 300,
          fields: [:args],
          keys: [:webhook_id, :event_type, :meeting_id]
        ]
      )
      |> Oban.insert()

    case result do
      {:ok, _job} ->
        Logger.debug("Webhook delivery job scheduled",
          webhook_id: webhook_id,
          event_type: event_type
        )

        :ok

      {:error, %Ecto.Changeset{errors: [unique: _]}} ->
        Logger.debug("Webhook delivery job already exists",
          webhook_id: webhook_id,
          event_type: event_type
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to schedule webhook delivery",
          webhook_id: webhook_id,
          event_type: event_type,
          reason: inspect(reason)
        )

        {:error, reason}
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 1s, 2s, 4s, 8s, 16s
    min(round(:math.pow(2, attempt - 1)), 16)
  end

  # Private functions

  defp deliver_webhook(%WebhookSchema{} = webhook, event_type, meeting, attempt) do
    # Check if webhook is still active
    if not WebhookSchema.should_be_active?(webhook) do
      {:error, :disabled}
    else
      # Decrypt secret if present
      webhook = WebhookSchema.decrypt_secret(webhook)

      # Build payload
      payload = PayloadBuilder.build_payload(event_type, meeting, to_string(webhook.id))

      # Create delivery log entry
      {:ok, delivery} =
        WebhookQueries.create_delivery(%{
          webhook_id: webhook.id,
          event_type: event_type,
          meeting_id: meeting.id,
          payload: payload,
          attempt_count: attempt
        })

      # Send HTTP request
      result = send_webhook_request(webhook.url, payload, webhook.secret)

      # Update delivery log with result
      update_delivery_with_result(delivery, result)
    end
  end

  defp send_webhook_request(url, payload, secret) do
    headers = build_headers(payload, secret)
    body = Jason.encode!(payload)

    task = Task.async(fn -> http_client().post(url, body, headers, recv_timeout: @delivery_timeout_ms) end)

    case Task.yield(task, @delivery_timeout_ms + 1000) || Task.shutdown(task) do
      {:ok, {:ok, %{status_code: status, body: response_body}}} ->
        {:ok, status, response_body}

      {:ok, {:error, %{reason: reason}}} ->
        {:error, inspect(reason)}

      {:ok, {:error, reason}} ->
        {:error, inspect(reason)}

      nil ->
        {:error, "Request timed out after #{@delivery_timeout_ms}ms"}
    end
  end

  defp build_headers(_payload, nil) do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "Tymeslot-Webhooks/1.0"}
    ]
  end

  defp build_headers(payload, secret) when is_binary(secret) and secret != "" do
    signature = Security.generate_signature(payload, secret)

    [
      {"Content-Type", "application/json"},
      {"User-Agent", "Tymeslot-Webhooks/1.0"},
      {"X-Tymeslot-Signature", signature},
      {"X-Tymeslot-Timestamp", DateTime.utc_now() |> DateTime.to_iso8601()}
    ]
  end

  defp build_headers(payload, _), do: build_headers(payload, nil)

  defp update_delivery_with_result(delivery, {:ok, status, response_body}) do
    WebhookQueries.update_delivery(delivery, %{
      response_status: status,
      response_body: truncate_response(response_body),
      delivered_at: DateTime.utc_now()
    })
  end

  defp update_delivery_with_result(delivery, {:error, error_message}) do
    WebhookQueries.update_delivery(delivery, %{
      error_message: truncate_response(error_message)
    })
  end

  # Truncate response to prevent database bloat and ensure UTF-8 compatibility
  defp truncate_response(nil), do: nil

  defp truncate_response(response) when is_binary(response) do
    # Ensure the string is valid UTF-8 to prevent Ecto errors
    safe_response =
      if String.printable?(response) do
        response
      else
        # If not printable (contains binary data), inspect it
        inspect(response, binaries: :as_strings, limit: 5000)
      end

    if String.length(safe_response) > 5000 do
      String.slice(safe_response, 0, 5000) <> "... (truncated)"
    else
      safe_response
    end
  end

  defp truncate_response(response), do: inspect(response) |> truncate_response()

  defp http_client do
    Application.get_env(:tymeslot, :http_client, HTTPoison)
  end
end
