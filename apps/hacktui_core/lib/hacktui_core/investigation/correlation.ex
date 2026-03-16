defmodule HacktuiCore.Investigation.Correlation do
  @moduledoc """
  Pure correlation logic for bounded investigation context.
  """

  @spec correlate(String.t(), [map()], [map()]) :: map()
  def correlate(case_id, alerts, timeline)
      when is_binary(case_id) and is_list(alerts) and is_list(timeline) do
    timeline_indicators =
      timeline
      |> Enum.flat_map(fn entry -> Map.get(entry, :indicators, []) end)
      |> Enum.uniq()

    matched_alerts =
      alerts
      |> Enum.filter(fn alert ->
        indicators = Map.get(alert, :indicators, [])
        Enum.any?(indicators, &(&1 in timeline_indicators))
      end)

    shared_indicators =
      matched_alerts
      |> Enum.flat_map(fn alert -> Map.get(alert, :indicators, []) end)
      |> Enum.filter(&(&1 in timeline_indicators))
      |> Enum.uniq()
      |> Enum.sort()

    matched_alert_ids =
      matched_alerts
      |> Enum.map(&Map.get(&1, :alert_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()

    %{
      case_id: case_id,
      matched_alert_ids: matched_alert_ids,
      shared_indicators: shared_indicators
    }
  end
end
