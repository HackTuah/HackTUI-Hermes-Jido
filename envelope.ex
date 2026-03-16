defmodule HacktuiCore.Observation.Envelope do
  @moduledoc """
  Canonical telemetry envelope for observations entering Hacktui.

  All external telemetry should first be normalized into this structure
  before becoming domain events.
  """

  @enforce_keys [:type, :source, :timestamp, :data]

  defstruct [
    :id,
    :type,
    :source,
    :timestamp,
    :data,
    :meta
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          source: atom() | String.t(),
          timestamp: DateTime.t(),
          data: map(),
          meta: map()
        }

  def new(type, source, data) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      type: type,
      source: source,
      timestamp: DateTime.utc_now(),
      data: data,
      meta: %{}
    }
  end
end
