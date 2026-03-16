defmodule HacktuiCore.InvestigationTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Investigation.{Correlation, ReportDraft}

  test "correlates timeline and alert context using pure logic" do
    timeline = [
      %{indicators: ["malicious.example", "10.0.0.4"]},
      %{indicators: ["10.0.0.4"]}
    ]

    alerts = [
      %{alert_id: "alert-1", indicators: ["malicious.example", "10.0.0.4"]},
      %{alert_id: "alert-2", indicators: ["malicious.example"]},
      %{alert_id: "alert-3", indicators: ["benign.example"]}
    ]

    result = Correlation.correlate("case-1", alerts, timeline)

    assert result.case_id == "case-1"
    assert result.matched_alert_ids == ["alert-1", "alert-2"]
    assert result.shared_indicators == ["10.0.0.4", "malicious.example"]
  end

  test "builds a deterministic report draft from correlation output" do
    report =
      ReportDraft.build("case-1", %{
        case_id: "case-1",
        matched_alert_ids: ["alert-1", "alert-2"],
        shared_indicators: ["10.0.0.4", "malicious.example"]
      })

    assert report.case_id == "case-1"
    assert report.summary =~ "case-1"
    assert report.matched_alert_ids == ["alert-1", "alert-2"]
  end
end
