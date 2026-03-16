defmodule HacktuiCore.CommandHandlers.Audit do
  @moduledoc """
  Pure command handling for audit recording.
  """

  alias HacktuiCore.ActorRef
  alias HacktuiCore.Events.AuditRecorded

  @spec handle(atom(), ActorRef.t(), keyword()) :: {:ok, AuditRecorded.t()}
  def handle(action, %ActorRef{} = actor, opts) when is_atom(action) do
    {:ok,
     %AuditRecorded{
       event_id: Keyword.fetch!(opts, :event_id),
       audit_id: Keyword.fetch!(opts, :audit_id),
       actor: actor,
       action: action,
       occurred_at: Keyword.fetch!(opts, :occurred_at),
       result: Keyword.fetch!(opts, :result),
       subject: Keyword.fetch!(opts, :subject)
     }}
  end
end
