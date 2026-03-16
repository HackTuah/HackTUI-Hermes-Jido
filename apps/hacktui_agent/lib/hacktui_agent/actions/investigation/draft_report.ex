defmodule HacktuiAgent.Actions.Investigation.DraftReport do
  @moduledoc """
  Drafts a deterministic investigation summary from correlated state.
  """

  use Jido.Action,
    name: "investigation_draft_report",
    description: "Draft a report from the correlated investigation state.",
    schema: []

  def run(_params, %{state: state}) do
    report_draft =
      HacktuiCore.Investigation.ReportDraft.build(state.case_id, state.correlation || %{})

    {:ok, %{status: :report_drafted, report_draft: report_draft}}
  end
end
