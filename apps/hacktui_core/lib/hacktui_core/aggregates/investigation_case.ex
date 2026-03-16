defmodule HacktuiCore.Aggregates.InvestigationCase do
  @moduledoc """
  Pure aggregate for case state and transitions.
  """

  alias HacktuiCore.{CaseLifecycle, Commands, Events}

  @enforce_keys [:case_id, :title, :status, :source_alert_ids]
  defstruct [
    :case_id,
    :title,
    :status,
    :source_alert_ids,
    :assigned_to,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          case_id: String.t(),
          title: String.t(),
          status: atom(),
          source_alert_ids: [String.t()],
          assigned_to: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec open(Commands.OpenCase.t(), keyword()) :: {:ok, t(), Events.CaseOpened.t()}
  def open(%Commands.OpenCase{} = command, opts) do
    opened_at = Keyword.fetch!(opts, :opened_at)

    case_record = %__MODULE__{
      case_id: command.case_id,
      title: command.title,
      status: :open,
      source_alert_ids: command.source_alert_ids,
      inserted_at: opened_at,
      updated_at: opened_at
    }

    event = %Events.CaseOpened{
      event_id: Keyword.fetch!(opts, :event_id),
      case_id: case_record.case_id,
      title: case_record.title,
      source_alert_ids: case_record.source_alert_ids,
      opened_at: opened_at,
      actor: command.actor
    }

    {:ok, case_record, event}
  end

  @spec transition(t(), Commands.TransitionCase.t(), keyword()) ::
          {:ok, t(), Events.CaseTransitioned.t()}
          | {:error,
             {:invalid_transition, atom(), atom()}
             | {:stale_state, atom(), atom()}
             | :mismatched_case}
  def transition(%__MODULE__{} = case_record, %Commands.TransitionCase{} = command, opts) do
    cond do
      case_record.case_id != command.case_id ->
        {:error, :mismatched_case}

      case_record.status != command.from_status ->
        {:error, {:stale_state, case_record.status, command.from_status}}

      true ->
        with {:ok, next_status} <- CaseLifecycle.transition(case_record.status, command.to_status) do
          occurred_at = Keyword.fetch!(opts, :occurred_at)

          transitioned = %__MODULE__{case_record | status: next_status, updated_at: occurred_at}

          event = %Events.CaseTransitioned{
            event_id: Keyword.fetch!(opts, :event_id),
            case_id: case_record.case_id,
            from_status: case_record.status,
            to_status: next_status,
            occurred_at: occurred_at,
            actor: command.actor,
            reason: command.reason
          }

          {:ok, transitioned, event}
        end
    end
  end
end
