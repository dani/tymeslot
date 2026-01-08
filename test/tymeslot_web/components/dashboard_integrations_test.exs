defmodule TymeslotWeb.Components.DashboardIntegrationsTest do
  use TymeslotWeb.ConnCase, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest
  alias Floki
  alias Phoenix.LiveView.JS

  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.CaldavConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.CalendarManagerModal
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.ConfigBase
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.NextcloudConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.RadicaleConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Calendar.SharedFormComponents
  alias TymeslotWeb.Components.Dashboard.Integrations.IntegrationCard
  alias TymeslotWeb.Components.Dashboard.Integrations.IntegrationForm
  alias TymeslotWeb.Components.Dashboard.Integrations.ProviderCard
  alias TymeslotWeb.Components.Dashboard.Integrations.Shared.DeleteIntegrationModal
  alias TymeslotWeb.Components.Dashboard.Integrations.Shared.UIComponents
  alias TymeslotWeb.Components.Dashboard.Integrations.Video.CustomConfig
  alias TymeslotWeb.Components.Dashboard.Integrations.Video.MirotalkConfig

  test "renders integration_card correctly" do
    assigns = %{
      integration: %{
        id: 1,
        name: "My Calendar",
        provider: "google",
        is_active: true,
        is_primary: true,
        is_default: true,
        base_url: nil,
        calendar_list: [%{"id" => "cal1", "name" => "Work", "selected" => true}],
        default_booking_calendar_id: "cal1"
      },
      integration_type: :calendar,
      provider_display_name: "Google Calendar",
      myself: "some-target"
    }

    html = render_component(&IntegrationCard.integration_card/1, assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "My Calendar"
    assert html =~ "Active"
    assert html =~ "Work"
    assert html =~ "Booking Calendar"

    assert Floki.find(doc, "span.status-badge--active") != []
  end

  test "renders integration_card correctly when inactive with no calendars configured" do
    assigns = %{
      integration: %{
        id: 1,
        name: "My Calendar",
        provider: "google",
        is_active: false,
        is_primary: false,
        is_default: false,
        base_url: nil,
        calendar_list: [],
        calendar_paths: [],
        default_booking_calendar_id: nil
      },
      integration_type: :calendar,
      provider_display_name: "Google Calendar",
      myself: "some-target"
    }

    html = render_component(&IntegrationCard.integration_card/1, assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Inactive"
    assert html =~ "Integration is currently disabled"
    assert html =~ "No specific calendars configured"

    # Calendar manage button is only shown for active integrations
    assert Floki.find(doc, "button[phx-click='manage_calendars']") == []
  end

  test "renders integration_card calendar_paths fallback when calendar_list is missing" do
    assigns = %{
      integration: %{
        id: 1,
        name: "My Calendar",
        provider: "caldav",
        is_active: true,
        is_primary: false,
        is_default: false,
        base_url: nil,
        calendar_list: nil,
        calendar_paths: ["/cal1", "/cal2"]
      },
      integration_type: :calendar,
      provider_display_name: "CalDAV",
      myself: "some-target"
    }

    html = render_component(&IntegrationCard.integration_card/1, assigns)
    assert html =~ "Connected to 2 calendars"
  end

  test "renders provider_card correctly" do
    assigns = %{
      provider: "google",
      title: "Google Calendar",
      description: "Sync with Google",
      button_text: "Connect",
      click_event: "connect_google",
      target: "some-target",
      provider_value: "google"
    }

    html = render_component(&ProviderCard.provider_card/1, assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Google Calendar"
    assert html =~ "Sync with Google"
    assert html =~ "Connect"

    assert Floki.find(
             doc,
             "button[phx-click='connect_google'][phx-target='some-target'][phx-value-provider='google']"
           ) != []
  end

  test "renders shared close_button correctly" do
    assigns = %{target: "some-target"}
    html = render_component(&UIComponents.close_button/1, assigns)
    doc = Floki.parse_document!(html)

    assert Floki.find(
             doc,
             "button[phx-click='back_to_providers'][phx-target='some-target'][title='Close']"
           ) != []

    assert Floki.text(doc) =~ "Close"
  end

  test "renders shared loading_spinner correctly" do
    assigns = %{class: "w-10 h-10"}
    html = render_component(&UIComponents.loading_spinner/1, assigns)
    doc = Floki.parse_document!(html)
    assert html =~ "animate-spin"
    assert Floki.find(doc, "svg.w-10.h-10.animate-spin") != []
  end

  test "renders shared form_submit_button correctly" do
    # Non-saving state
    assigns = %{saving: false, text: "Save Me"}
    html = render_component(&UIComponents.form_submit_button/1, assigns)
    doc = Floki.parse_document!(html)
    assert html =~ "Save Me"
    refute html =~ "Saving..."
    assert Floki.find(doc, "button[type='submit'][disabled]") == []

    # Saving state
    assigns = %{saving: true, saving_text: "Saving Now..."}
    html = render_component(&UIComponents.form_submit_button/1, assigns)
    doc = Floki.parse_document!(html)
    assert html =~ "Saving Now..."
    assert html =~ "animate-spin"
    assert Floki.find(doc, "button[type='submit'][disabled]") != []
  end

  test "renders shared secondary_button correctly" do
    assigns = %{target: "some-target", label: "Back", phx_click: "go_back", icon: "hero-x-mark"}
    html = render_component(&UIComponents.secondary_button/1, assigns)
    doc = Floki.parse_document!(html)

    assert Floki.find(doc, "button[phx-click='go_back'][phx-target='some-target']") != []
    assert Floki.text(doc) =~ "Back"
  end

  test "renders delete_integration_modal copy for calendar and video" do
    base_assigns = %{
      id: "delete-integration",
      show: true,
      integration_type: :calendar,
      on_cancel: %JS{},
      on_confirm: %JS{}
    }

    html = render_component(&DeleteIntegrationModal.delete_integration_modal/1, base_assigns)

    assert html =~ "Delete Calendar Integration"
    assert html =~ "calendar data"
    assert html =~ "Delete Integration"

    html =
      render_component(&DeleteIntegrationModal.delete_integration_modal/1, %{
        base_assigns
        | integration_type: :video
      })

    assert html =~ "Delete Video Integration"
    assert html =~ "video conferencing configuration"
    assert html =~ "Delete Integration"
  end

  test "renders integration_form with provider info and base errors" do
    inner_block = [
      %{__slot__: :inner_block, inner_block: fn assigns, _ -> ~H[<input name="x" />] end}
    ]

    assigns = %{
      title: "Add Integration",
      cancel_event: "cancel",
      submit_event: "submit",
      target: "some-target",
      provider_info: "Nextcloud",
      show_errors: true,
      form_errors: %{base: ["Something went wrong"]},
      saving: false,
      submit_text: "Add It",
      inner_block: inner_block
    }

    html = render_component(&IntegrationForm.render/1, assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Add Integration"
    assert html =~ "Provider:"
    assert html =~ "Nextcloud"
    assert html =~ "Something went wrong"
    assert Floki.find(doc, "form[phx-submit='submit'][phx-target='some-target']") != []
    assert Floki.find(doc, "button[type='submit']") != []
    assert html =~ "Add It"
  end

  test "renders integration_form submit button in saving state" do
    inner_block = [
      %{__slot__: :inner_block, inner_block: fn assigns, _ -> ~H[<input name="x" />] end}
    ]

    assigns = %{
      title: "Add Integration",
      cancel_event: "cancel",
      submit_event: "submit",
      target: "some-target",
      provider_info: nil,
      show_errors: false,
      form_errors: %{},
      saving: true,
      submit_text: "Add It",
      inner_block: inner_block
    }

    html = render_component(&IntegrationForm.render/1, assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Adding..."
    assert Floki.find(doc, "button[type='submit'][disabled]") != []
  end

  test "renders shared calendar config_form in discovery and selection modes" do
    base_assigns = %{
      provider: "caldav",
      show_calendar_selection: false,
      discovered_calendars: [],
      discovery_credentials: %{url: "https://example.com/dav", username: "u", password: "p"},
      form_errors: %{},
      form_values: %{"name" => "My CalDAV", "url" => "https://example.com/dav"},
      saving: false,
      target: "parent-target",
      myself: "self-target",
      suggested_name: "Suggested"
    }

    # Discovery mode
    html =
      render_component(&SharedFormComponents.config_form/1, base_assigns)

    doc = Floki.parse_document!(html)

    assert Floki.find(
             doc,
             "form[phx-submit='discover_calendars'][phx-change='track_form_change']"
           ) != []

    assert html =~ "Integration Name"
    assert html =~ "Server URL"
    assert html =~ "Username"
    assert html =~ "Password / App Password"

    assert Floki.find(doc, "button[phx-click='back_to_providers'][phx-target='parent-target']") !=
             []

    # Selection mode
    html =
      render_component(&SharedFormComponents.config_form/1, %{
        base_assigns
        | show_calendar_selection: true,
          discovered_calendars: [%{name: "Work", path: "/cal1"}]
      })

    doc = Floki.parse_document!(html)
    assert Floki.find(doc, "form[phx-submit='add_integration'][phx-target='parent-target']") != []
    assert html =~ "Select calendars to sync:"
    assert html =~ "Work"
    assert html =~ "/cal1"

    assert Floki.find(doc, "input[type='hidden'][name='integration[provider]'][value='caldav']") !=
             []

    assert Floki.find(doc, "input[type='hidden'][name='integration[username]'][value='u']") != []
  end

  test "ConfigBase event handlers update assigns without external calls" do
    socket =
      %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, form_errors: %{url: "bad"}, metadata: %{}, form_values: %{}}
      }

    # track_form_change
    {:noreply, socket} =
      CaldavConfig.handle_event(
        "track_form_change",
        %{"integration" => %{"name" => "My CalDAV"}},
        socket
      )

    assert socket.assigns.form_values["name"] == "My CalDAV"

    # validate_field clears existing url error for valid input
    {:noreply, socket} =
      CaldavConfig.handle_event(
        "validate_field",
        %{"field" => "url", "integration" => %{"url" => "https://example.com/dav"}},
        socket
      )

    refute Map.has_key?(socket.assigns.form_errors, :url)

    # discover_calendars with invalid credentials should surface validation errors and stop
    {:noreply, socket} =
      CaldavConfig.handle_event(
        "discover_calendars",
        %{
          "integration" => %{
            "url" => "https://example.com/dav",
            "username" => "",
            "password" => ""
          }
        },
        socket
      )

    assert socket.assigns.saving == false
    assert is_map(socket.assigns.form_errors)

    assert Map.has_key?(socket.assigns.form_errors, :username) or
             Map.has_key?(socket.assigns.form_errors, :password)
  end

  test "renders calendar manager modal for primary vs sync-only integrations" do
    primary_integration = %{
      id: 10,
      provider: "caldav",
      is_active: true,
      is_primary: true,
      default_booking_calendar_id: "cal1",
      calendar_list: [
        %{
          "id" => "cal1",
          "name" => "Work",
          "selected" => true,
          "primary" => true,
          "owner" => "me"
        }
      ]
    }

    html =
      render_component(&CalendarManagerModal.render/1, %{
        show: true,
        parent: "parent-target",
        myself: "modal-target",
        loading_calendars: false,
        managing_integration: primary_integration
      })

    doc = Floki.parse_document!(html)
    assert html =~ "Manage Integration"
    assert html =~ "Select calendars to sync:"
    assert html =~ "Where should new bookings be created?"
    assert Floki.find(doc, "select[name='calendars[default_booking_calendar]']") != []
    assert Floki.find(doc, "button[form='calendar-selection-form']") != []

    sync_only_integration = %{primary_integration | is_primary: false}

    html =
      render_component(&CalendarManagerModal.render/1, %{
        show: true,
        parent: "parent-target",
        myself: "modal-target",
        loading_calendars: false,
        managing_integration: sync_only_integration
      })

    doc = Floki.parse_document!(html)
    assert html =~ "Sync-Only Calendar"

    assert Floki.find(
             doc,
             "button[phx-click='set_as_primary'][phx-target='parent-target'][phx-value-id='10']"
           ) != []

    assert Floki.find(doc, "select[name='calendars[default_booking_calendar]']") == []
  end

  test "renders calendar provider config headers and provider hidden fields" do
    base_assigns = %{
      target: "parent-target",
      myself: "self-target",
      saving: false,
      form_values: %{},
      form_errors: %{}
    }

    html = render_component(&CaldavConfig.render/1, base_assigns)
    assert html =~ "Setup CalDAV Calendar"
    assert html =~ "Discover My Calendars"
    assert html =~ ~s(name="integration[provider]" value="caldav")

    html = render_component(&NextcloudConfig.render/1, base_assigns)
    assert html =~ "Setup Nextcloud Calendar"
    assert html =~ "Discover My Calendars"
    assert html =~ ~s(name="integration[provider]" value="nextcloud")

    html = render_component(&RadicaleConfig.render/1, base_assigns)
    assert html =~ "Setup Radicale Calendar"
    assert html =~ "Discover My Calendars"
    assert html =~ ~s(name="integration[provider]" value="radicale")
  end

  test "renders video provider configs" do
    base_assigns = %{
      target: "parent-target",
      saving: false,
      form_values: %{},
      form_errors: %{}
    }

    html = render_component(&MirotalkConfig.render/1, base_assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Setup MiroTalk P2P"

    assert Floki.find(doc, "input[type='hidden'][name='integration[provider]'][value='mirotalk']") !=
             []

    assert html =~ "API Key"
    assert html =~ "Base URL"

    html = render_component(&CustomConfig.render/1, base_assigns)
    doc = Floki.parse_document!(html)

    assert html =~ "Setup Custom Video Link"

    assert Floki.find(doc, "input[type='hidden'][name='integration[provider]'][value='custom']") !=
             []

    assert html =~ "Video Meeting URL"
  end

  test "ConfigBase macro can be exercised at runtime" do
    # credo:disable-for-lines:2 Credo.Check.Warning.UnsafeToAtom
    module_name =
      Module.concat(__MODULE__, "ConfigBaseRuntime#{System.unique_integer([:positive])}")

    code = """
    defmodule #{module_name} do
      use #{ConfigBase}, provider: :caldav, default_name: "X"
    end
    """

    [{compiled, _bin}] = Code.compile_string(code)
    assert compiled == module_name
    assert function_exported?(module_name, :assign_config_defaults, 1)
  end
end
