defmodule HacktuiCore.Observation.Envelope do
  @moduledoc """
  Transport-level observation envelope for telemetry and ingestion payloads.

  This is intentionally separate from `HacktuiCore.Events.*`, which model
  domain events and should remain unchanged.
  """

  @enforce_keys [:source, :kind, :payload]
  defstruct [:source, :kind, :payload, :received_at, metadata: %{}]

  @type t :: %__MODULE__{
          source: String.t() | atom(),
          kind: String.t() | atom(),
          payload: map(),
          received_at: DateTime.t() | nil,
          metadata: map()
        }

  @spec new(String.t() | atom(), String.t() | atom(), map()) :: t()
  def new(source, kind, payload) when is_map(payload) do
    %__MODULE__{
      source: source,
      kind: kind,
      payload: payload,
      received_at: DateTime.utc_now(),
      metadata: %{}
    }
  end
end
