defmodule HacktuiHub.PurpleServiceTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Aggregates.PurpleExercise
  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.PurpleService

  test "derives a purple exercise from an accepted replay observation" do
    accepted = %ObservationAccepted{
      event_id: "evt-1",
      observation_id: "obs-1",
      source: "demo.case-1",
      actor: "replay-runner",
      kind: "alert_observed",
      payload: %{"alert_id" => "alert-1", "indicator" => "10.0.0.4", "severity" => "high"},
      accepted_at: ~U[2026-03-07 13:00:00Z],
      metadata: %{"fixture" => "case-1", "sequence" => 1}
    }

    assert {:ok, %PurpleExercise{} = exercise} = PurpleService.derive_exercise(accepted)

    assert exercise.exercise_id == "px-case-1-1"
    assert exercise.title == "Validate alert_observed detection for 10.0.0.4"
    assert exercise.expected_detection == "alert_observed"
    assert exercise.attack_tactic == "command-and-control"
    assert exercise.attack_technique == "T1071.004"
    assert exercise.observation_refs == ["obs-1"]
    assert exercise.status == :validated
    assert exercise.validation_count == 1
    assert exercise.successful_validations == 1
    assert exercise.score == 1.0
  end
end
