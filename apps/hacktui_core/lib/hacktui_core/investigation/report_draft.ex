defmodule HacktuiCore.Investigation.ReportDraft do
  @moduledoc """
  Pure report drafting logic for bounded investigation summaries.
  """

  @spec build(String.t(), map()) :: map()
  def build(case_id, correlation) when is_binary(case_id) and is_map(correlation) do
    alert_text =
      correlation
      |> Map.get(:matched_alert_ids, [])
      |> Enum.join(", ")

    indicator_text =
      correlation
      |> Map.get(:shared_indicators, [])
      |> Enum.join(", ")

    %{
      case_id: case_id,
      summary:
        "Draft report for #{case_id}: correlated alerts [#{alert_text}] across indicators [#{indicator_text}]",
      matched_alert_ids: Map.get(correlation, :matched_alert_ids, []),
      shared_indicators: Map.get(correlation, :shared_indicators, [])
    }
  end
end
