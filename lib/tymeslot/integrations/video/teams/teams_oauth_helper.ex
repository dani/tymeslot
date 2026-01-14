defmodule Tymeslot.Integrations.Video.Teams.TeamsOAuthHelper do
  @moduledoc """
  Helper module for Microsoft Teams OAuth flow for video integrations.

  This module provides functions to generate OAuth URLs and handle
  the OAuth callback   for Microsoft Graph API integration specifically
  for Teams meeting creation.
  """

  @behaviour Tymeslot.Integrations.Video.Teams.TeamsOAuthHelperBehaviour

  alias Tymeslot.Infrastructure.Logging.Redactor
  alias Tymeslot.Infrastructure.Retry
  alias Tymeslot.Integrations.Common.OAuth.State
  alias Tymeslot.Integrations.Common.OAuth.TokenExchange
  alias Tymeslot.Integrations.Shared.MicrosoftConfig

  require Logger

  @teams_scope "https://graph.microsoft.com/OnlineMeetings.ReadWrite https://graph.microsoft.com/User.Read offline_access openid profile"
  @oauth_base_url "https://login.microsoftonline.com/common/oauth2/v2.0"
  @token_url "#{@oauth_base_url}/token"

  @doc """
  Generates the OAuth authorization URL for Microsoft Teams.
  """
  @spec authorization_url(term(), String.t()) :: String.t()
  def authorization_url(user_id, redirect_uri) do
    state = generate_state(user_id)

    params = %{
      client_id: MicrosoftConfig.client_id(),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: @teams_scope,
      state: state,
      response_mode: "query",
      prompt: "select_account"
    }

    query_string = URI.encode_query(params)
    "#{@oauth_base_url}/authorize?" <> query_string
  end

  @doc """
  Exchanges authorization code for access and refresh tokens.
  Also fetches the user profile to get the Microsoft user ID and tenant ID.
  """
  @spec exchange_code_for_tokens(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, String.t()}
  def exchange_code_for_tokens(code, redirect_uri, state) do
    with {:ok, user_id} <- verify_state(state),
         {:ok, tokens} <- fetch_tokens(code, redirect_uri),
         {:ok, profile} <- fetch_user_profile(tokens.access_token) do
      tenant_id = extract_tenant_id_from_id_token(tokens[:id_token]) || profile["tenant_id"] || "common"

      {:ok,
       Map.merge(tokens, %{
         user_id: user_id,
         teams_user_id: profile["id"],
         tenant_id: tenant_id
       })}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp extract_tenant_id_from_id_token(nil), do: nil

  defp extract_tenant_id_from_id_token(id_token) do
    case String.split(id_token, ".") do
      [_, payload_b64, _] ->
        with {:ok, payload_json} <- Base.url_decode64(payload_b64, padding: false),
             {:ok, %{"tid" => tenant_id}} <- Jason.decode(payload_json) do
          tenant_id
        else
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp fetch_user_profile(token) do
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    Retry.with_backoff(fn ->
      case http_client().get("https://graph.microsoft.com/v1.0/me", headers, []) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          case Jason.decode(body) do
            {:ok, %{"id" => id} = profile} when is_binary(id) and id != "" ->
              {:ok, profile}

            {:ok, _} ->
              {:error, "Microsoft profile missing unique ID"}

            {:error, _} ->
              {:error, "Invalid JSON response from Microsoft profile API"}
          end

        {:ok, %HTTPoison.Response{status_code: status, body: body}} ->
          Logger.error("Failed to fetch Microsoft user profile", status: status, body: body)
          {:error, "Failed to fetch user profile: HTTP #{status}"}

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, "Network error fetching profile: #{inspect(reason)}"}
      end
    end)
  end

  defp http_client do
    Application.get_env(:tymeslot, :http_client_module, Tymeslot.Infrastructure.HTTPClient)
  end

  @doc """
  Refreshes an access token using the refresh token.
  """
  @spec refresh_access_token(String.t(), String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def refresh_access_token(refresh_token, current_scope \\ nil) do
    scope = current_scope || @teams_scope

    body = %{
      refresh_token: refresh_token,
      client_id: MicrosoftConfig.client_id(),
      client_secret: MicrosoftConfig.client_secret(),
      grant_type: "refresh_token",
      scope: scope
    }

    case TokenExchange.refresh_access_token(@token_url, body,
           fallback_refresh_token: refresh_token,
           fallback_scope: scope
         ) do
      {:ok, tokens} ->
        {:ok, tokens}

      {:error, {:http_error, status, body}} ->
        Logger.error("Teams OAuth token refresh failed",
          status: status,
          response_body: Redactor.redact_and_truncate(body)
        )

        {:error, "Token refresh failed: HTTP #{status} (see logs for details)"}

      {:error, {:network_error, reason}} ->
        Logger.error("Network error during Teams token refresh", reason: inspect(reason))
        {:error, "Network error during token refresh: #{inspect(reason)}"}
    end
  end

  @doc """
  Validates if a token is still valid or needs refresh.
  """
  @spec validate_token(map()) :: {:ok, :valid | :needs_refresh} | {:error, String.t()}
  def validate_token(config) do
    case Map.get(config, :token_expires_at) do
      nil ->
        {:error, "No token expiration information"}

      expires_at ->
        # Consider token expired if it expires within 5 minutes
        buffer_time = DateTime.add(DateTime.utc_now(), 300, :second)

        if DateTime.compare(expires_at, buffer_time) == :gt do
          {:ok, :valid}
        else
          {:ok, :needs_refresh}
        end
    end
  end

  # Private functions

  defp fetch_tokens(code, redirect_uri) do
    TokenExchange.exchange_code_for_tokens(
      code,
      redirect_uri,
      @token_url,
      MicrosoftConfig.client_id(),
      MicrosoftConfig.client_secret(),
      @teams_scope
    )
  end

  defp generate_state(user_id) do
    State.generate(user_id, MicrosoftConfig.state_secret())
  end

  defp verify_state(state) when is_binary(state) do
    State.validate(state, MicrosoftConfig.state_secret())
  end

  defp verify_state(_), do: {:error, "Invalid state parameter"}
end
