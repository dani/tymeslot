defmodule Tymeslot.Security.WebhookInputProcessor do
  @moduledoc """
  Validates and sanitizes webhook input from user forms.

  Ensures webhook configuration is safe and valid before
  saving to the database.
  """

  alias Tymeslot.DatabaseSchemas.WebhookSchema
  alias Tymeslot.Security.RateLimiter

  @doc """
  Validates webhook form input.

  Returns {:ok, sanitized_params} or {:error, errors_map}
  """
  @spec validate_webhook_form(map(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def validate_webhook_form(params, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_form", metadata),
         {:ok, sanitized} <- sanitize_and_validate(params) do
      {:ok, sanitized}
    else
      {:error, :rate_limited} ->
        {:error, %{form: "Too many requests. Please slow down."}}

      {:error, errors} when is_map(errors) ->
        {:error, errors}

      {:error, error} ->
        {:error, %{form: error}}
    end
  end

  @doc """
  Validates a webhook name update.
  """
  @spec validate_name_update(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_name_update(name, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_name", metadata),
         {:ok, sanitized} <- validate_name(name) do
      {:ok, sanitized}
    else
      {:error, :rate_limited} ->
        {:error, "Too many requests. Please slow down."}

      error ->
        error
    end
  end

  @doc """
  Validates a webhook URL update.
  """
  @spec validate_url_update(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def validate_url_update(url, opts \\ []) do
    metadata = Keyword.get(opts, :metadata, %{})

    with :ok <- check_rate_limit("webhook_url", metadata),
         {:ok, sanitized} <- validate_url(url) do
      {:ok, sanitized}
    else
      {:error, :rate_limited} ->
        {:error, "Too many requests. Please slow down."}

      error ->
        error
    end
  end

  # Private functions

  defp sanitize_and_validate(params) do
    errors = %{}

    with {:ok, name, errors} <- validate_and_add(:name, params, errors),
         {:ok, url, errors} <- validate_and_add(:url, params, errors),
         {:ok, secret, errors} <- validate_and_add(:secret, params, errors),
         {:ok, events, errors} <- validate_and_add(:events, params, errors) do
      if map_size(errors) > 0 do
        {:error, errors}
      else
        {:ok,
         %{
           name: name,
           url: url,
           secret: secret,
           events: events
         }}
      end
    else
      {:error, errors} -> {:error, errors}
    end
  end

  defp validate_and_add(:name, params, errors) do
    case Map.get(params, "name") do
      nil ->
        {:error, Map.put(errors, :name, "Name is required")}

      name ->
        case validate_name(name) do
          {:ok, sanitized} -> {:ok, sanitized, errors}
          {:error, msg} -> {:error, Map.put(errors, :name, msg)}
        end
    end
  end

  defp validate_and_add(:url, params, errors) do
    case Map.get(params, "url") do
      nil ->
        {:error, Map.put(errors, :url, "URL is required")}

      url ->
        case validate_url(url) do
          {:ok, sanitized} -> {:ok, sanitized, errors}
          {:error, msg} -> {:error, Map.put(errors, :url, msg)}
        end
    end
  end

  defp validate_and_add(:secret, params, errors) do
    # Secret is optional
    case Map.get(params, "secret") do
      nil -> {:ok, nil, errors}
      "" -> {:ok, nil, errors}
      secret -> {:ok, String.trim(secret), errors}
    end
  end

  defp validate_and_add(:events, params, errors) do
    case Map.get(params, "events") do
      nil ->
        {:error, Map.put(errors, :events, "At least one event must be selected")}

      [] ->
        {:error, Map.put(errors, :events, "At least one event must be selected")}

      events when is_list(events) ->
        case validate_events(events) do
          {:ok, validated} -> {:ok, validated, errors}
          {:error, msg} -> {:error, Map.put(errors, :events, msg)}
        end

      _ ->
        {:error, Map.put(errors, :events, "Invalid events format")}
    end
  end

  defp validate_name(name) when is_binary(name) do
    sanitized = String.trim(name)

    cond do
      String.length(sanitized) < 1 ->
        {:error, "Name cannot be empty"}

      String.length(sanitized) > 255 ->
        {:error, "Name is too long (maximum 255 characters)"}

      true ->
        {:ok, sanitized}
    end
  end

  defp validate_name(_), do: {:error, "Invalid name format"}

  defp validate_url(url) when is_binary(url) do
    sanitized = String.trim(url)

    cond do
      String.length(sanitized) < 1 ->
        {:error, "URL cannot be empty"}

      String.length(sanitized) > 2048 ->
        {:error, "URL is too long (maximum 2048 characters)"}

      true ->
        case WebhookSchema.validate_url_format(sanitized) do
          :ok -> {:ok, sanitized}
          {:error, msg} -> {:error, String.capitalize(msg)}
        end
    end
  end

  defp validate_url(_), do: {:error, "Invalid URL format"}

  defp validate_events(events) when is_list(events) do
    valid_events = WebhookSchema.valid_events()
    invalid_events = Enum.reject(events, &(&1 in valid_events))

    if Enum.empty?(invalid_events) do
      {:ok, events}
    else
      {:error, "Invalid events: #{Enum.join(invalid_events, ", ")}"}
    end
  end

  defp validate_events(_), do: {:error, "Events must be a list"}

  defp check_rate_limit(bucket_key, _metadata) do
    case RateLimiter.check_rate_limit(bucket_key, 60, 60_000) do
      :ok -> :ok
      {:error, _} -> {:error, :rate_limited}
    end
  end
end
