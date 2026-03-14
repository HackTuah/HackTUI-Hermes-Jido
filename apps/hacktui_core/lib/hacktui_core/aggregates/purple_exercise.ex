defmodule HacktuiCore.Aggregates.PurpleExercise do
  @moduledoc """
  Minimal aggregate for deterministic purple exercise validation.
  """

  @enforce_keys [
    :exercise_id,
    :title,
    :objective,
    :attack_tactic,
    :attack_technique,
    :expected_detection,
    :observation_refs
  ]
  defstruct [
    :exercise_id,
    :title,
    :objective,
    :attack_tactic,
    :attack_technique,
    :expected_detection,
    observation_refs: [],
    status: :draft,
    validation_count: 0,
    successful_validations: 0,
    score: 0.0
  ]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()}
  def new(attrs) when is_map(attrs) do
    {:ok, struct!(__MODULE__, attrs)}
  end

  @spec record_validation(t(), boolean()) :: t()
  def record_validation(%__MODULE__{} = exercise, success?) when is_boolean(success?) do
    validation_count = exercise.validation_count + 1
    successful_validations = exercise.successful_validations + if(success?, do: 1, else: 0)

    %{
      exercise
      | status: :validated,
        validation_count: validation_count,
        successful_validations: successful_validations,
        score: successful_validations / validation_count
    }
  end
end
