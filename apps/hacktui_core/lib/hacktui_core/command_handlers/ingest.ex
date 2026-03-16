defmodule HacktuiCore.CommandHandlers.Ingest do
  @moduledoc """
  Pure command handling for the ingest boundary.
  """

  alias HacktuiCore.Commands.AcceptObservation
  alias HacktuiCore.Events.ObservationAccepted

  @spec handle(AcceptObservation.t(), keyword()) :: {:ok, ObservationAccepted.t()}
  def handle(%AcceptObservation{} = command, opts) do
    {:ok,
     %ObservationAccepted{
       event_id: Keyword.fetch!(opts, :event_id),
       observation_id: command.observation_id,
       source: command.source,
       accepted_at: Keyword.fetch!(opts, :accepted_at),
       actor: command.actor
     }}
  end
end
