defmodule TymeslotWeb.Themes.Rhythm.Scheduling.StateMachine do
  @moduledoc """
  State machine helpers for the Rhythm scheduling flow.
  """
  alias TymeslotWeb.Themes.Shared.StateMachineHelpers

  @states StateMachineHelpers.default_states()

  @spec determine_initial_state(atom()) :: atom()
  def determine_initial_state(live_action),
    do: StateMachineHelpers.determine_initial_state(live_action)

  @spec can_navigate_to_step?(Phoenix.LiveView.Socket.t(), atom()) :: boolean()
  def can_navigate_to_step?(socket, target_state),
    do: StateMachineHelpers.can_navigate_to_step?(socket, target_state, @states)

  @spec validate_state_transition(Phoenix.LiveView.Socket.t(), atom(), atom()) ::
          :ok | {:error, String.t()}
  def validate_state_transition(socket, current_state, next_state),
    do: StateMachineHelpers.validate_state_transition(socket, current_state, next_state)
end
