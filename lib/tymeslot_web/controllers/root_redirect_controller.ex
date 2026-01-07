defmodule TymeslotWeb.RootRedirectController do
  use TymeslotWeb, :controller

  @doc """
  Handles the root path routing for self-hosted deployments.
  - Redirects authenticated users to dashboard
  - Redirects unauthenticated users to login
  """
  @spec index(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def index(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/dashboard")
    else
      redirect(conn, to: ~p"/auth/login")
    end
  end
end
