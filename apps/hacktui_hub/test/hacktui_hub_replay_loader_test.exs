defmodule HacktuiHub.ReplayLoaderTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Observation.Envelope
  alias HacktuiHub.Replay.{Loader, Runner}

  test "load_fixture!/1 parses case-1 JSONL into ordered envelopes" do
    envelopes = Loader.load_fixture!("fixtures/replay/case-1.jsonl")

    assert [first, second] = envelopes

    assert %Envelope{
             source: "demo.case-1",
             kind: "alert_observed",
             payload: %{"alert_id" => "alert-1", "indicator" => "10.0.0.4", "severity" => "high"},
             received_at: ~U[2026-03-07 13:00:00Z],
             metadata: %{"fixture" => "case-1", "sequence" => 1}
           } = first

    assert %Envelope{
             source: "demo.case-1",
             kind: "alert_observed",
             payload: %{"alert_id" => "alert-2", "indicator" => "malicious.example", "severity" => "medium"},
             received_at: ~U[2026-03-07 13:00:10Z],
             metadata: %{"fixture" => "case-1", "sequence" => 2}
           } = second
   end

  test "run_fixture!/1 replays fixtures into ordered accepted observations" do
    accepted = Runner.run_fixture!("fixtures/replay/case-1.jsonl")

    assert [first, second] = accepted
    assert Enum.map(accepted, & &1.payload["alert_id"]) == ["alert-1", "alert-2"]
    assert Enum.map(accepted, & &1.metadata["sequence"]) == [1, 2]
    assert Enum.map(accepted, & &1.event_id) == [
             "replay-demo.case-1-alert_observed-1",
             "replay-demo.case-1-alert_observed-2"
           ]

    assert %HacktuiCore.Events.ObservationAccepted{
             source: "demo.case-1",
             kind: "alert_observed",
             payload: %{"alert_id" => "alert-1", "indicator" => "10.0.0.4", "severity" => "high"},
             accepted_at: ~U[2026-03-07 13:00:00Z],
             metadata: %{"fixture" => "case-1", "sequence" => 1}
           } = first

    assert %HacktuiCore.Events.ObservationAccepted{
             source: "demo.case-1",
             kind: "alert_observed",
             payload: %{"alert_id" => "alert-2", "indicator" => "malicious.example", "severity" => "medium"},
             accepted_at: ~U[2026-03-07 13:00:10Z],
             metadata: %{"fixture" => "case-1", "sequence" => 2}
           } = second
  end
end
