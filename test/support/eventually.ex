defmodule Tymeslot.TestHelpers.Eventually do
  @moduledoc """
  Helper for deterministic polling in tests.
  """

  @doc """
  Repeatedly executes the given function until it returns truthy or times out.
  Default timeout is 1000ms with 50ms interval.
  """
  @spec eventually((() -> any()), keyword()) :: any()
  def eventually(func, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 1000)
    interval = Keyword.get(opts, :interval, 50)
    start_time = System.monotonic_time(:millisecond)

    do_eventually(func, timeout, interval, start_time)
  end

  defp do_eventually(func, timeout, interval, start_time) do
    if result = func.() do
      result
    else
      retry_or_fail(func, timeout, interval, start_time)
    end
  rescue
    _e in [ExUnit.AssertionError] ->
      retry_or_fail(func, timeout, interval, start_time)
  end

  defp retry_or_fail(func, timeout, interval, start_time) do
    now = System.monotonic_time(:millisecond)

    if now - start_time < timeout do
      Process.sleep(interval)
      do_eventually(func, timeout, interval, start_time)
    else
      # Final attempt, let it raise if it fails
      func.()
    end
  end
end
