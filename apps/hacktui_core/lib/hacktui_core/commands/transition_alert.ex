defmodule HacktuiCore.Commands.TransitionAlert do
  @moduledoc """
  Command contract for transitioning an alert between lifecycle states.
  """

  @enforce_keys [:alert_id, :from_state, :to_state, :reason, :actor]
  defstruct [:alert_id, :from_state, :to_state, :reason, :actor]

  @type t :: %__MODULE__{
          alert_id: String.t(),
          from_state: atom(),
          to_state: atom(),
          reason: String.t(),
          actor: HacktuiCore.ActorRef.t()
        }
end
