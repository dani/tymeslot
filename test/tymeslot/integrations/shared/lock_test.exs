defmodule Tymeslot.Integrations.Shared.LockTest do
  # async: false because we are deleting a global ETS table
  use ExUnit.Case, async: false

  alias Tymeslot.Integrations.Shared.Lock

  @table :integration_operation_locks

  describe "with_lock/2" do
    test "ensures table exists when manager is running" do
      # Ensure it's started
      if !Process.whereis(Lock), do: Lock.start_link([])

      assert :ets.info(@table) != :undefined

      # Calling with_lock should succeed
      result = Lock.with_lock("test_key", fn -> :ok end)
      assert result == :ok
    end

    test "serializes execution" do
      test_pid = self()

      # Start a process that holds the lock
      spawn_link(fn ->
        Lock.with_lock("lock_456", fn ->
          send(test_pid, :locked)
          Process.sleep(100)
        end)
      end)

      assert_receive :locked

      # Try to get the same lock
      assert {:error, :refresh_in_progress} =
               Lock.with_lock("lock_456", fn -> :ok end)
    end

    test "cleans up monitors when overwriting expired lock" do
      key = "expired_lock_123"

      # Acquire lock in a process that stays alive
      parent = self()

      {pid, ref} =
        spawn_monitor(fn ->
          Lock.with_lock(key, fn ->
            send(parent, :locked)
            Process.sleep(:infinity)
          end)
        end)

      receive do
        :locked -> :ok
      after
        1000 -> flunk("Failed to acquire initial lock")
      end

      # Expire the lock manually via test helper
      expired_timestamp = System.monotonic_time(:millisecond) - 120_000
      Lock.put_lock(key, expired_timestamp, pid)

      # Acquire the lock again from a new process
      assert :ok = Lock.with_lock(key, fn -> :ok end)

      # Give the GenServer a moment to process everything
      Process.sleep(50)

      Process.exit(pid, :kill)

      receive do
        {:DOWN, ^ref, :process, ^pid, :killed} -> :ok
      end
    end

    test "supports backward compatibility for calendar integrations" do
      assert :ok = Lock.with_lock(:google, 999, fn -> :ok end)
      
      # Should also block the tuple key
      test_pid = self()
      spawn_link(fn ->
        Lock.with_lock({:google, 999}, fn ->
          send(test_pid, :locked)
          Process.sleep(100)
        end)
      end)
      
      assert_receive :locked
      assert {:error, :refresh_in_progress} = Lock.with_lock(:google, 999, fn -> :ok end)
    end
  end
end
