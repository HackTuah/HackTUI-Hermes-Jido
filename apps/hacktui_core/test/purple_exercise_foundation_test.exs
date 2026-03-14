defmodule HacktuiCore.PurpleExerciseFoundationTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Aggregates.PurpleExercise

  test "builds a purple exercise with deterministic scoring defaults" do
    assert {:ok, exercise} =
             PurpleExercise.new(%{
               exercise_id: "px-1",
               title: "Validate suspicious dns detection",
               objective: "Ensure demo replay observations are scored consistently",
               attack_tactic: "command-and-control",
               attack_technique: "T1071.004",
               expected_detection: "alert_observed",
               observation_refs: ["obs-1"]
             })

    assert exercise.exercise_id == "px-1"
    assert exercise.status == :draft
    assert exercise.validation_count == 0
    assert exercise.successful_validations == 0
    assert exercise.score == 0.0
  end

  test "records validation outcomes into a deterministic score" do
    {:ok, exercise} =
      PurpleExercise.new(%{
        exercise_id: "px-1",
        title: "Validate suspicious dns detection",
        objective: "Ensure demo replay observations are scored consistently",
        attack_tactic: "command-and-control",
        attack_technique: "T1071.004",
        expected_detection: "alert_observed",
        observation_refs: ["obs-1"]
      })

    assert updated = PurpleExercise.record_validation(exercise, true)
    assert updated.status == :validated
    assert updated.validation_count == 1
    assert updated.successful_validations == 1
    assert updated.score == 1.0

    assert updated = PurpleExercise.record_validation(updated, false)
    assert updated.validation_count == 2
    assert updated.successful_validations == 1
    assert updated.score == 0.5
  end
end
