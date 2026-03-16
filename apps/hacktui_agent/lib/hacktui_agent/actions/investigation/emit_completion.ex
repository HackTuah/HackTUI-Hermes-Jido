defmodule HacktuiAgent.Actions.Investigation.EmitCompletion do
  @moduledoc """
  Emits a completion signal after investigation correlation and report drafting.
  """

  alias Jido.Agent.Directive
  alias Jido.Signal

  use Jido.Action,
    name: "investigation_emit_completion",
    description: "Emit an investigation completed signal for downstream consumers.",
    schema: []

  def run(_params, %{state: state}) do
    signal =
      Signal.new!(
        "hacktui.investigation.completed",
        %{
          case_id: state.case_id,
          correlation: state.correlation,
          report_draft: state.report_draft
        },
        source: "/hacktui/agent/investigation"
      )

    {:ok, %{status: :completed}, [Directive.emit(signal)]}
  end
end
