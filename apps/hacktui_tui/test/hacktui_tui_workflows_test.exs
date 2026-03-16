defmodule HacktuiTui.WorkflowsTest do
  use ExUnit.Case, async: true

  alias HacktuiTui.Workflows.{AlertQueue, ApprovalInbox, AuditExplorer, CaseBoard}

  test "defines the alert queue workflow" do
    spec = AlertQueue.spec()

    assert spec.title == "Alert Queue"
    assert spec.read_model == :alert_queue
    assert :severity in spec.columns
    assert :curate in spec.command_classes
  end

  test "defines the case board workflow" do
    spec = CaseBoard.spec()

    assert spec.title == "Case Board"
    assert spec.read_model == :case_board
    assert :status in spec.columns
    assert :curate in spec.command_classes
  end

  test "defines the approval inbox workflow" do
    spec = ApprovalInbox.spec()

    assert spec.title == "Approval Inbox"
    assert spec.read_model == :approval_inbox
    assert :approval_status in spec.columns
    assert :contain in spec.command_classes
  end

  test "defines the audit explorer workflow" do
    spec = AuditExplorer.spec()

    assert spec.title == "Audit Explorer"
    assert spec.read_model == :audit_events
    assert :action in spec.columns
    assert spec.command_classes == [:observe]
  end
end
