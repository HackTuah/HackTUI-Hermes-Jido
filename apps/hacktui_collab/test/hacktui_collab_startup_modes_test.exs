defmodule HacktuiCollab.StartupModesTest do
  use ExUnit.Case, async: false

  alias HacktuiCollab.Health

  setup do
    previous = Application.get_env(:hacktui_collab, :enabled_providers)

    on_exit(fn ->
      Application.put_env(:hacktui_collab, :enabled_providers, previous || [])
    end)

    :ok
  end

  test "reports disabled mode by default" do
    Application.put_env(:hacktui_collab, :enabled_providers, [])

    assert %{mode: :disabled, enabled?: false, enabled_providers: []} = Health.status()
  end

  test "reports enabled mode when slack provider is configured" do
    Application.put_env(:hacktui_collab, :enabled_providers, [:slack])

    assert %{mode: :enabled, enabled?: true, enabled_providers: [:slack]} = Health.status()
  end

  test "supervisor child list includes runtime workers only when enabled" do
    Application.put_env(:hacktui_collab, :enabled_providers, [])
    {:ok, {_flags, children}} = HacktuiCollab.Supervisor.init([])
    refute Enum.any?(children, &match?({Task.Supervisor, _}, &1))

    Application.put_env(:hacktui_collab, :enabled_providers, [:slack])
    {:ok, {_flags, children}} = HacktuiCollab.Supervisor.init([])
    assert Enum.any?(children, &match?(%{id: HacktuiCollab.TaskSupervisor}, &1))
  end
end
