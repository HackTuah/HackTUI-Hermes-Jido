defmodule HacktuiCore.Aggregates.ActionRequest do
  @moduledoc """
  Pure aggregate for approval-governed action requests.
  """

  alias HacktuiCore.{Commands, Events}

  @enforce_keys [
    :action_request_id,
    :case_id,
    :action_class,
    :target,
    :approval_status,
    :requested_by,
    :reason
  ]
  defstruct [
    :action_request_id,
    :case_id,
    :action_class,
    :target,
    :approval_status,
    :requested_by,
    :approved_by,
    :reason,
    :inserted_at,
    :updated_at,
    :approved_at
  ]

  @type status :: :pending_approval | :approved

  @type t :: %__MODULE__{
          action_request_id: String.t(),
          case_id: String.t(),
          action_class: atom(),
          target: String.t(),
          approval_status: status(),
          requested_by: HacktuiCore.ActorRef.t(),
          approved_by: HacktuiCore.ActorRef.t() | nil,
          reason: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          approved_at: DateTime.t() | nil
        }

  @spec request(Commands.RequestAction.t(), keyword()) :: {:ok, t(), Events.ActionRequested.t()}
  def request(%Commands.RequestAction{} = command, opts) do
    requested_at = Keyword.fetch!(opts, :requested_at)

    action_request = %__MODULE__{
      action_request_id: command.action_request_id,
      case_id: command.case_id,
      action_class: command.action_class,
      target: command.target,
      approval_status: :pending_approval,
      requested_by: command.requested_by,
      reason: command.reason,
      inserted_at: requested_at,
      updated_at: requested_at
    }

    event = %Events.ActionRequested{
      event_id: Keyword.fetch!(opts, :event_id),
      action_request_id: action_request.action_request_id,
      case_id: action_request.case_id,
      action_class: action_request.action_class,
      target: action_request.target,
      requested_at: requested_at,
      actor: command.requested_by,
      reason: command.reason
    }

    {:ok, action_request, event}
  end

  @spec approve(t(), Commands.ApproveAction.t(), keyword()) ::
          {:ok, t(), Events.ActionApproved.t()}
          | {:error, :already_decided | :mismatched_action_request}
  def approve(%__MODULE__{} = action_request, %Commands.ApproveAction{} = command, opts) do
    cond do
      action_request.action_request_id != command.action_request_id ->
        {:error, :mismatched_action_request}

      action_request.approval_status != :pending_approval ->
        {:error, :already_decided}

      true ->
        approved_at = Keyword.fetch!(opts, :approved_at)

        approved_request = %__MODULE__{
          action_request
          | approval_status: :approved,
            approved_by: command.approver,
            approved_at: approved_at,
            updated_at: approved_at
        }

        event = %Events.ActionApproved{
          event_id: Keyword.fetch!(opts, :event_id),
          action_request_id: action_request.action_request_id,
          approved_at: approved_at,
          actor: command.approver,
          reason: command.reason
        }

        {:ok, approved_request, event}
    end
  end
end
