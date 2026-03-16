defmodule HacktuiAgent.StartupModesTest do
  use ExUnit.Case, async: false

  alias HacktuiAgent.Health

  setup do
    previous = Application.get_env(:hacktui_agent, :enabled_backends)

    on_exit(fn ->
      Application.put_env(:hacktui_agent, :enabled_backends, previous || [])
    end)

    :ok
  end

  test "reports disabled mode by default" do
    Application.put_env(:hacktui_agent, :enabled_backends, [])

    assert %{mode: :disabled, enabled?: false, enabled_backends: []} = Health.status()
  end

  test "reports jido-enabled mode when jido backend is configured" do
    Application.put_env(:hacktui_agent, :enabled_backends, [:jido])

    assert %{mode: :jido_enabled, enabled?: true, enabled_backends: [:jido], jido_enabled?: true} =
             Health.status()
  end

  test "supervisor child list includes Jido instance only when jido is enabled" do
    Application.put_env(:hacktui_agent, :enabled_backends, [])
    {:ok, {_flags, children}} = HacktuiAgent.Supervisor.init([])
    refute Enum.any?(children, &match?(HacktuiAgent.Jido, &1))

    Application.put_env(:hacktui_agent, :enabled_backends, [:jido])
    {:ok, {_flags, children}} = HacktuiAgent.Supervisor.init([])
    assert Enum.any?(children, &match?(%{id: HacktuiAgent.Jido}, &1))
  end
end
