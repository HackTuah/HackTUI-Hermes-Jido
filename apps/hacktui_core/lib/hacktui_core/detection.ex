defmodule HacktuiCore.Detection do
  @moduledoc """
  Decides whether an accepted observation warrants an alert.

  This is the step that did not exist. `CommandHandlers.Alerting` converted *every*
  observation into an alert and required the payload to pre-declare its own `alert_id`,
  which only replay fixtures carry -- so live telemetry could not flow through the
  persisting path at all.

  Ingest and detection are separate concerns:

      observation -> audit event (always)
                  -> promote? -> alert -> correlate -> score -> maybe open a case

  The predicate is deliberately narrow and built only from signals the collectors already
  emit. It is not a detection engine; it is the seam where one belongs.
  """

  alias HacktuiCore.Events.ObservationAccepted

  @promote_severities [:high, :critical]

  @doc """
  True when an observation should be promoted to an alert.

  Promotes when the normalised severity is high or critical, or when the payload carries
  an explicit `alert_id` (which preserves replay-fixture behaviour).
  """
  @spec promote?(ObservationAccepted.t() | map()) :: boolean()
  def promote?(observation) do
    payload = payload_of(observation)

    explicit_alert_id?(payload) or
      severity_of(payload) in @promote_severities or
      threat_severity(observation) in @promote_severities
  end

  @doc """
  The severity of an attached threat-intel match, or `:unknown`.

  Slice 02 deliberately excluded threat-driven promotion because the ThreatIntel
  subsystem was dead — its GenServer was in no supervision tree, so its ETS table never
  existed and every lookup raised. Slice 09 made it work, so the exclusion is lifted:
  a high-confidence indicator match promotes even when the collector rated the
  observation low-severity, which is the point of having threat intel at all.
  """
  @spec threat_severity(ObservationAccepted.t() | map()) :: atom()
  def threat_severity(observation) do
    observation
    |> metadata_of()
    |> get_either(:threat_context)
    |> case do
      %{} = context -> context |> get_either(:severity) |> normalize_severity()
      _ -> :unknown
    end
  end

  @doc """
  The alert id to use for an observation.

  Uses the payload's `alert_id` when present, otherwise derives a deterministic id from
  the observation id so that repeated processing of the same observation cannot produce
  duplicate alerts.
  """
  @spec alert_id_for(ObservationAccepted.t() | map()) :: String.t()
  def alert_id_for(observation) do
    payload = payload_of(observation)

    case fetch_alert_id(payload) do
      {:ok, id} -> id
      :error -> "auto-" <> to_string(observation_id_of(observation))
    end
  end

  @doc """
  Normalises a payload severity to a known atom, or `:unknown`.

  Accepts string or atom keys and values. Never creates atoms from input.
  """
  @spec severity_of(map()) :: atom()
  def severity_of(payload) when is_map(payload) do
    payload
    |> get_either(:severity)
    |> normalize_severity()
  end

  def severity_of(_), do: :unknown

  @spec promote_severities() :: [atom()]
  def promote_severities, do: @promote_severities

  defp explicit_alert_id?(payload), do: match?({:ok, _}, fetch_alert_id(payload))

  defp fetch_alert_id(payload) when is_map(payload) do
    case get_either(payload, :alert_id) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> :error
    end
  end

  defp fetch_alert_id(_), do: :error

  defp normalize_severity(value) when is_atom(value) and not is_nil(value), do: value

  defp normalize_severity(value) when is_binary(value) do
    case String.downcase(value) do
      "critical" -> :critical
      "high" -> :high
      "medium" -> :medium
      "low" -> :low
      "info" -> :info
      _ -> :unknown
    end
  end

  defp normalize_severity(_), do: :unknown

  defp metadata_of(%ObservationAccepted{metadata: metadata}) when is_map(metadata), do: metadata
  defp metadata_of(%{metadata: metadata}) when is_map(metadata), do: metadata
  defp metadata_of(_), do: %{}

  defp payload_of(%ObservationAccepted{payload: payload}) when is_map(payload), do: payload
  defp payload_of(%{payload: payload}) when is_map(payload), do: payload
  defp payload_of(payload) when is_map(payload), do: payload
  defp payload_of(_), do: %{}

  defp observation_id_of(%ObservationAccepted{observation_id: id}), do: id
  defp observation_id_of(%{observation_id: id}), do: id
  defp observation_id_of(_), do: "unknown"

  defp get_either(map, key) when is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end
end
