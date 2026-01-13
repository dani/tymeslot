defmodule Tymeslot.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  database access.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Tymeslot.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.Changeset
  alias Tymeslot.Infrastructure.CalendarCircuitBreaker
  alias Tymeslot.Infrastructure.CircuitBreaker
  alias Tymeslot.Repo

  using do
    quote do
      alias Tymeslot.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Tymeslot.DataCase
      import Tymeslot.Factory
    end
  end

  setup tags do
    setup_sandbox(tags)

    # Reset stateful components to ensure test isolation
    reset_stateful_components()

    :ok
  end

  @doc """
  Resets stateful components like circuit breakers between tests.
  This ensures test isolation and prevents state pollution.
  """
  @spec reset_stateful_components() :: :ok
  def reset_stateful_components do
    # Reset calendar circuit breakers
    providers = [:caldav, :radicale, :nextcloud, :google, :outlook]

    Enum.each(providers, fn p ->
      CalendarCircuitBreaker.reset(p)
    end)

    # Reset other circuit breakers
    Enum.each([:email_service_breaker, :oauth_github_breaker, :oauth_google_breaker], fn name ->
      if Process.whereis(name), do: CircuitBreaker.reset(name)
    end)

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  @spec setup_sandbox(map()) :: :ok
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  @spec errors_on(Ecto.Changeset.t()) :: map()
  def errors_on(changeset) do
    Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
