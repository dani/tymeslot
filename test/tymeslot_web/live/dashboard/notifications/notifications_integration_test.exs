defmodule TymeslotWeb.Dashboard.Notifications.NotificationsIntegrationTest do
  use TymeslotWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Tymeslot.AuthTestHelpers
  import Tymeslot.TestFixtures
  alias Tymeslot.DatabaseQueries.UserQueries
  alias Tymeslot.Webhooks

  setup %{conn: conn} do
    # Create a user and log them in
    user = create_user_fixture()
    {:ok, user} = UserQueries.mark_onboarding_complete(user)

    conn = log_in_user(conn, user)
    {:ok, conn: conn, user: user}
  end

  describe "Webhooks flow" do
    test "can create, edit, and delete a webhook", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, "/dashboard/notifications")

      # 1. Initial empty state
      assert render(view) =~ "No Webhooks Yet"

      # 2. Open create form
      view
      |> element("button", "Create Your First Webhook")
      |> render_click()

      assert render(view) =~ "Create Webhook"

      # 3. Fill and submit create form
      view
      |> form("#webhook-form", %{
        "webhook" => %{
          "name" => "My n8n Webhook",
          "url" => "https://example.com/webhook",
          "events" => ["meeting.created"]
        }
      })
      |> render_submit()

      assert render(view) =~ "Webhook created successfully"
      assert render(view) =~ "My n8n Webhook"
      assert render(view) =~ "meeting.created"

      # Verify DB
      [webhook] = Webhooks.list_webhooks(user.id)
      assert webhook.name == "My n8n Webhook"
      assert webhook.url == "https://example.com/webhook"
      assert webhook.is_active

      # 4. Toggle status
      view
      |> element("button[role='switch']")
      |> render_click()

      assert render(view) =~ "Webhook status updated"
      assert render(view) =~ "Disabled"

      [webhook] = Webhooks.list_webhooks(user.id)
      refute webhook.is_active

      # 5. Open edit form
      view
      |> element("button[title='Edit Webhook']")
      |> render_click()

      assert render(view) =~ "Edit Webhook"

      # 6. Update webhook
      view
      |> form("#webhook-form", %{
        "webhook" => %{
          "name" => "Updated Webhook Name",
          "url" => "https://example.com/updated",
          "events" => ["meeting.created", "meeting.cancelled"]
        }
      })
      |> render_submit()

      assert render(view) =~ "Webhook updated successfully"
      assert render(view) =~ "Updated Webhook Name"

      [webhook] = Webhooks.list_webhooks(user.id)
      assert webhook.name == "Updated Webhook Name"
      assert webhook.url == "https://example.com/updated"
      assert "meeting.cancelled" in webhook.events

      # 7. Delete webhook
      view
      |> element("button[title='Delete Webhook']")
      |> render_click()

      assert render(view) =~ "Delete Webhook?"

      view
      |> element("button", "Delete Webhook")
      |> render_click()


      assert render(view) =~ "Webhook deleted successfully"
      assert render(view) =~ "No Webhooks Yet"

      assert Webhooks.list_webhooks(user.id) == []
    end

    test "validation errors are shown", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/notifications")

      view
      |> element("button", "Create Your First Webhook")
      |> render_click()

      # Submit empty form
      view
      |> form("#webhook-form", %{
        "webhook" => %{
          "name" => "",
          "url" => "not-a-url"
        }
      })
      |> render_submit()

      # The errors are returned from WebhookInputProcessor via NotificationSettingsComponent
      assert render(view) =~ "Name cannot be empty"
      assert render(view) =~ "Must start with http:// or https://"
    end
  end
end
