defmodule Tymeslot.DemoTest do
  use Tymeslot.DataCase, async: true
  alias Tymeslot.Demo

  describe "Demo facade" do
    test "provider/0 returns configured provider" do
      # Check saas_mode to know what to expect in umbrella test environment
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert Demo.provider() == TymeslotSaas.Demo.Resolver
      else
        assert Demo.provider() == Tymeslot.Demo.NoOp
      end
    end

    test "delegates calls to the provider" do
      # Simple smoke test to ensure delegation works
      refute Demo.demo_mode?(%{})
      assert Demo.get_orchestrator(%{}) == Tymeslot.Bookings.Orchestrator
    end
  end
end
