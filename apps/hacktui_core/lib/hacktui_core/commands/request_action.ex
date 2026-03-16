defmodule HacktuiCore.Commands.RequestAction do
  @moduledoc """
  Command contract for proposing an approval-governed action.
  """

  @enforce_keys [:action_request_id, :case_id, :action_class, :target, :requested_by, :reason]
  defstruct [:action_request_id, :case_id, :action_class, :target, :requested_by, :reason]

  @type t :: %__MODULE__{
          action_request_id: String.t(),
          case_id: String.t(),
          action_class: atom(),
          target: String.t(),
          requested_by: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
