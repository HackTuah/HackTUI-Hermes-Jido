defmodule HacktuiTui.LiveDashboardViewTest do
  use ExUnit.Case, async: true

  alias HacktuiTui.LiveDashboardView

  test "renders threat-context observations with a visible threat marker" do
    output =
      LiveDashboardView.render(%{
        health: %{summary: "ok"},
        refreshed_at: "now",
        status_line: "ready",
        alerts: [],
        cases: [],
        observations: [
          %{
            kind: "process_start",
            accepted_at: ~U[2026-03-14 00:00:00Z],
            metadata: %{threat_context: %{keyword: "mimikatz", severity: :high}},
            payload: %{summary: "credential access", raw_message: "mimikatz executed"}
          }
        ],
        ui: %{focused_pane: :observations, selections: %{observations: 0}, mode: :normal}
      })

    assert output =~ "@ credential access [TI: mimikatz]"
    assert output =~ "\e[38;5;141m"
  end
end