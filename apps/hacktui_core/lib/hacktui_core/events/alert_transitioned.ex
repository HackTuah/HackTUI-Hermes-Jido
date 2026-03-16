defmodule HacktuiCore.Events.AlertTransitioned do
  @moduledoc """
  Domain event emitted when an alert changes lifecycle state.
  """

  @enforce_keys [:event_id, :alert_id, :from_state, :to_state, :occurred_at, :actor, :reason]
  defstruct [:event_id, :alert_id, :from_state, :to_state, :occurred_at, :actor, :reason]

  @type t :: %__MODULE__{
          event_id: String.t(),
          alert_id: String.t(),
          from_state: atom(),
          to_state: atom(),
          occurred_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t(),
          reason: String.t()
        }
end
