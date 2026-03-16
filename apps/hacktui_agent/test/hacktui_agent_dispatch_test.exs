defmodule HacktuiAgent.DispatchTest do
  use ExUnit.Case, async: true

  alias HacktuiAgent.MCP.Dispatch

  defmodule FakeQueryService do
    def alert_queue, do: [%{alert_id: "alert-1"}]
    def sensor_logs, do: [%{sensor_id: "sensor-1", message: "accepted connection"}]
    def jido_responses, do: [%{agent_id: "agent-1", status: "ok"}]
    def case_timeline(_repo, "case-1"), do: [%{entry_type: "case_opened"}]
  end

  defmodule FakeProposalService do
    def draft_report("case-1", _opts), do: %{case_id: "case-1", summary: "Draft report scaffold"}

    def propose_action(%{case_id: "case-1", action_class: :contain, target: "host-42"}, _opts),
      do: %{case_id: "case-1", action_class: :contain, target: "host-42", requires_approval: true}
  end

  test "dispatches read-only MCP tools to the hub query service" do
    assert {:ok, [%{alert_id: "alert-1"}]} =
             Dispatch.call(:get_latest_alerts, %{}, query_service: FakeQueryService)

    assert {:ok, [%{entry_type: "case_opened"}]} =
             Dispatch.call(:get_case_timeline, %{case_id: "case-1"},
               query_service: FakeQueryService
             )
  end

  test "dispatches proposal MCP tools to the proposal service" do
    assert {:ok, %{summary: "Draft report scaffold"}} =
             Dispatch.call(:draft_report, %{case_id: "case-1"},
               proposal_service: FakeProposalService
             )

    assert {:ok, %{requires_approval: true, action_class: :contain}} =
             Dispatch.call(
               :propose_action,
               %{case_id: "case-1", action_class: :contain, target: "host-42"},
               proposal_service: FakeProposalService
             )
  end
end
