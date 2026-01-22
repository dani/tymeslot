defmodule Tymeslot.Auth.OAuth.GoogleTest do
  use Tymeslot.DataCase, async: false

  alias Plug.Test, as: PlugTest
  alias Tymeslot.Auth.OAuth.Google
  alias Tymeslot.Auth.OAuth.HelperMock
  import Mox

  setup :verify_on_exit!

  setup do
    old_helper = Application.get_env(:tymeslot, :oauth_helper_module)
    Application.put_env(:tymeslot, :oauth_helper_module, HelperMock)

    on_exit(fn ->
      if old_helper, do: Application.put_env(:tymeslot, :oauth_helper_module, old_helper),
      else: Application.delete_env(:tymeslot, :oauth_helper_module)
    end)
    :ok
  end

  test "authorize_url/2 generates state and builds client" do
    conn = PlugTest.init_test_session(PlugTest.conn(:get, "/"), %{})
    redirect_uri = "http://callback"

    expect(HelperMock, :generate_and_store_state, fn ^conn -> {conn, "state456"} end)
    expect(HelperMock, :build_oauth_client, fn :google, ^redirect_uri, "state456" ->
      %OAuth2.Client{
        client_id: "test",
        authorize_url: "https://accounts.google.com/oauth/authorize",
        redirect_uri: redirect_uri,
        params: %{"state" => "state456"}
      }
    end)

    {_updated_conn, url} = Google.authorize_url(conn, redirect_uri)
    assert url =~ "state=state456"
    assert url =~ "scope=email+profile"
  end

  test "handle_callback/4 validates state and exchanges code" do
    conn = PlugTest.init_test_session(PlugTest.conn(:get, "/"), %{})
    code = "code456"
    state = "state456"
    redirect_uri = "http://callback"

    expect(HelperMock, :validate_state, fn ^conn, ^state -> :ok end)
    expect(HelperMock, :clear_oauth_state, fn ^conn -> conn end)
    expect(HelperMock, :do_handle_callback, fn _conn, ^code, ^redirect_uri, :google -> {:ok, conn, %{"id" => 2}} end)

    assert {:ok, _updated_conn, %{"id" => 2}} = Google.handle_callback(conn, code, state, redirect_uri)
  end

  test "handle_callback/4 returns error on invalid state" do
    conn = PlugTest.init_test_session(PlugTest.conn(:get, "/"), %{})
    code = "code456"
    state = "wrong_state"
    redirect_uri = "http://callback"

    expect(HelperMock, :validate_state, fn ^conn, ^state -> {:error, :invalid_state} end)

    assert {:error, ^conn, :invalid_state} = Google.handle_callback(conn, code, state, redirect_uri)
  end
end
