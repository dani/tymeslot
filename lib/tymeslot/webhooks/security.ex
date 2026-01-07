defmodule Tymeslot.Webhooks.Security do
  @moduledoc """
  Security utilities for webhook signatures.

  Implements HMAC-SHA256 signature generation for webhook payloads,
  allowing recipients to verify that webhooks are genuinely from Tymeslot.
  """

  alias Plug.Crypto

  @doc """
  Generates an HMAC-SHA256 signature for a payload.

  The signature is computed as:
    HMAC-SHA256(secret, JSON-encoded payload)

  Recipients can verify the webhook by computing the same signature
  and comparing it to the X-Tymeslot-Signature header.

  ## Examples

      iex> payload = %{event: "meeting.created", data: %{}}
      iex> Security.generate_signature(payload, "my-secret-key")
      "a1b2c3d4e5f6..."

  """
  @spec generate_signature(map(), String.t()) :: String.t()
  def generate_signature(payload, secret) when is_map(payload) and is_binary(secret) do
    payload
    |> Jason.encode!()
    |> generate_signature_from_string(secret)
  end

  @doc """
  Generates an HMAC-SHA256 signature for a string payload.
  """
  @spec generate_signature_from_string(String.t(), String.t()) :: String.t()
  def generate_signature_from_string(payload_string, secret)
      when is_binary(payload_string) and is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, payload_string)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a webhook signature.

  Returns true if the signature is valid, false otherwise.
  """
  @spec verify_signature(String.t(), String.t(), String.t()) :: boolean()
  def verify_signature(payload_string, signature, secret) do
    expected_signature = generate_signature_from_string(payload_string, secret)
    Crypto.secure_compare(signature, expected_signature)
  end

  @doc """
  Generates a random webhook secret.
  """
  @spec generate_secret() :: String.t()
  def generate_secret do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
  end
end
