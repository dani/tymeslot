defmodule TymeslotWeb.RootRedirectControllerTest do
  # async false because we are changing env vars
  use TymeslotWeb.ConnCase, async: false

  alias Tymeslot.AuthTestHelpers
  alias Tymeslot.Factory

  setup do
    # Save original env and config to restore them later
    original_type = System.get_env("DEPLOYMENT_TYPE")
    original_saas_mode = Application.get_env(:tymeslot, :saas_mode)

    on_exit(fn ->
      if original_type do
        System.put_env("DEPLOYMENT_TYPE", original_type)
      else
        System.delete_env("DEPLOYMENT_TYPE")
      end

      Application.put_env(:tymeslot, :saas_mode, original_saas_mode)
    end)

    :ok
  end

  describe "GET /" do
    test "redirects to dashboard if user is logged in", %{conn: conn} do
      user = Factory.insert(:user)
      conn = conn |> AuthTestHelpers.log_in_user(user) |> get(~p"/")

      assert redirected_to(conn) == "/dashboard"
    end

    test "renders homepage LiveView if unauthenticated and SaaS mode", %{conn: conn} do
      # This test is only relevant when running in SaaS mode
      Application.put_env(:tymeslot, :saas_mode, true)
      System.delete_env("DEPLOYMENT_TYPE")
      conn = get(conn, ~p"/")

      # live_render doesn't redirect, it renders.
      # We check if it returns 200 and has some homepage content
      assert html_response(conn, 200) =~ "Tymeslot"
    end

    test "redirects to login if unauthenticated and standalone (docker)", %{conn: conn} do
      Application.put_env(:tymeslot, :saas_mode, false)
      System.put_env("DEPLOYMENT_TYPE", "docker")
      conn = get(conn, ~p"/")

      assert redirected_to(conn) == "/auth/login"
    end

    test "redirects to login if unauthenticated and standalone (cloudron)", %{conn: conn} do
      Application.put_env(:tymeslot, :saas_mode, false)
      System.put_env("DEPLOYMENT_TYPE", "cloudron")
      conn = get(conn, ~p"/")

      assert redirected_to(conn) == "/auth/login"
    end
  end
end
