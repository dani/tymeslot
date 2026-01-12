defmodule Tymeslot.Infrastructure.CacheStoreTest do
  use ExUnit.Case, async: false

  defmodule TestCache do
    use Tymeslot.Infrastructure.CacheStore,
      table_name: :test_cache,
      default_ttl: :timer.seconds(1),
      cleanup_interval: :timer.seconds(5)
  end

  setup do
    start_supervised!(TestCache)
    TestCache.clear_all()
    :ok
  end

  test "get_or_compute caches the value" do
    key = "key1"
    counter = :erlang.unique_integer()

    # First call computes
    val1 = TestCache.get_or_compute(key, fn -> {:computed, counter} end)

    # Second call returns cached
    val2 = TestCache.get_or_compute(key, fn -> {:computed, :erlang.unique_integer()} end)

    assert val1 == val2
    assert val1 == {:computed, counter}
  end

  test "get_or_compute coalesces concurrent requests (prevents stampede)" do
    # Force coalescing even in test environment for this specific test
    Application.put_env(:tymeslot, :force_cache_coalescing, true)
    on_exit(fn -> Application.delete_env(:tymeslot, :force_cache_coalescing) end)

    key = "stampede_key"
    parent = self()

    # Start 5 concurrent requests
    tasks =
      Enum.map(1..5, fn _ ->
        Task.async(fn ->
          TestCache.get_or_compute(key, fn ->
            # Signal that we started computing
            send(parent, :computing_started)
            # Simulate slow computation
            Process.sleep(100)
            :result
          end)
        end)
      end)

    results = Task.yield_many(tasks, 500)

    # Verify all got the same result
    Enum.each(results, fn {_task, {:ok, res}} ->
      assert res == :result
    end)

    # Verify the computation function was only called ONCE
    # We should have exactly one :computing_started message in our mailbox
    messages = collect_messages([])
    assert length(Enum.filter(messages, &(&1 == :computing_started))) == 1
  end

  test "invalidate removes item from cache" do
    TestCache.get_or_compute("key", fn -> "val" end)
    assert TestCache.get_or_compute("key", fn -> "new" end) == "val"

    TestCache.invalidate("key")
    assert TestCache.get_or_compute("key", fn -> "new" end) == "new"
  end

  defp collect_messages(acc) do
    receive do
      msg -> collect_messages([msg | acc])
    after
      0 -> acc
    end
  end
end
