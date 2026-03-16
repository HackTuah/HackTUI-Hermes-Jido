defmodule HacktuiTui.DemoTerminalViewTest do
  use ExUnit.Case, async: true

  alias HacktuiTui.DemoTerminalView

  test "renders the bounded workflow terminal view with the required fields" do
    output =
      DemoTerminalView.render(%{
        case_id: "case-1",
        investigation_status: :completed,
        matched_alert_ids: ["alert-1", "alert-2"],
        shared_indicators: ["10.0.0.4", "malicious.example"],
        summary: "Deterministic summary",
        recommendation: "Request approval for SIMULATED containment",
        health_snapshot: %{store: %{mode: :db_backed}, agent: %{mode: :jido_enabled}}
      })

    assert output =~ "case-1"
    assert output =~ "completed"
    assert output =~ "alert-1"
    assert output =~ "malicious.example"
    assert output =~ "Deterministic summary"
    assert output =~ "SIMULATED"
    assert output =~ "db_backed"
  end
end
