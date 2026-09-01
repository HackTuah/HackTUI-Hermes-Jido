defmodule HacktuiStore.Actions do
  @moduledoc """
  Ecto persistence flows for action requests and approvals.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias HacktuiCore.Aggregates.ActionRequest, as: DomainActionRequest
  alias HacktuiCore.Events.{ActionApproved, ActionRequested}
  alias HacktuiStore.Schema.ActionRequest

  @spec persist_request(module(), DomainActionRequest.t(), ActionRequested.t()) ::
          HacktuiStore.transaction_result()
  def persist_request(repo, %DomainActionRequest{} = action_request, %ActionRequested{} = event) do
    action_request
    |> request_multi(event)
    |> repo.transaction()
  end

  @spec persist_approval(module(), DomainActionRequest.t(), ActionApproved.t()) ::
          HacktuiStore.transaction_result()
  def persist_approval(repo, %DomainActionRequest{} = action_request, %ActionApproved{} = event) do
    action_request
    |> approval_multi(event)
    |> repo.transaction()
  end

  @spec request_multi(DomainActionRequest.t(), ActionRequested.t()) :: Ecto.Multi.t()
  def request_multi(%DomainActionRequest{} = action_request, %ActionRequested{} = event) do
    Multi.new()
    |> Multi.insert(:action_request_insert, request_changeset(action_request, event))
  end

  @spec approval_multi(DomainActionRequest.t(), ActionApproved.t()) :: Ecto.Multi.t()
  def approval_multi(%DomainActionRequest{} = action_request, %ActionApproved{} = event) do
    # Guarded on the current status. Without it, two concurrent approvers both pass the
    # aggregate's :already_decided check, both writes succeed, and the second silently
    # overwrites approved_by/approved_at -- so the record of who authorised a containment
    # action was last-writer-wins.
    query =
      from(record in ActionRequest,
        where:
          record.action_request_id == ^action_request.action_request_id and
            record.approval_status == "pending_approval"
      )

    Multi.new()
    |> Multi.update_all(
      :action_request_update,
      query,
      set: [
        approval_status: Atom.to_string(action_request.approval_status),
        approved_by: event.actor.id,
        approved_at: event.approved_at,
        updated_at: event.approved_at
      ]
    )
    # update_all returns {count, nil}; a zero-row update means someone decided first.
    |> Multi.run(:action_request_guard, fn _repo, %{action_request_update: {count, _}} ->
      if count == 1, do: {:ok, count}, else: {:error, :already_decided}
    end)
  end

  defp request_changeset(%DomainActionRequest{} = action_request, %ActionRequested{} = event) do
    ActionRequest.changeset(%ActionRequest{}, %{
      id: Ecto.UUID.generate(),
      action_request_id: action_request.action_request_id,
      case_id: action_request.case_id,
      action_class: Atom.to_string(action_request.action_class),
      target: action_request.target,
      approval_status: Atom.to_string(action_request.approval_status),
      requested_by: action_request.requested_by.id,
      reason: action_request.reason,
      metadata: %{
        event_id: event.event_id
      }
    })
  end
end
