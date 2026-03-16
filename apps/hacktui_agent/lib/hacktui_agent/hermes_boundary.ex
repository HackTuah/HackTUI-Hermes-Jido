defmodule HacktuiAgent.HermesBoundary do
  @moduledoc """
  Declares the approved context and operation boundaries for Hermes-facing runs.
  """

  @allowed_context_fields [
    :case_summary,
    :alert_summary,
    :timeline_excerpt,
    :audit_summary,
    :policy_class,
    :tool_budget
  ]

  @proposal_only_operations [:draft_report, :propose_action]

  @spec allowed_context_fields() :: [atom()]
  def allowed_context_fields, do: @allowed_context_fields

  @spec proposal_only_operations() :: [atom()]
  def proposal_only_operations, do: @proposal_only_operations
end
