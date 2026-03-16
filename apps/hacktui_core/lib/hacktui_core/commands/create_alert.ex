defmodule HacktuiCore.Commands.CreateAlert do
  @moduledoc """
  Command contract for creating a new alert from accepted observations.
  """

  @enforce_keys [:alert_id, :title, :severity, :observation_refs, :actor]
  defstruct [:alert_id, :title, :severity, :observation_refs, :actor]

  @type t :: %__MODULE__{
          alert_id: String.t(),
          title: String.t(),
          severity: atom(),
          observation_refs: [String.t()],
          actor: HacktuiCore.ActorRef.t()
        }
end
