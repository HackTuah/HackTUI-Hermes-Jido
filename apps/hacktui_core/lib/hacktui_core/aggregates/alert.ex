defmodule HacktuiCore.Aggregates.Alert do
  @moduledoc """
  Pure aggregate for alert state and transitions.
  """

  alias HacktuiCore.{AlertLifecycle, Commands, Events}

  @enforce_keys [:alert_id, :title, :severity, :state, :disposition, :observation_refs]
  defstruct [
    :alert_id,
    :title,
    :severity,
    :state,
    :disposition,
    :observation_refs,
    :inserted_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          alert_id: String.t(),
          title: String.t(),
          severity: atom(),
          state: atom(),
          disposition: atom(),
          observation_refs: [String.t()],
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec create(Commands.CreateAlert.t(), keyword()) :: {:ok, t(), Events.AlertCreated.t()}
  def create(%Commands.CreateAlert{} = command, opts) do
    occurred_at = Keyword.fetch!(opts, :occurred_at)

    alert = %__MODULE__{
      alert_id: command.alert_id,
      title: command.title,
      severity: command.severity,
      state: :open,
      disposition: :unknown,
      observation_refs: command.observation_refs,
      inserted_at: occurred_at,
      updated_at: occurred_at
    }

    event = %Events.AlertCreated{
      event_id: Keyword.fetch!(opts, :event_id),
      alert_id: alert.alert_id,
      title: alert.title,
      severity: alert.severity,
      occurred_at: occurred_at,
      actor: command.actor
    }

    {:ok, alert, event}
  end

  @spec transition(t(), Commands.TransitionAlert.t(), keyword()) ::
          {:ok, t(), Events.AlertTransitioned.t()}
          | {:error,
             {:invalid_transition, atom(), atom()}
             | {:stale_state, atom(), atom()}
             | :mismatched_alert}
  def transition(%__MODULE__{} = alert, %Commands.TransitionAlert{} = command, opts) do
    cond do
      alert.alert_id != command.alert_id ->
        {:error, :mismatched_alert}

      alert.state != command.from_state ->
        {:error, {:stale_state, alert.state, command.from_state}}

      true ->
        with {:ok, next_state} <- AlertLifecycle.transition(alert.state, command.to_state) do
          occurred_at = Keyword.fetch!(opts, :occurred_at)

          transitioned = %__MODULE__{alert | state: next_state, updated_at: occurred_at}

          event = %Events.AlertTransitioned{
            event_id: Keyword.fetch!(opts, :event_id),
            alert_id: alert.alert_id,
            from_state: alert.state,
            to_state: next_state,
            occurred_at: occurred_at,
            actor: command.actor,
            reason: command.reason
          }

          {:ok, transitioned, event}
        end
    end
  end
end
