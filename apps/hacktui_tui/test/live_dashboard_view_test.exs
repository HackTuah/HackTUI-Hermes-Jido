defmodule HacktuiTui.LiveDashboardViewTest do
  use ExUnit.Case, async: true

  alias HacktuiTui.LiveDashboardView

  @fg_purple "\e[38;5;141m"
  @bold "\e[1m"

  # Mirrors the map HacktuiTui.ui_state/1 passes to render/3.
  defp ui_state(focused_pane, selections) do
    %{
      mode: :normal,
      query: "",
      pending_query: "",
      focused_pane: focused_pane,
      selected_pane: focused_pane,
      selected_index: Map.get(selections, focused_pane, 0),
      selections: selections,
      panes: [:alerts, :cases, :observations]
    }
  end

  defp observation(summary, metadata) do
    %{
      kind: "process_start",
      accepted_at: ~U[2026-03-14 00:00:00Z],
      metadata: metadata,
      payload: %{summary: summary, raw_message: summary}
    }
  end

  defp render(observations) do
    data = %{
      health: %{summary: "ok"},
      refreshed_at: "now",
      status_line: "ready",
      alerts: [],
      cases: [],
      observations: observations
    }

    LiveDashboardView.render(
      data,
      ui_state(:observations, %{alerts: 0, cases: 0, observations: 0})
    )
  end

  defp row_containing(output, needle) do
    output
    |> String.split("\n")
    |> Enum.find(&String.contains?(&1, needle))
  end

  test "flags threat-context observations with the ! marker and purple styling" do
    output =
      render([
        observation("credential access", %{
          threat_context: %{keyword: "mimikatz", severity: :high}
        })
      ])

    row = row_containing(output, "credential access")

    assert row, "expected a rendered row for the threat observation"
    assert row =~ "! 00:00:00"
    assert row =~ @fg_purple <> @bold
  end

  test "leaves observations without threat context unmarked" do
    output =
      render([
        observation("credential access", %{
          threat_context: %{keyword: "mimikatz", severity: :high}
        }),
        observation("routine login", %{})
      ])

    threat_row = row_containing(output, "credential access")
    plain_row = row_containing(output, "routine login")

    assert threat_row =~ "! 00:00:00"
    refute plain_row =~ "! 00:00:00"
    refute plain_row =~ @fg_purple <> @bold
  end
end
