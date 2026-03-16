defmodule HacktuiTui.Workflows.AlertQueue do
  @moduledoc """
  Workflow specification for the terminal alert queue.
  """

  alias HacktuiHub.QueryService
  alias HacktuiTui.{WorkflowSpec, WorkflowView}

  @spec spec() :: WorkflowSpec.t()
  def spec do
    %WorkflowSpec{
      name: :alert_queue,
      title: "Alert Queue",
      read_model: :alert_queue,
      columns: [:alert_id, :title, :severity, :state, :inserted_at],
      command_classes: [:observe, :curate],
      empty_state: "No alerts are currently queued."
    }
  end

  @spec load(module()) :: WorkflowView.t()
  def load(query_service \\ QueryService) do
    %WorkflowView{spec: spec(), rows: query_service.alert_queue()}
  end
end
