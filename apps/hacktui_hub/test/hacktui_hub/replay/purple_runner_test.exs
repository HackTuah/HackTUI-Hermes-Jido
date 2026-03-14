defmodule HacktuiHub.Replay.PurpleRunnerTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Aggregates.PurpleExercise
  alias HacktuiHub.Replay.Runner

  test "replay accepted observations derive deterministic purple exercises" do
    accepted = Runner.run_fixture!("case-1")

    assert [%PurpleExercise{} = first, %PurpleExercise{} = second] =
             Runner.derive_exercises!(accepted)

    assert {first.exercise_id, first.score, first.observation_refs} ==
             {"px-case-1-1", 1.0, [hd(accepted).observation_id]}

    assert {second.exercise_id, second.score, second.observation_refs} ==
             {"px-case-1-2", 1.0, [List.last(accepted).observation_id]}
  end
end
