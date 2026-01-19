defmodule Tymeslot.Payments.Webhooks.IdempotencyCache do
  @moduledoc """
  ETS-based idempotency cache for webhook event deduplication.
  Uses the centralized CacheStore infrastructure.
  """

  alias Tymeslot.Infrastructure.CacheStore

  use CacheStore,
    table_name: :webhook_idempotency_cache,
    default_ttl: :timer.hours(24),
    cleanup_interval: :timer.hours(1)

  @processing_ttl :timer.minutes(10)
  @processed_ttl :timer.hours(24)

  @doc """
  Check if an event has already been processed.
  Returns {:ok, :not_processed} if the event hasn't been seen,
  or {:ok, :already_processed} if it has already been processed.
  """
  @spec check_idempotency(String.t()) :: {:ok, :not_processed | :already_processed}
  def check_idempotency(event_id) do
    case CacheStore.lookup(:webhook_idempotency_cache, event_id) do
      {:ok, _timestamp} ->
        {:ok, :already_processed}

      :miss ->
        {:ok, :not_processed}
    end
  end

  @doc """
  Atomically reserves an event for processing.
  Returns {:ok, :reserved} if this process should handle it,
  or {:ok, :already_processed} if another process already reserved/processed it.
  """
  @spec reserve(String.t()) :: {:ok, :reserved | :in_progress | :already_processed}
  def reserve(event_id) do
    now = System.monotonic_time(:millisecond)
    expiry = now + @processing_ttl

    case :ets.insert_new(:webhook_idempotency_cache, {event_id, :processing, expiry}) do
      true ->
        {:ok, :reserved}

      false ->
        case lookup_entry(event_id) do
          {:ok, :processing} ->
            {:ok, :in_progress}

          {:ok, :processed} ->
            {:ok, :already_processed}

          :miss ->
            # Entry expired but wasn't cleaned yet; clear and try again
            :ets.delete(:webhook_idempotency_cache, event_id)

            if :ets.insert_new(:webhook_idempotency_cache, {event_id, :processing, expiry}) do
              {:ok, :reserved}
            else
              {:ok, :in_progress}
            end
        end
    end
  end

  @doc """
  Mark an event as processed in the cache.
  """
  @spec mark_processed(String.t()) :: :ok
  def mark_processed(event_id) do
    # Mark as processed with a 24-hour TTL
    put(event_id, :processed, @processed_ttl)
  end

  @doc """
  Releases a reserved event so it can be retried.
  """
  @spec release(String.t()) :: :ok
  def release(event_id) do
    invalidate(event_id)
    :ok
  end

  defp lookup_entry(event_id) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(:webhook_idempotency_cache, event_id) do
      [{^event_id, value, expiry}] when expiry > now -> {:ok, value}
      _ -> :miss
    end
  end
end
