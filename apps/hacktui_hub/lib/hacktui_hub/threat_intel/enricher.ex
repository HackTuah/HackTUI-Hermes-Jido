defmodule HacktuiHub.ThreatIntel.Enricher do
  @moduledoc "Safe enrichment layer. Cleaned up to prevent compiler warnings."
  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.ThreatIntel.Indexer

  def enrich(%ObservationAccepted{payload: payload, metadata: metadata} = obs) do
    raw_text = to_string(payload["raw_message"] || payload[:raw_message] || payload["summary"] || payload[:summary] || "")

    case Indexer.lookup(raw_text) do
      {_keyword, description} ->
        updated_metadata = Map.put(metadata || %{}, "threat_context", description)
        %ObservationAccepted{obs | metadata: updated_metadata}
      nil ->
        obs
    end
  end
end
