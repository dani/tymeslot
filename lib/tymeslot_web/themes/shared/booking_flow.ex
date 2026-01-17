defmodule TymeslotWeb.Themes.Shared.BookingFlow do
  @moduledoc """
  Shared booking orchestration for all scheduling themes.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Phoenix.Component
  alias Tymeslot.Security.FormValidation
  alias TymeslotWeb.Live.Scheduling.Handlers.BookingSubmissionHandlerComponent
  alias TymeslotWeb.Live.Scheduling.Helpers

  require Logger

  @type transition_fun :: (Phoenix.LiveView.Socket.t(), atom(), map() ->
                             Phoenix.LiveView.Socket.t())

  @doc """
  Handles booking submission from the LiveView.
  This centralizes the validation and submission logic by delegating to
  the shared BookingSubmissionHandlerComponent.
  """
  @spec submit_booking(Phoenix.LiveView.Socket.t(), map(), transition_fun()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def submit_booking(socket, booking_params, transition_fun) do
    case BookingSubmissionHandlerComponent.submit_booking(socket, booking_params) do
      {:ok, socket} ->
        # On success, transition to confirmation
        {:noreply, transition_fun.(socket, :confirmation, %{})}

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  @spec handle_form_validation(Phoenix.LiveView.Socket.t(), map()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_form_validation(socket, booking_params) do
    case FormValidation.validate_booking_form(booking_params) do
      {:ok, sanitized_params} ->
        form = Component.to_form(sanitized_params)

        socket =
          socket
          |> assign(:form, form)
          |> assign(:validation_errors, [])

        {:noreply, socket}

      {:error, errors} ->
        {:ok, sanitized_params} =
          FormValidation.sanitize_booking_params(booking_params)

        form = Component.to_form(sanitized_params)

        socket =
          socket
          |> assign(:form, form)
          |> Helpers.assign_form_errors(errors)

        {:noreply, socket}
    end
  end
end
