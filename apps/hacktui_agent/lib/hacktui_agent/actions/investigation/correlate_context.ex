defmodule HacktuiAgent.Actions.Investigation.CorrelateContext do
  @moduledoc """
  Correlates the investigation context already gathered by the hub.
  """

  use Jido.Action,
    name: "investigation_correlate_context",
    description: "Correlate case context and alert context to identify shared indicators.",
    schema: []

  def run(_params, %{state: state}) do
    alerts = get_in(state, [:context, :alerts]) || []
    timeline = get_in(state, [:context, :timeline]) || []
    correlation = HacktuiCore.Investigation.Correlation.correlate(state.case_id, alerts, timeline)

    {:ok, %{status: :correlated, correlation: correlation}}
  end
end
