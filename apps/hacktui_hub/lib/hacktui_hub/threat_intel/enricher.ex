defmodule HacktuiHub.ThreatIntel.Enricher do
  @moduledoc """
  Attaches threat context to an accepted observation.

  A match is written to `metadata[:threat_context]` as the `Indexer` entry map —
  `%{keyword:, severity:, source:}`. That is an **atom** key holding a **map**, which is
  what every consumer already expected:

    * `HacktuiHub.IngestService` reads `Map.get(metadata, :threat_context, %{})`
    * `HacktuiHub.Runtime.normalize_threat_context/1` accepts only a map
    * the TUI's purple `!` threat marker reads `%{keyword:, severity:}`

  This module previously wrote a **string** key holding a **binary** description, so all
  three consumers silently saw nothing: the threat score bonus, `maybe_create_threat_alert/2`
  and the TUI marker were all permanently dead.
  """

  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.ThreatIntel.Indexer

  @doc """
  Enriches an observation with threat context, if any keyword matches.

  Returns the observation unchanged when nothing matches or the index is unavailable.
  """
  @spec enrich(ObservationAccepted.t(), keyword()) :: ObservationAccepted.t()
  def enrich(observation, opts \\ [])

  def enrich(%ObservationAccepted{} = observation, opts) do
    indexer = Keyword.get(opts, :indexer, Indexer)

    case indexer.lookup(searchable_text(observation)) do
      %{} = entry ->
        metadata = Map.put(observation.metadata || %{}, :threat_context, entry)
        %ObservationAccepted{observation | metadata: metadata}

      _ ->
        observation
    end
  end

  def enrich(observation, _opts), do: observation

  # Only fields an operator would search: the raw log line and the summary.
  defp searchable_text(%ObservationAccepted{payload: payload}) when is_map(payload) do
    [
      Map.get(payload, "raw_message"),
      Map.get(payload, :raw_message),
      Map.get(payload, "summary"),
      Map.get(payload, :summary)
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
  end

  defp searchable_text(_observation), do: ""
end
