defmodule Tymeslot.Integrations.Calendar.CalDAV.ServerDetectorTest do
  use ExUnit.Case, async: true

  alias Tymeslot.Integrations.Calendar.CalDAV.ServerDetector

  describe "detect_from_url/1" do
    test "detects Radicale from hostname containing 'radicale'" do
      assert ServerDetector.detect_from_url("https://radicale.example.com") == :radicale
      assert ServerDetector.detect_from_url("https://my-radicale-server.com") == :radicale
      assert ServerDetector.detect_from_url("https://RADICALE.example.com") == :radicale
    end

    test "detects Radicale from port 5232" do
      assert ServerDetector.detect_from_url("https://cal.example.com:5232") == :radicale
      assert ServerDetector.detect_from_url("http://localhost:5232") == :radicale
    end

    test "detects Nextcloud from hostname containing 'nextcloud'" do
      assert ServerDetector.detect_from_url("https://nextcloud.example.com") == :nextcloud
      assert ServerDetector.detect_from_url("https://my-nextcloud.com") == :nextcloud
      assert ServerDetector.detect_from_url("https://NEXTCLOUD.example.com") == :nextcloud
    end

    test "detects Nextcloud from remote.php/dav path" do
      assert ServerDetector.detect_from_url("https://cloud.example.com/remote.php/dav") ==
               :nextcloud

      assert ServerDetector.detect_from_url("https://example.com/remote.php/webdav") ==
               :nextcloud
    end

    test "detects ownCloud from hostname" do
      assert ServerDetector.detect_from_url("https://owncloud.example.com") == :owncloud
      assert ServerDetector.detect_from_url("https://my-owncloud.com") == :owncloud
      assert ServerDetector.detect_from_url("https://OWNCLOUD.example.com") == :owncloud
    end

    test "detects Baikal from hostname containing 'baikal'" do
      assert ServerDetector.detect_from_url("https://baikal.example.com") == :baikal
      assert ServerDetector.detect_from_url("https://my-baikal.com") == :baikal
    end

    test "detects Baikal from cal.php path" do
      assert ServerDetector.detect_from_url("https://example.com/cal.php") == :baikal
      assert ServerDetector.detect_from_url("https://example.com/cal.php/calendars") == :baikal
    end

    test "detects SabreDAV from hostname containing 'sabre'" do
      assert ServerDetector.detect_from_url("https://sabredav.example.com") == :sabredav
      assert ServerDetector.detect_from_url("https://sabre.example.com") == :sabredav
    end

    test "detects SabreDAV from server.php path" do
      assert ServerDetector.detect_from_url("https://example.com/server.php") == :sabredav
    end

    test "returns :generic for unknown CalDAV servers" do
      assert ServerDetector.detect_from_url("https://caldav.example.com") == :generic
      assert ServerDetector.detect_from_url("https://calendar.example.com") == :generic
      assert ServerDetector.detect_from_url("https://dav.example.com/calendars") == :generic
    end
  end

  describe "detect_from_headers/1" do
    test "detects Radicale from Server header" do
      headers = [{"server", "radicale/3.1.8"}]
      assert ServerDetector.detect_from_headers(headers) == :radicale
    end

    test "detects Nextcloud from Server header" do
      headers = [{"server", "Apache/2.4.41 (Ubuntu) Nextcloud"}]
      assert ServerDetector.detect_from_headers(headers) == :nextcloud
    end

    test "detects Nextcloud from X-Powered-By header" do
      headers = [{"x-powered-by", "Nextcloud"}]
      assert ServerDetector.detect_from_headers(headers) == :nextcloud
    end

    test "detects ownCloud from Server header" do
      headers = [{"server", "Apache ownCloud"}]
      assert ServerDetector.detect_from_headers(headers) == :owncloud
    end

    test "detects Baikal from Server header" do
      headers = [{"server", "Baikal/0.9.3"}]
      assert ServerDetector.detect_from_headers(headers) == :baikal
    end

    test "detects SabreDAV from Server header" do
      headers = [{"server", "SabreDAV/4.3.1"}]
      assert ServerDetector.detect_from_headers(headers) == :sabredav
    end

    test "returns generic for calendar-access in DAV header" do
      headers = [{"dav", "1, 2, calendar-access"}]
      assert ServerDetector.detect_from_headers(headers) == :generic
    end

    test "returns nil for unrecognized headers" do
      headers = [{"server", "nginx/1.18.0"}]
      assert ServerDetector.detect_from_headers(headers) == nil
    end

    test "handles case-insensitive header names" do
      headers = [{"Server", "Radicale/3.1.8"}]
      assert ServerDetector.detect_from_headers(headers) == :radicale

      headers = [{"X-Powered-By", "NextCloud"}]
      assert ServerDetector.detect_from_headers(headers) == :nextcloud
    end
  end

  describe "get_server_profile/1" do
    test "returns Radicale profile with correct paths" do
      profile = ServerDetector.get_server_profile(:radicale)

      assert profile.type == :radicale
      assert profile.discovery_path == "/{username}/"
      assert profile.calendar_path_pattern == "/{username}/{calendar}/"
      assert profile.event_path_pattern == "/{username}/{calendar}/{uid}.ics"
      assert profile.supports_oauth == false
      assert profile.supports_calendar_color == true
      assert profile.requires_calendar_suffix == true
    end

    test "returns Nextcloud profile with correct paths" do
      profile = ServerDetector.get_server_profile(:nextcloud)

      assert profile.type == :nextcloud
      assert profile.discovery_path == "/remote.php/dav/calendars/{username}/"

      assert profile.calendar_path_pattern ==
               "/remote.php/dav/calendars/{username}/{calendar}/"

      assert profile.event_path_pattern ==
               "/remote.php/dav/calendars/{username}/{calendar}/{uid}.ics"

      assert profile.supports_oauth == true
      assert profile.supports_calendar_color == true
      assert profile.requires_calendar_suffix == false
    end

    test "returns ownCloud profile with correct paths" do
      profile = ServerDetector.get_server_profile(:owncloud)

      assert profile.type == :owncloud
      assert profile.discovery_path == "/remote.php/dav/calendars/{username}/"
      assert profile.supports_oauth == true
    end

    test "returns Baikal profile with correct paths" do
      profile = ServerDetector.get_server_profile(:baikal)

      assert profile.type == :baikal
      assert profile.discovery_path == "/cal.php/calendars/{username}/"
      assert profile.calendar_path_pattern == "/cal.php/calendars/{username}/{calendar}/"
      assert profile.supports_oauth == false
    end

    test "returns SabreDAV profile with correct paths" do
      profile = ServerDetector.get_server_profile(:sabredav)

      assert profile.type == :sabredav
      assert profile.discovery_path == "/calendars/{username}/"
      assert profile.calendar_path_pattern == "/calendars/{username}/{calendar}/"
    end

    test "returns generic CalDAV profile for unknown types" do
      profile = ServerDetector.get_server_profile(:unknown)

      assert profile.type == :generic
      assert profile.discovery_path == "/calendars/{username}/"
      assert profile.calendar_path_pattern == "/calendars/{username}/{calendar}/"
      assert profile.supports_oauth == false
      assert profile.supports_calendar_color == false
    end
  end

  describe "build_discovery_url/3" do
    test "builds correct URL for Radicale" do
      url = ServerDetector.build_discovery_url("https://radicale.example.com", "user", :radicale)
      assert url == "https://radicale.example.com/user/"
    end

    test "builds correct URL for Nextcloud" do
      url = ServerDetector.build_discovery_url("https://cloud.example.com", "user", :nextcloud)
      assert url == "https://cloud.example.com/remote.php/dav/calendars/user/"
    end

    test "builds correct URL for Baikal" do
      url = ServerDetector.build_discovery_url("https://cal.example.com", "user", :baikal)
      assert url == "https://cal.example.com/cal.php/calendars/user/"
    end

    test "builds correct URL for generic CalDAV" do
      url = ServerDetector.build_discovery_url("https://caldav.example.com", "user", :generic)
      assert url == "https://caldav.example.com/calendars/user/"
    end

    test "removes trailing slash from base URL" do
      url = ServerDetector.build_discovery_url("https://radicale.example.com/", "user", :radicale)
      assert url == "https://radicale.example.com/user/"
    end
  end

  describe "build_calendar_url/4" do
    test "builds correct calendar URL for Radicale" do
      url =
        ServerDetector.build_calendar_url(
          "https://radicale.example.com",
          "user",
          "personal",
          :radicale
        )

      assert url == "https://radicale.example.com/user/personal/"
    end

    test "builds correct calendar URL for Nextcloud" do
      url =
        ServerDetector.build_calendar_url(
          "https://cloud.example.com",
          "user",
          "personal",
          :nextcloud
        )

      assert url == "https://cloud.example.com/remote.php/dav/calendars/user/personal/"
    end

    test "builds correct calendar URL for generic CalDAV" do
      url =
        ServerDetector.build_calendar_url(
          "https://caldav.example.com",
          "user",
          "personal",
          :generic
        )

      assert url == "https://caldav.example.com/calendars/user/personal/"
    end
  end

  describe "build_event_url/5" do
    test "builds correct event URL for Radicale" do
      url =
        ServerDetector.build_event_url(
          "https://radicale.example.com",
          "user",
          "personal",
          "event-123",
          :radicale
        )

      assert url == "https://radicale.example.com/user/personal/event-123.ics"
    end

    test "builds correct event URL for Nextcloud" do
      url =
        ServerDetector.build_event_url(
          "https://cloud.example.com",
          "user",
          "personal",
          "event-123",
          :nextcloud
        )

      assert url == "https://cloud.example.com/remote.php/dav/calendars/user/personal/event-123.ics"
    end

    test "adds .ics extension if not present" do
      url =
        ServerDetector.build_event_url(
          "https://caldav.example.com",
          "user",
          "personal",
          "event-123",
          :generic
        )

      assert url == "https://caldav.example.com/calendars/user/personal/event-123.ics"
    end

    test "does not duplicate .ics extension" do
      url =
        ServerDetector.build_event_url(
          "https://caldav.example.com",
          "user",
          "personal",
          "event-123.ics",
          :generic
        )

      assert url == "https://caldav.example.com/calendars/user/personal/event-123.ics"
    end
  end
end
