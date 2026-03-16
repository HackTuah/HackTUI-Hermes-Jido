defmodule HacktuiStore.ReadModels do
  @moduledoc """
  Query builders for operator-facing read models.

  Alerts may originate from either:
  1. persisted Alert rows
  2. AlertCreated audit events

  The alert queue therefore merges both sources.
  """

  import Ecto.Query

  alias HacktuiStore.Schema.{
    ActionRequest,
    Alert,
    AuditEvent,
    CaseRecord,
    CaseTimelineEntry
  }

  #
  # ALERT QUEUE
  #

  @spec alert_queue_query() :: Ecto.Query.t()
  def alert_queue_query do
    alert_rows =
      from(alert in Alert,
        select: %{
          alert_id: alert.alert_id,
          title: alert.title,
          severity: alert.severity,
          state: alert.state,
          inserted_at: alert.inserted_at,
          metadata: fragment("'{}'::jsonb")
        }
      )

    event_rows =
      from(event in AuditEvent,
        where: fragment("? ILIKE '%alert%'", event.entry_type),
        select: %{
          alert_id: fragment("?->>'alert_id'", event.payload),
          title: fragment("?->>'title'", event.payload),
          severity: fragment("?->>'severity'", event.payload),
          state: fragment("'open'"),
          inserted_at: event.occurred_at,
          metadata: event.payload
        }
      )

    from(row in subquery(alert_rows |> union_all(^event_rows)),
      order_by: [desc: row.inserted_at]
    )
  end

  #
  # CASE BOARD
  #

  @spec case_board_query() :: Ecto.Query.t()
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
