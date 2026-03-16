defmodule HacktuiTui.QueryWiringTest do
  use ExUnit.Case, async: true

  alias HacktuiTui.Workflows.{AlertQueue, ApprovalInbox, AuditExplorer, CaseBoard}
  alias HacktuiTui.TestSupport.FakeQueryService

  test "loads alert queue rows through the hub query service" do
    view = AlertQueue.load(FakeQueryService)

    assert view.spec.name == :alert_queue
    assert [%{alert_id: "alert-1"}] = view.rows
  end

  test "loads case board rows through the hub query service" do
    view = CaseBoard.load(FakeQueryService)

    assert view.spec.name == :case_board
    assert [%{case_id: "case-1"}] = view.rows
  end

  test "loads approval inbox rows through the hub query service" do
    view = ApprovalInbox.load(FakeQueryService)

    assert view.spec.name == :approval_inbox
    assert [%{action_request_id: "act-1"}] = view.rows
  end

  test "loads audit explorer rows through the hub query service" do
    view = AuditExplorer.load(FakeQueryService)

    assert view.spec.name == :audit_explorer
    assert [%{audit_id: "audit-1"}] = view.rows
  end
end
