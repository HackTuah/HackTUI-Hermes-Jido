defmodule HacktuiTui.TestSupport.FakeQueryService do
  def alert_queue, do: [%{alert_id: "alert-1", severity: "high", state: "open"}]
  def case_board, do: [%{case_id: "case-1", status: "triage"}]
  def approval_inbox, do: [%{action_request_id: "act-1", approval_status: "pending_approval"}]
  def audit_events, do: [%{audit_id: "audit-1", action: "approve_action"}]
end

ExUnit.start()
