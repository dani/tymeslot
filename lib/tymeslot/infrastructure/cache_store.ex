defmodule Tymeslot.Infrastructure.CacheStore do
  @moduledoc """
  A reusable base for ETS-based caches.
  Provides standard lookup, compute, and cleanup logic.
  """

  defmacro __using__(opts) do
    quote do
      use GenServer
      alias Tymeslot.Infrastructure.CacheStore

      @table_name unquote(opts[:table_name])
      @default_ttl unquote(opts[:default_ttl] || :timer.minutes(5))
      @cleanup_interval unquote(opts[:cleanup_interval] || :timer.minutes(10))

      # Client API

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @doc """
      Get a value from cache or compute it if missing/expired.
      Coalesces concurrent requests for the same key to prevent cache stampedes.
      """
      def get_or_compute(key, fun, ttl \\ @default_ttl) do
        case CacheStore.lookup(@table_name, key) do
          {:ok, value} ->
            value

          :miss ->
            # In test environment, compute directly to avoid ownership issues with background tasks.
            # This ensures that database connections and Mox expectations are preserved.
            if Application.get_env(:tymeslot, :environment) == :test and
                 not Application.get_env(:tymeslot, :force_cache_coalescing, false) do
              CacheStore.compute_and_store(@table_name, key, fun, ttl)
            else
              # Use GenServer to coalesce concurrent computations
              GenServer.call(__MODULE__, {:compute_coalesced, key, fun, ttl}, :timer.minutes(1))
            end
        end
      end

      @doc """
      Invalidate a specific cache key.
      """
      def invalidate(key) do
        :ets.delete(@table_name, key)
      end

      @doc """
      Invalidate all cache entries matching a pattern.
      """
      def invalidate_pattern(pattern) do
        :ets.match_delete(@table_name, {pattern, :_, :_})
      end

      @doc """
      Clear all cache entries.
      """
      def clear_all do
        :ets.delete_all_objects(@table_name)
      end

      # Server Callbacks

      @impl true
      def init(_opts) do
        :ets.new(@table_name, [
          :named_table,
          :public,
          :set,
          read_concurrency: true
        ])

        CacheStore.schedule_cleanup(@cleanup_interval)
        {:ok, %{pending: %{}}}
      end

      @impl true
      def handle_call({:compute_coalesced, key, fun, ttl}, from, state) do
        # Double-check lookup inside the GenServer to handle race between
        # the initial lookup and reaching the GenServer.
        case CacheStore.lookup(@table_name, key) do
          {:ok, value} ->
            {:reply, value, state}

          :miss ->
            case Map.get(state.pending, key) do
              nil ->
                # No computation in flight, start one
                parent = self()

                Task.start(fn ->
                  value = fun.()
                  send(parent, {:computation_done, key, value, ttl})
                end)

                new_state = put_in(state.pending[key], [from])
                {:noreply, new_state}

              waiters ->
                # Already computing, add this caller to waiters
                new_state = put_in(state.pending[key], [from | waiters])
                {:noreply, new_state}
            end
        end
      end

      @impl true
      def handle_info({:computation_done, key, value, ttl}, state) do
        waiters = Map.get(state.pending, key, [])

        # Store in ETS
        expiry = System.monotonic_time(:millisecond) + ttl
        :ets.insert(@table_name, {key, value, expiry})

        # Reply to everyone
        Enum.each(waiters, fn waiter ->
          GenServer.reply(waiter, value)
        end)

        {:noreply, %{state | pending: Map.delete(state.pending, key)}}
      end

      @impl true
      def handle_info(:cleanup, state) do
        CacheStore.cleanup_expired(@table_name)
        CacheStore.schedule_cleanup(@cleanup_interval)
        {:noreply, state}
      end

      defoverridable init: 1, handle_info: 2
    end
  end

  # Helpers to reduce quote block size

  @doc false
  @spec lookup(atom(), any()) :: {:ok, any()} | :miss
  def lookup(table_name, key) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(table_name, key) do
      [{^key, value, expiry}] when expiry > now ->
        {:ok, value}

      _ ->
        :miss
    end
  end

  @doc false
  @spec compute_and_store(atom(), any(), (-> any()), integer()) :: any()
  def compute_and_store(table_name, key, fun, ttl) do
    value = fun.()
    expiry = System.monotonic_time(:millisecond) + ttl
    :ets.insert(table_name, {key, value, expiry})
    value
  end

  @doc false
  @spec cleanup_expired(atom()) :: integer()
  def cleanup_expired(table_name) do
    now = System.monotonic_time(:millisecond)

    :ets.select_delete(table_name, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])
  end

  @doc false
  @spec schedule_cleanup(integer()) :: reference()
  def schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
