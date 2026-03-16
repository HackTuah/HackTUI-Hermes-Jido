defmodule HacktuiCore.Commands.TransitionCase do
  @moduledoc """
  Command contract for transitioning a case between lifecycle states.
  """

  @enforce_keys [:case_id, :from_status, :to_status, :reason, :actor]
  defstruct [:case_id, :from_status, :to_status, :reason, :actor]

  @type t :: %__MODULE__{
          case_id: String.t(),
          from_status: atom(),
          to_status: atom(),
          reason: String.t(),
          actor: HacktuiCore.ActorRef.t()
        }
end
