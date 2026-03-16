defmodule HacktuiHub.ThreatIntelTest do
  use ExUnit.Case, async: false

  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.ThreatIntel.{Enricher, Indexer}

  setup do
    case :ets.whereis(Indexer.table()) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end

    :ok
  end

  test "loads keywords into ets and enriches matching observations" do
    :ok = Indexer.load(keywords: [%{keyword: "mimikatz", severity: :high, source: "test"}])

    observation = %ObservationAccepted{
      event_id: Ecto.UUID.generate(),
      observation_id: Ecto.UUID.generate(),
      source: "test",
      accepted_at: DateTime.utc_now(),
      actor: "test-suite",
      metadata: %{},
      payload: %{"summary" => "credential access", "raw_message" => "mimikatz executed"}
    }
    enriched = Enricher.enrich(observation)

    assert %{metadata: %{threat_context: %{keyword: "mimikatz", severity: :high, source: "test"}}} = enriched
  end

  test "ingestion remains resilient when datasets are unavailable" do
    observation = %ObservationAccepted{
      event_id: Ecto.UUID.generate(),
      observation_id: Ecto.UUID.generate(),
      source: "test",
      accepted_at: DateTime.utc_now(),
      actor: "test-suite",
      metadata: %{},
      payload: %{"raw_message" => "benign", "summary" => "normal"}
    }
    enriched = Enricher.enrich(observation, dataset_path: "/missing/path.json")

    assert enriched.metadata == %{}
  end
end