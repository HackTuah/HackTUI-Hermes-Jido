defmodule HacktuiCore do
  @moduledoc """
  Pure domain catalog for the HackTUI umbrella.
  """

  @bounded_contexts [
    :sensor_collection,
    :ingest_and_normalization,
    :detection_and_alerting,
    :casework_and_investigation,
    :evidence_and_artifacts,
    :response_governance,
    :policy_identity_and_audit,
    :collaboration,
    :operator_experience,
    :agent_operations,
    :platform_operations
  ]

  @spec bounded_contexts() :: [atom()]
  def bounded_contexts, do: @bounded_contexts
end
