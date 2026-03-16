defmodule HacktuiCore.Events.CaseTransitioned do
  @moduledoc """
  Domain event emitted when a case changes lifecycle state.
  """

  @enforce_keys [:event_id, :case_id, :from_status, :to_status, :occurred_at, :actor, :reason]
  defstruct [:event_id, :case_id, :from_status, :to_status, :occurred_at, :actor, :reason]

  @type t :: %__MODULE__{
          event_id: String.t(),
          case_id: String.t(),
          from_status: atom(),
          to_status: atom(),
          occurred_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
