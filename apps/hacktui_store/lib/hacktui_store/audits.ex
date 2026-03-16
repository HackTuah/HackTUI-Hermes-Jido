defmodule HacktuiStore.Audits do
  @moduledoc """
  Ecto persistence flows for audit events.
  """

  alias Ecto.Multi
  alias HacktuiCore.Events.AuditRecorded
  alias HacktuiStore.Schema.AuditEvent

  @spec persist(module(), AuditRecorded.t()) :: HacktuiStore.transaction_result()
  def persist(repo, %AuditRecorded{} = event) do
    Multi.new()
    |> Multi.insert(:audit_insert, audit_changeset(event))
    |> repo.transaction()
  end

  defp audit_changeset(%AuditRecorded{} = event) do
    AuditEvent.changeset(%AuditEvent{}, %{
      id: Ecto.UUID.generate(),
      audit_id: event.audit_id,
      action: Atom.to_string(event.action),
      result: Atom.to_string(event.result),
      actor_id: event.actor.id,
      subject: event.subject,
      occurred_at: event.occurred_at,
      metadata:
        Map.merge(
          %{
            event_id: event.event_id,
            subject: event.subject,
            action: event.action,
            result: event.result
          },
          Map.get(event, :metadata, %{}) || %{}
        )
    })
  end
end
