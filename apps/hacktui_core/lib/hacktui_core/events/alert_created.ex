defmodule HacktuiCore.Events.AlertCreated do
  @moduledoc """
  Domain event emitted when detection creates a new alert.
  """

  @enforce_keys [:event_id, :alert_id, :title, :severity, :occurred_at, :actor]
  defstruct [:event_id, :alert_id, :title, :severity, :occurred_at, :actor]

  @type t :: %__MODULE__{
          event_id: String.t(),
          alert_id: String.t(),
          title: String.t(),
          severity: atom(),
          occurred_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t()
        }
end
