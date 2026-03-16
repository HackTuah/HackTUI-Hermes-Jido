defmodule HacktuiTui.Workflows.AuditExplorer do
  @moduledoc """
  Workflow specification for browsing audit history.
  """

  alias HacktuiHub.QueryService
  alias HacktuiTui.{WorkflowSpec, WorkflowView}

  @spec spec() :: WorkflowSpec.t()
  def spec do
    %WorkflowSpec{
      name: :audit_explorer,
      title: "Audit Explorer",
      read_model: :audit_events,
      columns: [:audit_id, :action, :result, :actor_id, :occurred_at],
      command_classes: [:observe],
      empty_state: "No audit events have been recorded yet."
    }
  end

  @spec load(module()) :: WorkflowView.t()
  def load(query_service \\ QueryService) do
    %WorkflowView{spec: spec(), rows: query_service.audit_events()}
  end
end
