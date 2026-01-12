defmodule Tymeslot.Security.WebhookInputProcessor do
  @moduledoc """
  Validates and sanitizes webhook input from user forms.

  Ensures webhook configuration is safe and valid before
  saving to the database.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.DatabaseSchemas.WebhookSchema
  alias Tymeslot.Security.RateLimiter

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:url, :string)
    field(:secret, :string)
    field(:events, {:array, :string}, default: [])
  end

  @doc """
  Validates webhook form input.

  Returns {:ok, sanitized_params} or {:error, errors_map}
  """
  @spec validate_webhook_form(map(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def validate_webhook_form(params, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_form", metadata) do
      %__MODULE__{}
      |> cast(params, [:name, :url, :secret, :events])
      |> validate_required([:name, :url])
      |> validate_length(:name, min: 1, max: 255)
      |> validate_length(:url, min: 1, max: 2048)
      |> validate_url_format()
      |> validate_events_list()
      |> apply_action(:validate)
      |> case do
        {:ok, validated} ->
          {:ok, Map.from_struct(validated)}

        {:error, changeset} ->
          {:error, translate_errors(changeset)}
      end
    else
      {:error, :rate_limited} ->
        {:error, %{form: "Too many requests. Please slow down."}}
    end
  end

  @doc """
  Validates a webhook name update.
  """
  @spec validate_name_update(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_name_update(name, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_name", metadata) do
      %__MODULE__{}
      |> cast(%{"name" => name}, [:name])
      |> validate_required([:name])
      |> validate_length(:name, min: 1, max: 255)
      |> apply_action(:validate)
      |> case do
        {:ok, validated} -> {:ok, validated.name}
        {:error, changeset} -> {:error, get_first_error(changeset, :name)}
      end
    else
      {:error, :rate_limited} ->
        {:error, "Too many requests. Please slow down."}
    end
  end

  @doc """
  Validates a webhook URL update.
  """
  @spec validate_url_update(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_url_update(url, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_url", metadata) do
      %__MODULE__{}
      |> cast(%{"url" => url}, [:url])
      |> validate_required([:url])
      |> validate_length(:url, min: 1, max: 2048)
      |> validate_url_format()
      |> apply_action(:validate)
      |> case do
        {:ok, validated} -> {:ok, validated.url}
        {:error, changeset} -> {:error, get_first_error(changeset, :url)}
      end
    else
      {:error, :rate_limited} ->
        {:error, "Too many requests. Please slow down."}
    end
  end

  # Private functions

  defp validate_url_format(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      case WebhookSchema.validate_url_format(url) do
        :ok -> []
        {:error, msg} -> [{:url, String.capitalize(msg)}]
      end
    end)
  end

  defp validate_events_list(changeset) do
    validate_change(changeset, :events, fn :events, events ->
      valid_events = WebhookSchema.valid_events()

      cond do
        Enum.empty?(events) ->
          [{:events, "At least one event must be selected"}]

        true ->
          invalid_events = Enum.reject(events, &(&1 in valid_events))

          if Enum.empty?(invalid_events) do
            []
          else
            [{:events, "Invalid events: #{Enum.join(invalid_events, ", ")}"}]
          end
      end
    end)
  end

  defp check_rate_limit(bucket_key, _metadata) do
    case RateLimiter.check_rate_limit(bucket_key, 60, 60_000) do
      :ok -> :ok
      {:error, _} -> {:error, :rate_limited}
    end
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> {k, List.first(v)} end)
    |> Map.new()
  end

  defp get_first_error(changeset, field) do
    case changeset.errors[field] do
      {msg, opts} ->
        Regex.replace(~r/%{(\w+)}/, msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)

      _ ->
        "Invalid input"
    end
  end
end
