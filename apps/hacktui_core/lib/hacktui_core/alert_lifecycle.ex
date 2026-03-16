defmodule HacktuiCore.AlertLifecycle do
  @moduledoc """
  Alert lifecycle values and transition rules agreed in the architecture.
  """

  @states [:open, :acknowledged, :investigating, :suppressed, :resolved, :closed]
  @dispositions [
    :unknown,
    :true_positive,
    :benign_true_activity,
    :false_positive,
    :duplicate,
    :expected_recurring_activity
  ]

  @transitions %{
    open: [:acknowledged, :investigating, :suppressed, :resolved],
    acknowledged: [:investigating, :suppressed, :resolved],
    investigating: [:suppressed, :resolved],
    suppressed: [:open, :acknowledged],
    resolved: [:open, :closed],
    closed: [:open]
  }

  @spec states() :: [atom()]
  def states, do: @states

  @spec dispositions() :: [atom()]
  def dispositions, do: @dispositions

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
