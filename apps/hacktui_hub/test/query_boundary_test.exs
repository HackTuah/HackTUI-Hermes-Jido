defmodule HacktuiHub.QueryBoundaryTest do
  @moduledoc """
  Structural guard: one public read path per operator read model.

  `HacktuiStore.ReadModels.alert_queue_query/0` was a **second** definition of the alert
  queue. It selected `entry_type` and `payload`, which `HacktuiStore.Schema.AuditEvent`
  does not declare and no migration creates, so it could never execute against a database
  -- and it had no production caller, because the live path is
  `HacktuiHub.QueryService.alert_queue/1`. Ecto validates fields at planning time, not at
  build time, so the function returned a `%Ecto.Query{}` happily and would have raised only
  on `Repo.all`. Its only test asserted `query.from.source`, which never plans.

  Deleting it fixed the failure. This test is what stops it coming back: the defect was
  duplication, and a duplicate can be reintroduced by anyone who does not know the history.
  Follows the same shape as the ingest-routing guard in
  `apps/hacktui_hub/test/runtime_ingest_test.exs`.
  """
  use ExUnit.Case, async: true

  # cwd is the app directory when an umbrella test runs.
  @root Path.expand("../../..", __DIR__)

  defp lib_sources do
    @root |> Path.join("apps/*/lib/**/*.ex") |> Path.wildcard()
  end

  defp defining(pattern) do
    lib_sources()
    |> Enum.filter(&(&1 |> File.read!() |> String.match?(pattern)))
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  test "alert_queue is defined in exactly one module" do
    assert defining(~r/^\s{2}def\s+alert_queue/m) == [
             "apps/hacktui_hub/lib/hacktui_hub/query_service.ex"
           ]
  end

  test "no module exposes a second alert-queue query builder" do
    # Catches the reintroduced shape by name rather than by call site: a *_query builder
    # returning an Ecto query over alerts is how the duplicate was expressed.
    assert defining(~r/^\s{2}def\s+alert_queue_query/m) == []
  end

  test "the other operator read models are also singly defined" do
    for name <- ~w(case_board approval_inbox audit_events) do
      definers = defining(~r/^\s{2}def\s+#{name}\(/m)

      assert definers == ["apps/hacktui_hub/lib/hacktui_hub/query_service.ex"],
             "#{name} should have exactly one public definition; got: #{inspect(definers)}"
    end
  end
end
