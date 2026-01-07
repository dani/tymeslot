defmodule Tymeslot.Webhooks do
  @moduledoc """
  Context module for webhook management and delivery.

  Provides the public API for:
  - CRUD operations on webhooks
  - Testing webhook connections
  - Triggering webhook deliveries
  - Viewing delivery logs and statistics
  """

  require Logger

  alias Tymeslot.DatabaseQueries.WebhookQueries
  alias Tymeslot.DatabaseSchemas.{WebhookDeliverySchema, WebhookSchema}
  alias Tymeslot.Webhooks.{PayloadBuilder, Security}
  alias Tymeslot.Workers.WebhookWorker

  # ============================================================================
  # CRUD Operations
  # ============================================================================

  @doc """
  Lists all webhooks for a user.
  """
  @spec list_webhooks(integer()) :: [WebhookSchema.t()]
  def list_webhooks(user_id) do
    WebhookQueries.list_webhooks(user_id)
  end

  @doc """
  Gets a single webhook by ID for a specific user.
  Returns the webhook with decrypted secret.
  """
  @spec get_webhook(integer(), integer()) :: {:ok, WebhookSchema.t()} | {:error, :not_found}
  def get_webhook(id, user_id) do
    case WebhookQueries.get_webhook(id, user_id) do
      {:ok, webhook} -> {:ok, WebhookSchema.decrypt_secret(webhook)}
      error -> error
    end
  end

  @doc """
  Creates a new webhook for a user.
  """
  @spec create_webhook(integer(), map()) ::
          {:ok, WebhookSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_webhook(user_id, attrs) do
    attrs
    |> Map.put(:user_id, user_id)
    |> WebhookQueries.create_webhook()
  end

  @doc """
  Updates a webhook.
  """
  @spec update_webhook(WebhookSchema.t(), map()) ::
          {:ok, WebhookSchema.t()} | {:error, Ecto.Changeset.t()}
  def update_webhook(webhook, attrs) do
    WebhookQueries.update_webhook(webhook, attrs)
  end

  @doc """
  Deletes a webhook.
  """
  @spec delete_webhook(WebhookSchema.t()) ::
          {:ok, WebhookSchema.t()} | {:error, Ecto.Changeset.t()}
  def delete_webhook(webhook) do
    WebhookQueries.delete_webhook(webhook)
  end

  @doc """
  Toggles webhook active status.
  """
  @spec toggle_webhook(WebhookSchema.t()) ::
          {:ok, WebhookSchema.t()} | {:error, Ecto.Changeset.t()}
  def toggle_webhook(webhook) do
    WebhookQueries.toggle_webhook(webhook)
  end

  @doc """
  Re-enables a disabled webhook (resets failure count).
  """
  @spec enable_webhook(WebhookSchema.t()) ::
          {:ok, WebhookSchema.t()} | {:error, Ecto.Changeset.t()}
  def enable_webhook(webhook) do
    WebhookQueries.enable_webhook(webhook)
  end

  # ============================================================================
  # Validation & Testing
  # ============================================================================

  @doc """
  Tests a webhook connection by sending a test payload.
  """
  @spec test_webhook_connection(String.t(), String.t() | nil) :: :ok | {:error, String.t()}
  def test_webhook_connection(url, secret \\ nil) do
    payload = PayloadBuilder.build_test_payload()
    headers = build_headers(payload, secret)

    case http_client().post(url, Jason.encode!(payload), headers, recv_timeout: 10_000) do
      {:ok, %{status_code: status}} when status >= 200 and status < 300 ->
        :ok

      {:ok, %{status_code: status}} ->
        {:error, "Webhook returned status #{status}"}

      {:error, %{reason: reason}} ->
        {:error, "Connection failed: #{inspect(reason)}"}

      {:error, reason} ->
        {:error, "Connection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Validates a webhook URL format.
  Checks for protocol and prevents SSRF by blocking private IP ranges in production.
  """
  @spec validate_webhook_url(String.t()) :: :ok | {:error, String.t()}
  def validate_webhook_url(url) do
    WebhookSchema.validate_url_format(url)
  end

  # ============================================================================
  # Delivery
  # ============================================================================

  @doc """
  Triggers a webhook delivery by scheduling it via Oban.
  """
  @spec trigger_webhook(WebhookSchema.t(), String.t(), map()) :: :ok | {:error, term()}
  def trigger_webhook(webhook, event_type, meeting) do
    if WebhookSchema.should_be_active?(webhook) and
         WebhookSchema.subscribed_to?(webhook, event_type) do
      WebhookWorker.schedule_delivery(webhook.id, event_type, meeting.id)
    else
      {:error, :webhook_not_active}
    end
  end

  @doc """
  Triggers all webhooks for a user and event type.
  """
  @spec trigger_webhooks_for_event(integer(), String.t(), map()) :: :ok
  def trigger_webhooks_for_event(user_id, event_type, meeting) do
    user_id
    |> WebhookQueries.list_active_webhooks_for_event(event_type)
    |> Enum.each(fn webhook ->
      case trigger_webhook(webhook, event_type, meeting) do
        :ok ->
          Logger.debug("Scheduled webhook delivery",
            webhook_id: webhook.id,
            event_type: event_type
          )

        {:error, reason} ->
          Logger.warning("Failed to schedule webhook delivery",
            webhook_id: webhook.id,
            event_type: event_type,
            reason: inspect(reason)
          )
      end
    end)

    :ok
  end

  # ============================================================================
  # Delivery Logs
  # ============================================================================

  @doc """
  Lists webhook deliveries with pagination.
  """
  @spec list_deliveries(integer(), keyword()) :: [WebhookDeliverySchema.t()]
  def list_deliveries(webhook_id, opts \\ []) do
    WebhookQueries.list_deliveries(webhook_id, opts)
  end

  @doc """
  Gets delivery statistics for a webhook.
  """
  @spec get_delivery_stats(integer(), keyword()) :: map()
  def get_delivery_stats(webhook_id, opts \\ []) do
    WebhookQueries.get_delivery_stats(webhook_id, opts)
  end

  # ============================================================================
  # Events
  # ============================================================================

  @doc """
  Returns all available event types.
  """
  @spec available_events() :: [map()]
  def available_events do
    [
      %{
        value: "meeting.created",
        label: "Meeting Created",
        description: "Triggered when a new booking is created"
      },
      %{
        value: "meeting.cancelled",
        label: "Meeting Cancelled",
        description: "Triggered when a booking is cancelled"
      },
      %{
        value: "meeting.rescheduled",
        label: "Meeting Rescheduled",
        description: "Triggered when a booking time is changed"
      }
    ]
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp build_headers(_payload, nil) do
    [
      {"Content-Type", "application/json"},
      {"User-Agent", "Tymeslot-Webhooks/1.0"}
    ]
  end

  defp build_headers(payload, secret) when is_binary(secret) do
    signature = Security.generate_signature(payload, secret)

    [
      {"Content-Type", "application/json"},
      {"User-Agent", "Tymeslot-Webhooks/1.0"},
      {"X-Tymeslot-Signature", signature},
      {"X-Tymeslot-Timestamp", DateTime.utc_now() |> DateTime.to_iso8601()}
    ]
  end

  defp http_client do
    Application.get_env(:tymeslot, :http_client, HTTPoison)
  end
end
