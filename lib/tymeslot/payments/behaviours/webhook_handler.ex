defmodule Tymeslot.Payments.Behaviours.WebhookHandler do
  @moduledoc """
  Behaviour for Stripe webhook event handlers.

  Implement this behaviour for each type of webhook event that needs processing.
  """

  @type event :: map()
  @type object :: map()
  @type result :: {:ok, atom()} | {:error, atom() | Exception.t(), String.t() | nil}

  @doc """
  Processes a webhook event of a specific type.

  Returns a standardized result tuple with a status atom indicating success or failure.
  """
  @callback process(event(), object()) :: result()

  @doc """
  Returns whether this handler can process the given event type.

  Used by the registry to determine which handler to use.
  """
  @callback can_handle?(String.t()) :: boolean()

  @doc """
  Validates that the webhook object contains all required fields for processing.

  Returns :ok if valid, or {:error, reason} if invalid.
  """
  @callback validate(object()) :: :ok | {:error, atom(), String.t()}

  @optional_callbacks [validate: 1]
end
