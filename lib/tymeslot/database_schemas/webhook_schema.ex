defmodule Tymeslot.DatabaseSchemas.WebhookSchema do
  @moduledoc """
  Ecto schema for webhooks.

  Allows users to configure HTTP endpoints that receive notifications
  when specific booking events occur (created, cancelled, rescheduled, etc.).
  Enables integration with automation tools like n8n, Zapier, Make.com.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.Security.Encryption

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          name: String.t() | nil,
          url: String.t() | nil,
          secret_encrypted: binary() | nil,
          events: [String.t()],
          is_active: boolean(),
          last_triggered_at: DateTime.t() | nil,
          last_status: String.t() | nil,
          failure_count: integer(),
          disabled_at: DateTime.t() | nil,
          disabled_reason: String.t() | nil,
          user: Tymeslot.DatabaseSchemas.UserSchema.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "webhooks" do
    field(:name, :string)
    field(:url, :string)
    field(:secret_encrypted, :binary)
    field(:events, {:array, :string}, default: [])
    field(:is_active, :boolean, default: true)
    field(:last_triggered_at, :utc_datetime)
    field(:last_status, :string)
    field(:failure_count, :integer, default: 0)
    field(:disabled_at, :utc_datetime)
    field(:disabled_reason, :string)

    # Virtual field for decrypted secret
    field(:secret, :string, virtual: true)

    belongs_to(:user, Tymeslot.DatabaseSchemas.UserSchema)

    timestamps(type: :utc_datetime)
  end

  @valid_events [
    "meeting.created",
    "meeting.cancelled",
    "meeting.rescheduled"
  ]

  @required_fields [:name, :url, :user_id]
  @optional_fields [
    :secret,
    :events,
    :is_active,
    :last_triggered_at,
    :last_status,
    :failure_count,
    :disabled_at,
    :disabled_reason
  ]

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:url, min: 1, max: 2048)
    |> validate_url()
    |> validate_events()
    |> encrypt_secret()
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Decrypts the secret field.
  """
  @spec decrypt_secret(t()) :: t()
  def decrypt_secret(%__MODULE__{} = webhook) do
    %{webhook | secret: Encryption.decrypt(webhook.secret_encrypted)}
  end

  @doc """
  Returns all valid event types
  """
  @spec valid_events() :: [String.t()]
  def valid_events, do: @valid_events

  @doc """
  Checks if webhook should be active (not disabled by failures)
  """
  @spec should_be_active?(t()) :: boolean()
  def should_be_active?(%__MODULE__{is_active: false}), do: false
  def should_be_active?(%__MODULE__{disabled_at: disabled}) when not is_nil(disabled), do: false
  def should_be_active?(%__MODULE__{failure_count: count}) when count >= 10, do: false
  def should_be_active?(_), do: true

  @doc """
  Checks if webhook is subscribed to a specific event
  """
  @spec subscribed_to?(t(), String.t()) :: boolean()
  def subscribed_to?(%__MODULE__{events: events}, event_type) do
    event_type in events
  end

  # Private functions

  @doc """
  Validates a webhook URL string.
  Returns :ok or {:error, message}
  """
  @spec validate_url_format(String.t()) :: :ok | {:error, String.t()}
  def validate_url_format(url) when is_binary(url) do
    cond do
      not String.starts_with?(url, "http://") and not String.starts_with?(url, "https://") ->
        {:error, "must start with http:// or https://"}

      in_production?() and String.starts_with?(url, "http://") ->
        {:error, "must use HTTPS in production"}

      in_production?() and is_private_url?(url) ->
        {:error, "cannot use private or local network addresses in production"}

      not in_production?() and (String.contains?(url, "localhost") or String.contains?(url, "127.0.0.1")) ->
        # Allow localhost in dev/test
        :ok

      true ->
        :ok
    end
  end

  defp validate_url(changeset) do
    case get_change(changeset, :url) do
      nil ->
        changeset

      url ->
        case validate_url_format(url) do
          :ok -> changeset
          {:error, msg} -> add_error(changeset, :url, msg)
        end
    end
  end

  defp is_private_url?(url) do
    case URI.parse(url).host do
      nil ->
        true

      host ->
        # Check for literal local hostnames
        if host in ["localhost", "127.0.0.1", "::1"] do
          true
        else
          # Resolve hostname and check IP ranges
          case :inet.getaddr(to_charlist(host), :inet) do
            {:ok, {10, _, _, _}} -> true
            {:ok, {172, x, _, _}} when x >= 16 and x <= 31 -> true
            {:ok, {192, 168, _, _}} -> true
            {:ok, {127, _, _, _}} -> true
            {:ok, {169, 254, _, _}} -> true
            {:ok, {0, 0, 0, 0}} -> true
            _ -> false
          end
        end
    end
  end

  defp validate_events(changeset) do
    case get_change(changeset, :events) do
      nil ->
        changeset

      [] ->
        add_error(changeset, :events, "must select at least one event")

      events ->
        invalid_events = Enum.reject(events, &(&1 in @valid_events))

        if Enum.empty?(invalid_events) do
          changeset
        else
          add_error(
            changeset,
            :events,
            "contains invalid events: #{Enum.join(invalid_events, ", ")}"
          )
        end
    end
  end

  defp encrypt_secret(changeset) do
    case get_change(changeset, :secret) do
      nil ->
        changeset

      "" ->
        changeset

      secret ->
        changeset
        |> put_change(:secret_encrypted, Encryption.encrypt(secret))
        |> delete_change(:secret)
    end
  end

  defp in_production? do
    Application.get_env(:tymeslot, :environment) == :prod
  end
end
