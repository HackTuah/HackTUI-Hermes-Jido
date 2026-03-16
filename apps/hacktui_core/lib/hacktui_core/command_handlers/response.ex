defmodule HacktuiCore.CommandHandlers.Response do
  @moduledoc """
  Pure command handling for approval-governed response actions.
  """

  alias HacktuiCore.Aggregates.ActionRequest
  alias HacktuiCore.Commands.{ApproveAction, RequestAction}

  @spec handle(RequestAction.t(), keyword()) :: {:ok, ActionRequest.t(), struct()}
  def handle(%RequestAction{} = command, opts), do: ActionRequest.request(command, opts)

  @spec handle(ActionRequest.t(), ApproveAction.t(), keyword()) ::
          {:ok, ActionRequest.t(), struct()} | {:error, term()}
  def handle(%ActionRequest{} = action_request, %ApproveAction{} = command, opts),
    do: ActionRequest.approve(action_request, command, opts)
end
