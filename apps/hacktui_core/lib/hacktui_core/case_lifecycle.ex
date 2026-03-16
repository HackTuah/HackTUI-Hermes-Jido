defmodule HacktuiCore.CaseLifecycle do
  @moduledoc """
  Case lifecycle values and transition rules agreed in the architecture.
  """

  @states [
    :open,
    :triage,
    :active_investigation,
    :response_pending_approval,
    :response_in_progress,
    :monitoring,
    :resolved,
    :closed
  ]

  @transitions %{
    open: [:triage],
    triage: [:active_investigation, :response_pending_approval, :resolved],
    active_investigation: [:response_pending_approval, :monitoring, :resolved],
    response_pending_approval: [:response_in_progress, :active_investigation],
    response_in_progress: [:monitoring, :active_investigation, :resolved],
    monitoring: [:active_investigation, :resolved],
    resolved: [:closed, :active_investigation],
    closed: [:active_investigation]
  }

  @spec states() :: [atom()]
  def states, do: @states

  @spec transition(atom(), atom()) ::
          {:ok, atom()} | {:error, {:invalid_transition, atom(), atom()}}
  def transition(from_state, to_state) do
    if allowed_transition?(from_state, to_state) do
      {:ok, to_state}
    else
      {:error, {:invalid_transition, from_state, to_state}}
    end
  end

  @spec allowed_transition?(atom(), atom()) :: boolean()
  def allowed_transition?(from_state, to_state) do
    to_state in Map.get(@transitions, from_state, [])
  end

  @spec terminal?(atom()) :: boolean()
  def terminal?(:closed), do: true
  def terminal?(_state), do: false
end
