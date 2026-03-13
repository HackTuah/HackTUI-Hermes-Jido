defmodule HacktuiHub.Replay.RunnerIngestTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.Events.ObservationAccepted
  alias HacktuiCore.Observation.Envelope
  alias HacktuiHub.Replay.Runner

  test "replay envelopes are accepted through ingest" do
    received_at = DateTime.from_naive!(~N[2026-03-01 12:00:01], "Etc/UTC")

    envelopes = [
      build_envelope(received_at, %{kind: "auth_failure", sequence: 1}),
      build_envelope(DateTime.add(received_at, 1, :second), %{kind: "auth_failure", sequence: 2})
    ]

    accepted =
      envelopes
      |> Runner.run_envelopes!()
      |> Enum.map(&extract_observation_accepted!/1)

    assert length(accepted) == 2
    assert Enum.all?(accepted, &match?(%ObservationAccepted{source: :replay}, &1))
    assert Enum.uniq(Enum.map(accepted, & &1.observation_id)) |> length() == 2
  end

  defp build_envelope(received_at, payload) do
    struct(Envelope, %{
      source: :replay,
      payload: payload,
      received_at: received_at,
      metadata: %{}
    })
  end

  defp extract_observation_accepted!(%ObservationAccepted{} = event), do: event
  defp extract_observation_accepted!([%ObservationAccepted{} = event | _]), do: event

  defp extract_observation_accepted!(other) do
    flunk("expected ObservationAccepted result, got: #{inspect(other)}")
  end
end
