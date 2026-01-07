defmodule TymeslotWeb.Components.HeroBookingDemoTest do
  use TymeslotWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias TymeslotWeb.Components.HeroBookingDemo

  test "renders hero booking demo component" do
    html = render_component(HeroBookingDemo, id: "hero-demo")

    assert html =~ "Select Duration"
    assert html =~ "Pick a Time"
    assert html =~ "Discovery Call"
    assert html =~ "Alex Thompson"
  end
end
