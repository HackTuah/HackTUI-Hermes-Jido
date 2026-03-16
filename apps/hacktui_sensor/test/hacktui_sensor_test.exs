defmodule HacktuiSensorTest do
  use ExUnit.Case, async: false

  alias HacktuiHub.{IngestService, QueryService}

  test "starts collector supervision boundaries and ingests live observations locally" do
    IngestService.reset_recent_observations()

    assert {:ok, _} = Application.ensure_all_started(:hacktui_hub)
    assert {:ok, _} = Application.ensure_all_started(:hacktui_sensor)

    assert Process.whereis(HacktuiSensor.CollectorsSupervisor)
    assert Process.whereis(HacktuiSensor.TaskSupervisor)

    children = Supervisor.which_children(HacktuiSensor.CollectorsSupervisor)
    assert Enum.any?(children, fn {_id, pid, _type, _modules} -> is_pid(pid) end)

    assert %{hub_node: nil, hub_module: HacktuiHub.IngestService} = :sys.get_state(HacktuiSensor.Forwarder)

    assert_eventually(fn ->
      snapshot = QueryService.live_dashboard_snapshot()
      observations = snapshot.observations

      observations != [] and
        Enum.any?(observations, fn observation ->
          observation.kind == "process_signals" and
            is_map(observation.payload) and
            Map.has_key?(observation.payload, "message_queue_len")
        end)
    end)
  end

  test "declares expected collector categories" do
    assert :packet_capture in HacktuiSensor.collectors()
    assert :journald in HacktuiSensor.collectors()
    assert :process_signals in HacktuiSensor.collectors()
  end

  defp assert_eventually(fun, attempts \\ 20)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      assert true
    else
      Process.sleep(100)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("condition was not met in time")
end
