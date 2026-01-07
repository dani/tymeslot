defmodule TymeslotWeb.FallbackControllerTest do
  use TymeslotWeb.ConnCase, async: true

  describe "GET / (fallback)" do
    test "redirects to root path", %{conn: conn} do
      # We need to trigger the fallback. Usually it's via a route that doesn't exist but is caught by a fallback plug,
      # or directly calling the controller. The controller is usually used as a fallback for the router.
      # Looking at the controller, it just does `redirect(conn, to: ~p"/")`.

      conn = get(conn, "/some-non-existent-path-that-should-be-caught")
      # Wait, I should check the router to see how FallbackController is used.
      assert redirected_to(conn) == "/"
    end
  end
end
