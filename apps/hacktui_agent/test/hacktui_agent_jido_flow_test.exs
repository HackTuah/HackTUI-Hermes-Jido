defmodule HacktuiAgent.JidoFlowTest do
  use ExUnit.Case, async: true

  alias HacktuiAgent.{InvestigationFlow, Agents.InvestigationCoordinator}

  defmodule FakeInvestigationQueryService do
    def case_timeline(_repo, "case-1") do
      [
        %{
          entry_type: "case_opened",
          summary: "Investigate suspicious DNS",
          indicators: ["malicious.example"]
        },
        %{
          entry_type: "alert_linked",
          summary: "Beaconing suspicion",
          indicators: ["malicious.example", "10.0.0.4"]
        }
      ]
    end

    def alert_queue(_repo) do
      [
        %{alert_id: "alert-1", indicators: ["malicious.example", "10.0.0.4"], severity: "high"},
        %{alert_id: "alert-2", indicators: ["malicious.example"], severity: "medium"},
        %{alert_id: "alert-3", indicators: ["benign.example"], severity: "low"}
      ]
    end
  end

  test "defines a Jido instance module for the agent runtime" do
    assert Code.ensure_loaded?(HacktuiAgent.Jido)
    assert function_exported?(HacktuiAgent.Jido, :child_spec, 1)
  end

  test "defines signal routes for the investigation coordinator agent" do
    routes = InvestigationCoordinator.signal_routes()

    assert Enum.any?(routes, fn {signal, _action, _priority} ->
             signal == "hacktui.investigation.start"
           end)

    assert Enum.any?(routes, fn {signal, _action, _priority} ->
             signal == "hacktui.correlation.triggered"
           end)
  end

  test "runs a Jido-powered investigation and correlation flow" do
    assert {:ok, agent, directives} =
             InvestigationFlow.run("case-1",
               query_service: FakeInvestigationQueryService,
               repo: :fake_repo
             )

    assert agent.state.status == :completed
    assert agent.state.case_id == "case-1"
    assert agent.state.correlation.matched_alert_ids == ["alert-1", "alert-2"]
    assert agent.state.correlation.shared_indicators == ["10.0.0.4", "malicious.example"]
    assert agent.state.report_draft.summary =~ "case-1"
    assert Enum.any?(directives, &match?(%Elixir.Jido.Agent.Directive.Emit{}, &1))
  end
end
