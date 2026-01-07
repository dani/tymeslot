defmodule Tymeslot.Workers.WebhookCleanupWorker do
  @moduledoc """
  Oban worker for cleaning up old webhook delivery logs.

  Ensures the database doesn't grow indefinitely by removing
  old logs based on the configured retention period.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 3600]

  require Logger

  alias Tymeslot.DatabaseQueries.WebhookQueries

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # Default to 60 days retention as requested
    retention_days = Map.get(args, "retention_days", 60)

    Logger.info("Starting webhook delivery cleanup", retention_days: retention_days)

    {count, _} = WebhookQueries.cleanup_old_deliveries(retention_days)

    Logger.info("Webhook delivery cleanup completed",
      deleted_count: count,
      retention_days: retention_days
    )

    :ok
  end
end
