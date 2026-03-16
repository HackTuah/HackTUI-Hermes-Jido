defmodule HacktuiCore.Commands.ApproveAction do
  @moduledoc """
  Command contract for approving a pending action request.
  """

  @enforce_keys [:action_request_id, :approver, :reason]
  defstruct [:action_request_id, :approver, :reason]

  @type t :: %__MODULE__{
          action_request_id: String.t(),
          approver: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
