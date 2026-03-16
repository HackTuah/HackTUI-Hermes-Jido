defmodule HacktuiStore.ReadModelsTest do
  use ExUnit.Case, async: true

  alias HacktuiStore.ReadModels
  alias HacktuiStore.Schema.{ActionRequest, Alert, AuditEvent, CaseRecord, CaseTimelineEntry}

  test "builds alert queue query" do
    query = ReadModels.alert_queue_query()
    assert query.from.source == {"alerts", Alert}
  end

  test "builds case board query" do
    query = ReadModels.case_board_query()
    assert query.from.source == {"cases", CaseRecord}
  end

  test "builds approval inbox query" do
    query = ReadModels.approval_inbox_query()
    assert query.from.source == {"action_requests", ActionRequest}
  end

  test "builds audit explorer query" do
    query = ReadModels.audit_events_query()
    assert query.from.source == {"audit_events", AuditEvent}
  end

  test "builds case timeline query" do
    query = ReadModels.case_timeline_query("case-1")
    assert query.from.source == {"case_timeline_entries", CaseTimelineEntry}
  end
end
