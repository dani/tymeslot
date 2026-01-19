defmodule Tymeslot.Infrastructure.ResilientCallTest do
  use Tymeslot.DataCase, async: false

  alias Tymeslot.Infrastructure.{ResilientCall, CircuitBreaker}

  setup do
    breaker_name = String.to_atom("test_breaker_#{system_time()}")
    {:ok, pid} = CircuitBreaker.start_link(name: breaker_name, config: %{
      failure_threshold: 2,
      recovery_timeout: 1000
    })
    
    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, breaker: breaker_name}
  end

  defp system_time, do: System.monotonic_time()

  test "executes function successfully", %{breaker: breaker} do
    result = ResilientCall.execute(fn -> {:ok, "success"} end, breaker: breaker)
    assert result == {:ok, "success"}
  end

  test "retries on retriable failure and eventually succeeds", %{breaker: breaker} do
    test_process = self()
    
    fun = fn ->
      send(test_process, :called)
      if Process.get(:attempts, 0) < 1 do
        Process.put(:attempts, 1)
        {:error, "timeout"}
      else
        {:ok, "eventual success"}
      end
    end

    result = ResilientCall.execute(fun, breaker: breaker, retry_opts: [max_attempts: 3, initial_delay: 1, jitter: false])
    
    assert result == {:ok, "eventual success"}
    assert_receive :called
    assert_receive :called
  end

  test "fails after max retries", %{breaker: breaker} do
    fun = fn -> {:error, "timeout"} end

    result = ResilientCall.execute(fun, breaker: breaker, retry_opts: [max_attempts: 2, initial_delay: 1, jitter: false])
    
    assert result == {:error, :max_attempts_exceeded}
  end

  test "circuit breaker opens after failures", %{breaker: breaker} do
    # First failure (retry will happen but we set max_attempts: 1 to speed up)
    ResilientCall.execute(fn -> {:error, "permanent fail"} end, breaker: breaker, retry_opts: [max_attempts: 1])
    # Second failure - should open the circuit
    ResilientCall.execute(fn -> {:error, "permanent fail"} end, breaker: breaker, retry_opts: [max_attempts: 1])
    
    # Third call - should fail immediately with :circuit_open
    result = ResilientCall.execute(fn -> {:ok, "won't run"} end, breaker: breaker)
    assert result == {:error, :circuit_open}
  end
end
