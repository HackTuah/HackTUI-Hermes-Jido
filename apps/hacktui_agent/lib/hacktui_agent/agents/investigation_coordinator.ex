defmodule HacktuiAgent.Agents.InvestigationCoordinator do
  @moduledoc """
  Jido agent for bounded multi-step investigation flows.
  """

  use Jido.Agent,
    name: "investigation_coordinator",
    description: "Coordinates a deterministic investigation and correlation flow for a case.",
    schema: [
      status: [type: :atom, default: :idle],
      case_id: [type: :string, required: true],
      context: [type: :map, default: %{}],
      correlation: [type: :map, default: %{}],
      report_draft: [type: :map, default: %{}]
    ],
    signal_routes: [
      {"hacktui.investigation.start", HacktuiAgent.Actions.Investigation.CorrelateContext, 0},
      {"hacktui.correlation.triggered", HacktuiAgent.Actions.Investigation.CorrelateContext, 0}
    ]
end
