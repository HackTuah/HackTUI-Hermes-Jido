defmodule HacktuiStore.ReadModels do
  @moduledoc """
  Query builders for operator-facing read models.

  Alert rows are read through `HacktuiHub.QueryService.alert_queue/1`, which is the single
  public alert-queue read path. A second definition used to live here and unioned persisted
  alerts with AlertCreated audit events; it selected `entry_type` and `payload`, which
  `AuditEvent` does not declare and no migration creates, so it could never execute against
  a database. It had no production caller. Removing the duplication is the fix; repairing
  dead code would have preserved the drift risk.

  The alert queue therefore merges both sources.
  """

  import Ecto.Query

  alias HacktuiStore.Schema.{
    ActionRequest,
    AuditEvent,
    CaseRecord,
    CaseTimelineEntry
  }

  #
  # ALERT QUEUE
  #

  def case_board_query do
    from(case_record in CaseRecord,
      order_by: [desc: case_record.updated_at]
    )
  end

  #
  # APPROVAL INBOX
  #

  @spec approval_inbox_query() :: Ecto.Query.t()
  def approval_inbox_query do
    from(action_request in ActionRequest,
      where: action_request.approval_status == "pending_approval",
      order_by: [desc: action_request.inserted_at]
    )
  end

  #
  # AUDIT EVENTS
  #

  @spec audit_events_query() :: Ecto.Query.t()
  def audit_events_query do
    from(audit_event in AuditEvent,
      order_by: [desc: audit_event.occurred_at]
    )
  end

  #
  # CASE TIMELINE
  #

  @spec case_timeline_query(String.t()) :: Ecto.Query.t()
  def case_timeline_query(case_id) do
    from(entry in CaseTimelineEntry,
      where: entry.case_id == ^case_id,
      order_by: [asc: entry.occurred_at]
    )
  end

  #
  # CASE LOOKUP
  #

  @spec case_record_query(String.t()) :: Ecto.Query.t()
  def case_record_query(case_id) do
    from(case_record in CaseRecord,
      where: case_record.case_id == ^case_id,
      limit: 1
    )
  end

  #
  # CASE ACTION REQUEST
  #

  @spec pending_action_for_case_query(String.t()) :: Ecto.Query.t()
  def pending_action_for_case_query(case_id) do
    from(action_request in ActionRequest,
      where:
        action_request.case_id == ^case_id and
          action_request.approval_status == "pending_approval",
      order_by: [desc: action_request.inserted_at],
      limit: 1
    )
  end
end
