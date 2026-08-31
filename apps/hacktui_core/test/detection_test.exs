defmodule HacktuiCore.DetectionTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.ActorRef
  alias HacktuiCore.Detection
  alias HacktuiCore.Events.ObservationAccepted

  defp observation(payload, opts \\ []) do
    %ObservationAccepted{
      event_id: "evt-1",
      observation_id: Keyword.get(opts, :observation_id, "obs-1"),
      source: "sensor",
      kind: Keyword.get(opts, :kind, "network.flow"),
      payload: payload,
      metadata: %{},
      accepted_at: ~U[2026-03-14 00:00:00Z],
      actor: %ActorRef{id: "sensor", type: :service, role: :sensor, source: :hacktui_sensor}
    }
  end

  describe "promote?/1" do
    test "promotes high and critical severity, string or atom" do
      for severity <- ["high", "critical", "HIGH", :high, :critical] do
        assert Detection.promote?(observation(%{"severity" => severity})),
               "expected #{inspect(severity)} to promote"
      end
    end

    test "does not promote routine severities" do
      for severity <- ["low", "medium", "info", :low, :medium, "nonsense", nil] do
        refute Detection.promote?(observation(%{"severity" => severity})),
               "expected #{inspect(severity)} not to promote"
      end
    end

    test "does not promote when severity is absent" do
      refute Detection.promote?(observation(%{"summary" => "a routine dns lookup"}))
    end

    test "promotes when the payload carries an explicit alert_id, preserving replay" do
      assert Detection.promote?(observation(%{"alert_id" => "alert-1", "severity" => "low"}))
    end

    test "an empty alert_id is not an alert_id" do
      refute Detection.promote?(observation(%{"alert_id" => ""}))
    end

    test "accepts atom payload keys" do
      assert Detection.promote?(observation(%{severity: :critical}))
    end
  end

  describe "alert_id_for/1" do
    test "uses an explicit alert_id when present" do
      assert Detection.alert_id_for(observation(%{"alert_id" => "alert-1"})) == "alert-1"
    end

    test "derives a deterministic id from the observation id otherwise" do
      obs = observation(%{"severity" => "high"}, observation_id: "obs-abc")

      assert Detection.alert_id_for(obs) == "auto-obs-abc"
      assert Detection.alert_id_for(obs) == Detection.alert_id_for(obs)
    end

    test "distinct observations get distinct ids" do
      a = Detection.alert_id_for(observation(%{}, observation_id: "obs-a"))
      b = Detection.alert_id_for(observation(%{}, observation_id: "obs-b"))

      refute a == b
    end
  end

  describe "severity_of/1" do
    test "normalises known severities and never creates atoms" do
      assert Detection.severity_of(%{"severity" => "Critical"}) == :critical
      assert Detection.severity_of(%{severity: :low}) == :low
      assert Detection.severity_of(%{"severity" => "not-a-real-severity"}) == :unknown
      assert Detection.severity_of(%{}) == :unknown
      assert Detection.severity_of(nil) == :unknown
    end
  end
end
