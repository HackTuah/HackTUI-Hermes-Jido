defmodule HacktuiCore.Events.ActionApproved do
  @moduledoc """
  Domain event emitted when an action request is approved.
  """

  @enforce_keys [:event_id, :action_request_id, :approved_at, :actor, :reason]
  defstruct [:event_id, :action_request_id, :approved_at, :actor, :reason]

  @type t :: %__MODULE__{
          event_id: String.t(),
          action_request_id: String.t(),
          approved_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
