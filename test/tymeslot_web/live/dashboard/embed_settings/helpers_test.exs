defmodule TymeslotWeb.Live.Dashboard.EmbedSettings.HelpersTest do
  use Tymeslot.DataCase, async: true
  alias TymeslotWeb.Live.Dashboard.EmbedSettings.Helpers

  describe "embed_code/2" do
    test "generates inline embed code" do
      assigns = %{username: "testuser", base_url: "https://tymeslot.com"}
      code = Helpers.embed_code("inline", assigns)

      assert code =~ "id=\"tymeslot-booking\""
      assert code =~ "data-username=\"testuser\""
      assert code =~ "src=\"https://tymeslot.com/embed.js\""
    end

    test "generates popup embed code" do
      assigns = %{username: "testuser", base_url: "https://tymeslot.com"}
      code = Helpers.embed_code("popup", assigns)

      assert code =~ "onclick=\"TymeslotBooking.open('testuser')\""
      assert code =~ "src=\"https://tymeslot.com/embed.js\""
    end

    test "generates link embed code" do
      assigns = %{booking_url: "https://tymeslot.com/testuser"}
      code = Helpers.embed_code("link", assigns)

      assert code =~ "href=\"https://tymeslot.com/testuser\""
      assert code =~ "Schedule a meeting"
    end

    test "generates floating embed code" do
      assigns = %{username: "testuser", base_url: "https://tymeslot.com"}
      code = Helpers.embed_code("floating", assigns)

      assert code =~ "src=\"https://tymeslot.com/embed.js\""
      assert code =~ "TymeslotBooking.initFloating('testuser')"
    end

    test "returns empty string for unknown type" do
      assert Helpers.embed_code("unknown", %{}) == ""
    end
  end
end
