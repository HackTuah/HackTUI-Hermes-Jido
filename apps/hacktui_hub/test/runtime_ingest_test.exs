defmodule HacktuiHub.RuntimeIngestTest do
  @moduledoc """
  Covers the unified ingest entry point.

  Before slice 02, `Runtime.accept_observation/2` had zero production callers: the live
  sensor path went to `IngestService`, which only fills a 100-slot RAM ring buffer. It
  also could not have worked if called -- `Alerting.handle/2` did
  `Map.fetch!(payload, "alert_id")` and no sensor payload carries that key.
  """
  use ExUnit.Case, async: false

  alias HacktuiCore.Commands.AcceptObservation
  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiHub.Runtime

  # Shaped like what Collectors.Network actually emits: no alert_id anywhere.
  defp sensor_command(overrides \\ %{}) do
    now = DateTime.utc_now()

    defaults = %{
      observation_id: "obs-#{System.unique_integer([:positive])}",
      fingerprint: "fp-#{System.unique_integer([:positive])}",
      envelope_version: 1,
      source: "sensor.network",
      kind: "network.flow",
      summary: "TCP 10.0.0.4:443 -> 93.184.216.34:443",
      raw_message: "TCP 10.0.0.4:443 -> 93.184.216.34:443",
      severity: :low,
      confidence: 0.6,
      payload: %{"summary" => "flow", "severity" => "low", "src" => "10.0.0.4"},
      metadata: %{"sequence" => 1, collector: :packet_capture},
      observed_at: now,
      received_at: now,
      actor: "sensor"
    }

    struct!(AcceptObservation, Map.merge(defaults, overrides))
  end

  describe "accept_observation/2 with no repo running" do
    setup do
      refute Process.whereis(HacktuiStore.Repo),
             "this test asserts the repo-absent path; the repo must not be started"

      :ok
    end

    test "a live sensor observation with no alert_id does not raise" do
      assert {:ok, result} = Runtime.accept_observation(sensor_command())
      assert %ObservationAccepted{} = result.observation
    end

    test "reports that persistence was skipped rather than claiming a write" do
      assert {:ok, result} = Runtime.accept_observation(sensor_command())

      assert result.persistence == :skipped_no_repo
      assert result.audit_persistence == nil
      assert result.alert == nil
      refute result.promoted
    end

    test "a high-severity observation also does not raise without a repo" do
      command = sensor_command(%{payload: %{"summary" => "mimikatz", "severity" => "high"}})

      assert {:ok, result} = Runtime.accept_observation(command)
      assert result.persistence == :skipped_no_repo
    end

    test "caller metadata keys survive ingest" do
      assert {:ok, result} = Runtime.accept_observation(sensor_command())

      # normalize_metadata_map/1 used to rewrite every string key through
      # String.to_existing_atom/1, so metadata["sequence"] silently became :sequence.
      assert result.observation.metadata["sequence"] == 1
    end
  end

  describe "routing" do
    test "IngestService is reached only through Runtime" do
      # In an umbrella, a test's cwd is its own app directory.
      root = Path.expand("../../..", __DIR__)

      callers =
        root
        |> Path.join("apps/*/lib/**/*.ex")
        |> Path.wildcard()
        |> Enum.filter(fn path ->
          path |> File.read!() |> String.contains?("IngestService.accept_observation")
        end)
        |> Enum.map(&Path.relative_to(&1, root))

      assert callers == ["apps/hacktui_hub/lib/hacktui_hub/runtime.ex"],
             "live telemetry must not bypass the persisting path; got: #{inspect(callers)}"
    end
  end
end
