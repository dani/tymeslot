defmodule Tymeslot.Auth.OAuth.AuthenticatorTest do
  use Tymeslot.DataCase, async: false

  import Mox
  alias Tymeslot.Auth.OAuth.Authenticator
  alias Tymeslot.Auth.OAuth.HelperMock
  alias Tymeslot.Auth.SessionMock
  alias Plug.Test, as: PlugTest

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    # Configure mocks
    old_helper = Application.get_env(:tymeslot, :oauth_helper_module)
    old_session = Application.get_env(:tymeslot, :session_module)

    Application.put_env(:tymeslot, :oauth_helper_module, HelperMock)
    Application.put_env(:tymeslot, :session_module, SessionMock)

    on_exit(fn ->
      if old_helper do
        Application.put_env(:tymeslot, :oauth_helper_module, old_helper)
      else
        Application.delete_env(:tymeslot, :oauth_helper_module)
      end

      if old_session do
        Application.put_env(:tymeslot, :session_module, old_session)
      else
        Application.delete_env(:tymeslot, :session_module)
      end
    end)

    {:ok, conn: PlugTest.conn(:get, "/")}
  end

  describe "authenticate/7" do
    test "successfully authenticates and creates session", %{conn: conn} do
      user = %{id: 1, email: "test@example.com"}
      code = "auth_code"
      provider = :github
      callback_url = "http://callback"
      
      expect(HelperMock, :build_oauth_client, fn :github, ^callback_url, "" -> %OAuth2.Client{} end)
      expect(HelperMock, :exchange_code_for_token, fn _client, ^code -> {:ok, %OAuth2.Client{}} end)
      expect(HelperMock, :get_user_info, fn _client, :github -> {:ok, %{email: "test@example.com"}} end)
      
      process_user_fun = fn _info -> {:ok, user} end
      registration_complete_fun = fn _user -> true end
      build_registration_params_fun = fn _user -> %{} end

      expect(SessionMock, :create_session, fn _conn, ^user -> {:ok, conn, "token"} end)

      assert {:ok, ^conn, "Successfully signed in with Github."} = Authenticator.authenticate(
        conn, code, provider, callback_url, process_user_fun, registration_complete_fun, build_registration_params_fun
      )
    end

    test "successfully authenticates but registration is incomplete", %{conn: conn} do
      user = %{email: "test@example.com"}
      code = "auth_code"
      provider = :google
      callback_url = "http://callback"
      
      expect(HelperMock, :build_oauth_client, fn :google, ^callback_url, "" -> %OAuth2.Client{} end)
      expect(HelperMock, :exchange_code_for_token, fn _client, ^code -> {:ok, %OAuth2.Client{}} end)
      expect(HelperMock, :get_user_info, fn _client, :google -> {:ok, %{email: "test@example.com"}} end)
      
      process_user_fun = fn _info -> {:ok, user} end
      registration_complete_fun = fn _user -> false end
      registration_params = %{email: "test@example.com", provider: "google"}
      build_registration_params_fun = fn _user -> registration_params end

      assert {:ok, ^conn, :incomplete_registration, ^registration_params} = Authenticator.authenticate(
        conn, code, provider, callback_url, process_user_fun, registration_complete_fun, build_registration_params_fun
      )
    end

    test "returns error when code exchange fails due to OAuth error", %{conn: conn} do
      expect(HelperMock, :build_oauth_client, fn _, _, _ -> %OAuth2.Client{} end)
      expect(HelperMock, :exchange_code_for_token, fn _client, _code -> {:error, %OAuth2.Error{reason: "invalid_code"}} end)
      
      assert {:error, ^conn, :oauth_error, "Failed to authenticate with Github."} = Authenticator.authenticate(
        conn, "bad_code", :github, "url", fn _ -> {:ok, %{}} end, fn _ -> true end, fn _ -> %{} end
      )
    end

    test "returns error when other authentication errors occur", %{conn: conn} do
      expect(HelperMock, :build_oauth_client, fn _, _, _ -> %OAuth2.Client{} end)
      expect(HelperMock, :exchange_code_for_token, fn _client, _code -> {:ok, %OAuth2.Client{}} end)
      expect(HelperMock, :get_user_info, fn _client, _ -> {:error, :unreachable} end)
      
      assert {:error, ^conn, :authentication_error, "An error occurred during Github authentication."} = Authenticator.authenticate(
        conn, "code", :github, "url", fn _ -> {:ok, %{}} end, fn _ -> true end, fn _ -> %{} end
      )
    end

    test "returns error when session creation fails", %{conn: conn} do
      user = %{id: 1}
      expect(HelperMock, :build_oauth_client, fn _, _, _ -> %OAuth2.Client{} end)
      expect(HelperMock, :exchange_code_for_token, fn _client, _code -> {:ok, %OAuth2.Client{}} end)
      expect(HelperMock, :get_user_info, fn _client, _ -> {:ok, %{}} end)
      
      expect(SessionMock, :create_session, fn _conn, ^user -> {:error, :failed, "message"} end)

      assert {:error, ^conn, :session_creation_failed, "Authentication succeeded but session creation failed."} = Authenticator.authenticate(
        conn, "code", :github, "url", fn _ -> {:ok, user} end, fn _ -> true end, fn _ -> %{} end
      )
    end
  end
end
