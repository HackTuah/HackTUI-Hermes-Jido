defmodule HacktuiTui.Workflows.ApprovalInbox do
  @moduledoc """
  Workflow specification for pending approvals.
  """

  alias HacktuiHub.QueryService
  alias HacktuiTui.{WorkflowSpec, WorkflowView}

  @spec spec() :: WorkflowSpec.t()
  def spec do
    %WorkflowSpec{
      name: :approval_inbox,
      title: "Approval Inbox",
      read_model: :approval_inbox,
      columns: [:action_request_id, :action_class, :approval_status, :requested_by, :inserted_at],
      command_classes: [:observe, :change, :contain],
      empty_state: "There are no pending approvals."
    }
  end

  @spec load(module()) :: WorkflowView.t()
  def load(query_service \\ QueryService) do
    %WorkflowView{spec: spec(), rows: query_service.approval_inbox()}
  end
end
