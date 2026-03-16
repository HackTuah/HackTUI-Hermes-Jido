defmodule HacktuiTui.DemoTerminalView do
  @moduledoc """
  Honest bounded terminal view for the demo path.

  This is not a full-screen interactive TUI.
  It is a compact operator dashboard over the current bounded workflow result.
  """

  @spec render(map()) :: String.t()
  def render(data) do
    """
    ========================================
    HACKTUI DEMO VIEW (BOUNDED TERMINAL MODE)
    ========================================
    Case ID: #{data.case_id}
    Investigation Status: #{data.investigation_status}

    Health / Status:
    #{health_lines(Map.get(data, :health_snapshot, %{}))}

    Latest Alerts:
    #{alert_lines(Map.get(data, :latest_alerts, []))}

    Active Cases:
    #{case_lines(Map.get(data, :active_cases, []))}

    Shared Indicators:
    #{bullet_lines(Map.get(data, :shared_indicators, []))}

    Latest Observations:
    #{observation_lines(Map.get(data, :latest_observations, []))}

    Current Investigation Summary:
    Summary: #{data.summary}
    Recommendation: #{data.recommendation}
    Matched Alert IDs:
    #{bullet_lines(Map.get(data, :matched_alert_ids, []))}
    Shared Indicators:
    #{bullet_lines(Map.get(data, :shared_indicators, []))}
    ========================================
    """
  end

  defp bullet_lines([]), do: "- none"
  defp bullet_lines(values), do: Enum.map_join(values, "\n", &"- #{&1}")

  defp health_lines(health_snapshot) when is_map(health_snapshot) do
    health_snapshot
    |> Enum.map(fn {name, status} -> "- #{name}: #{format_status(status)}" end)
    |> Enum.join("\n")
  end

  defp health_lines(_), do: "- unavailable"

  defp alert_lines([]), do: "- none"

  defp alert_lines(alerts) do
    Enum.map_join(alerts, "\n", fn alert ->
      "- #{Map.get(alert, :alert_id, "unknown")} | #{Map.get(alert, :severity, "unknown")} | #{Map.get(alert, :title, "untitled")}"
    end)
  end

  defp case_lines([]), do: "- none"

  defp case_lines(cases) do
    Enum.map_join(cases, "\n", fn case_record ->
      "- #{Map.get(case_record, :case_id, "unknown")} | #{Map.get(case_record, :status, "unknown")} | #{Map.get(case_record, :title, "untitled")}"
    end)
  end

  defp observation_lines([]), do: "- none available"

  defp observation_lines(observations) do
    Enum.map_join(observations, "\n", fn observation ->
      observed_at = Map.get(observation, :observed_at) || "unknown-time"
      summary = Map.get(observation, :summary) || "observation recorded"
      indicators = Map.get(observation, :indicators, []) |> Enum.join(", ")

      if indicators == "" do
        "- #{observed_at} | #{summary}"
      else
        "- #{observed_at} | #{summary} | indicators: #{indicators}"
      end
    end)
  end

  defp format_status(status) when is_map(status) do
    status
    |> Enum.map(fn {key, value} -> "#{key}=#{format_scalar(value)}" end)
    |> Enum.join(", ")
  end

  defp format_status(status), do: format_scalar(status)

  defp format_scalar(value) when is_boolean(value), do: to_string(value)
  defp format_scalar(value) when is_atom(value), do: Atom.to_string(value)
  defp format_scalar(value) when is_binary(value), do: value
  defp format_scalar(value), do: inspect(value)
end
