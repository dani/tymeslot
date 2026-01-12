defmodule TymeslotWeb.LiveCase do
  @moduledoc """
  This module defines the test case to be used by
  LiveView tests.

  Such tests rely on `Phoenix.LiveViewTest` and also
  import other functionality to make it easier
  to build common data structures and test LiveView functionality.
  """

  use ExUnit.CaseTemplate

  alias Phoenix.ConnTest
  alias Tymeslot.DataCase

  using do
    quote do
      # The default endpoint for testing
      @endpoint TymeslotWeb.Endpoint

      use TymeslotWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import TymeslotWeb.LiveCase

      def wait_until(predicate, timeout_ms \\ 30_000, interval_ms \\ 100) do
        deadline = System.monotonic_time(:millisecond) + timeout_ms
        do_wait_until(predicate, deadline, interval_ms)
      end

      defp do_wait_until(predicate, deadline, interval_ms) do
        case predicate.() do
          true ->
            :ok

          {:ok, _} ->
            :ok

          _ ->
            now = System.monotonic_time(:millisecond)

            if now >= deadline do
              flunk(
                "Timed out waiting for UI condition. Current monotonic time: #{now}, deadline: #{deadline}"
              )
            end

            Process.sleep(interval_ms)
            do_wait_until(predicate, deadline, interval_ms)
        end
      end
    end
  end

  setup tags do
    DataCase.setup_sandbox(tags)
    {:ok, conn: ConnTest.build_conn()}
  end
end
