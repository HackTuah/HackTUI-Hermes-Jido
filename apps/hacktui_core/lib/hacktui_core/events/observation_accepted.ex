defmodule HacktuiCore.Events.ObservationAccepted do
  @moduledoc """
  Domain event emitted when an observation is accepted by the ingest boundary.
  """

  @enforce_keys [:event_id, :observation_id, :source, :accepted_at, :actor]
  defstruct [:event_id, :observation_id, :source, :kind, :payload, :metadata, :accepted_at, :actor]

  @type t :: %__MODULE__{
          event_id: String.t(),
          observation_id: String.t(),
          source: atom(),
          kind: String.t() | atom() | nil,
          payload: map() | nil,
          metadata: map() | nil,
          accepted_at: DateTime.t(),
          actor: HacktuiCore.ActorRef.t()
        }
end
