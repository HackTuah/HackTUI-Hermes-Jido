defmodule HacktuiHub.PurpleService do
  @moduledoc """
  Derives deterministic purple exercises from accepted observations.
  """

  alias HacktuiCore.Aggregates.PurpleExercise
  alias HacktuiCore.Events.ObservationAccepted

  @spec derive_exercise(ObservationAccepted.t()) :: {:ok, PurpleExercise.t()}
  def derive_exercise(%ObservationAccepted{} = accepted) do
    fixture = get_in(accepted.metadata, ["fixture"]) || accepted.source
    sequence = get_in(accepted.metadata, ["sequence"]) || 1
    indicator = get_in(accepted.payload, ["indicator"]) || accepted.observation_id
    {attack_tactic, attack_technique} = attack_mapping(accepted.kind)

    PurpleExercise.new(%{
      exercise_id: "px-#{fixture}-#{sequence}",
      title: "Validate #{accepted.kind} detection for #{indicator}",
      objective: "Continuously validate replay-derived detections",
      attack_tactic: attack_tactic,
      attack_technique: attack_technique,
      expected_detection: accepted.kind,
      observation_refs: [accepted.observation_id]
    })
    |> then(fn {:ok, exercise} -> {:ok, PurpleExercise.record_validation(exercise, true)} end)
  end

  defp attack_mapping("alert_observed"), do: {"command-and-control", "T1071.004"}
  defp attack_mapping(_kind), do: {"discovery", "T1087"}
end
