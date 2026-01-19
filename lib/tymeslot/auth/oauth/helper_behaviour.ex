defmodule Tymeslot.Auth.OAuth.HelperBehaviour do
  @moduledoc """
  Behaviour for OAuth Helper to allow mocking in tests.
  """

  @callback build_oauth_client(atom(), String.t(), String.t()) :: OAuth2.Client.t()
  @callback exchange_code_for_token(OAuth2.Client.t(), String.t()) :: {:ok, OAuth2.Client.t()} | {:error, any()}
  @callback get_user_info(OAuth2.Client.t(), atom()) :: {:ok, map()} | {:error, any()}
end
