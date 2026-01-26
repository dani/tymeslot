defmodule Tymeslot.DatabaseSchemas.WebhookSchemaTest do
  use Tymeslot.DataCase, async: true

  alias Tymeslot.DatabaseSchemas.WebhookSchema
  alias Tymeslot.Security.Encryption

  describe "generate_token/1" do
    test "generates a new token if one doesn't exist" do
      changeset = WebhookSchema.changeset(%WebhookSchema{}, %{
        name: "Test Webhook",
        url: "https://example.com/webhook",
        user_id: 1,
        events: ["meeting.created"]
      })

      assert token = get_change(changeset, :webhook_token)
      assert String.starts_with?(token, "ts_")
      assert get_change(changeset, :webhook_token_encrypted)
    end

    test "regenerates token when webhook_token is set to nil" do
      # Simulate an existing webhook
      webhook = %WebhookSchema{
        webhook_token_encrypted: Encryption.encrypt("old_token")
      }

      # Passing nil should trigger regeneration
      changeset = WebhookSchema.changeset(webhook, %{webhook_token: nil})

      assert token = get_change(changeset, :webhook_token)
      assert token != "old_token"
      assert String.starts_with?(token, "ts_")
      assert new_encrypted = get_change(changeset, :webhook_token_encrypted)
      assert Encryption.decrypt(new_encrypted) == token
    end

    test "does not regenerate token if it already exists and not changing" do
      encrypted = Encryption.encrypt("existing_token")
      webhook = %WebhookSchema{
        webhook_token_encrypted: encrypted
      }

      changeset = WebhookSchema.changeset(webhook, %{name: "Updated Name"})

      refute get_change(changeset, :webhook_token)
      assert get_field(changeset, :webhook_token_encrypted) == encrypted
    end
  end
end
