defmodule TymeslotWeb.RouterHookConfigTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  setup do
    original = Application.get_env(:tymeslot, :dashboard_additional_hooks)

    on_exit(fn ->
      if is_nil(original) do
        Application.delete_env(:tymeslot, :dashboard_additional_hooks)
      else
        Application.put_env(:tymeslot, :dashboard_additional_hooks, original)
      end
    end)

    :ok
  end

  test "returns a configured list of hooks" do
    hooks = [
      {TymeslotWeb.Hooks.AuthLiveSessionHook, :ensure_authenticated},
      TymeslotWeb.Hooks.ClientInfoHook
    ]

    Application.put_env(:tymeslot, :dashboard_additional_hooks, hooks)

    assert TymeslotWeb.Router.dashboard_additional_hooks() == hooks
  end

  test "wraps a single hook value and logs a warning" do
    hook = {TymeslotWeb.Hooks.AuthLiveSessionHook, :ensure_authenticated}

    log =
      capture_log(fn ->
        Application.put_env(:tymeslot, :dashboard_additional_hooks, hook)

        assert TymeslotWeb.Router.dashboard_additional_hooks() == [hook]
      end)

    assert log =~ "Expected :dashboard_additional_hooks to be a list, received a single hook"
  end

  test "ignores invalid values and logs a warning" do
    log =
      capture_log(fn ->
        Application.put_env(:tymeslot, :dashboard_additional_hooks, "invalid")

        assert TymeslotWeb.Router.dashboard_additional_hooks() == []
      end)

    assert log =~ "Expected :dashboard_additional_hooks to be a list. Ignoring invalid value"
  end
end
