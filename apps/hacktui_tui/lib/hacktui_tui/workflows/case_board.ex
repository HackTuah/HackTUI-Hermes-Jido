defmodule HacktuiTui.Workflows.CaseBoard do
  @moduledoc """
  Workflow specification for the case board.
  """

  alias HacktuiHub.QueryService
  alias HacktuiTui.{WorkflowSpec, WorkflowView}

  @spec spec() :: WorkflowSpec.t()
  def spec do
    %WorkflowSpec{
      name: :case_board,
      title: "Case Board",
      read_model: :case_board,
      columns: [:case_id, :title, :status, :assigned_to, :updated_at],
      command_classes: [:observe, :curate],
      empty_state: "No active cases are currently assigned."
    }
  end

  @spec load(module()) :: WorkflowView.t()
  def load(query_service \\ QueryService) do
    %WorkflowView{spec: spec(), rows: query_service.case_board()}
  end
end
