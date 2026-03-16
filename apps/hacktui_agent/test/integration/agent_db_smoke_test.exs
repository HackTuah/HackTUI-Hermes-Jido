defmodule HacktuiAgent.AgentDbSmokeTest do
  use ExUnit.Case, async: false

  @moduletag :integration

  alias HacktuiAgent.Health
  alias HacktuiAgent.TestSupport.Integration

  setup_all do
    Integration.require_db_env!()
    Application.put_env(:hacktui_store, :start_repo, true)
    Application.put_env(:hacktui_agent, :enabled_backends, [:jido])
    Integration.start_repo!()
    Integration.migrate!()
    {:ok, _} = Application.ensure_all_started(:hacktui_hub)

    if Process.whereis(HacktuiAgent.Supervisor) do
      Application.stop(:hacktui_agent)
    end

    {:ok, _} = Application.ensure_all_started(:hacktui_agent)

    on_exit(fn ->
      Application.put_env(:hacktui_agent, :enabled_backends, [])
      Application.stop(:hacktui_agent)
      Application.stop(:hacktui_hub)
      Integration.stop_repo!()
    end)

    :ok
  end

  test "db-backed + agent-enabled mode health is explicit" do
    status = Health.status()
    assert status.mode == :jido_enabled
    assert status.enabled?
    assert status.jido_enabled?
    assert status.jido_instance_started?
  end
end
