defmodule Tymeslot.Infrastructure.AppConfigBehaviour do
  @moduledoc """
  Behaviour for application-wide configuration that might differ between Core and SaaS.
  """

  @callback saas_mode?() :: boolean()
  @callback enforce_legal_agreements?() :: boolean()
  @callback site_home_path() :: String.t()
end

defmodule Tymeslot.Infrastructure.AppConfig do
  @moduledoc """
  Default implementation of AppConfigBehaviour for Tymeslot Core.
  """
  @behaviour Tymeslot.Infrastructure.AppConfigBehaviour

  @impl true
  def saas_mode? do
    Application.get_env(:tymeslot, :saas_mode, false)
  end

  @impl true
  def enforce_legal_agreements? do
    Application.get_env(:tymeslot, :enforce_legal_agreements, false)
  end

  @impl true
  def site_home_path do
    Application.get_env(:tymeslot, :site_home_path, "/dashboard")
  end
end
