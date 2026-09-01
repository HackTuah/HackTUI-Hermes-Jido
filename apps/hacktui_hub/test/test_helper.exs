defmodule HacktuiHub.TestSupport.Integration do
  alias Ecto.Adapters.SQL.Sandbox
  alias HacktuiStore.Repo

  @tables [
    "alert_transitions",
    "alerts",
    "case_timeline_entries",
    "cases",
    "action_requests",
    "audit_events"
  ]

  @spec require_db_env!() :: :ok
  def require_db_env! do
    if System.get_env("HACKTUI_DB_PASS") in [nil, ""] do
      raise "HACKTUI_DB_PASS must be set in the environment for integration qualification"
    end

    :ok
  end

  @spec start_repo!() :: :ok
  def start_repo! do
    if Application.spec(:hacktui_store, :modules) && Process.whereis(HacktuiStore.Supervisor) do
      Application.stop(:hacktui_store)
    end

    Application.put_env(:hacktui_store, :start_repo, true)
    {:ok, _} = Application.ensure_all_started(:hacktui_store)
    :ok
  end

  @spec stop_repo!() :: :ok
  def stop_repo! do
    Application.stop(:hacktui_store)
    :ok
  end

  @spec migrate!() :: [term()]
  def migrate! do
    migrations_path = Path.join(to_string(:code.priv_dir(:hacktui_store)), "repo/migrations")

    with_auto_mode(fn ->
      {:ok, _pid, result} =
        Ecto.Migrator.with_repo(Repo, fn repo ->
          Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
        end)

      result
    end)
  end

  defp with_auto_mode(fun) do
    Sandbox.mode(Repo, :auto)

    try do
      fun.()
    after
      Sandbox.mode(Repo, :manual)
    end
  end

  @spec migration_statuses() :: [tuple()]
  def migration_statuses do
    {:ok, _pid, result} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.migrations/1)
    result
  end

  @spec checkout!() :: :ok
  def checkout! do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  @spec cleanup!() :: :ok
  def cleanup! do
    sql = "TRUNCATE TABLE " <> Enum.join(@tables, ", ") <> " RESTART IDENTITY CASCADE"
    _ = Ecto.Adapters.SQL.query!(Repo, sql, [])
    :ok
  end
end

defmodule HacktuiHub.TestSupport.FakeTransactionRepo do
  @moduledoc """
  Declaring the behaviour is the point: this double silently lacked `get_by/2` for as
  long as `Runtime.persist_alert_correlation_metadata/7` has called it, and three tests
  failed with `UndefinedFunctionError` rather than a compile-time warning.
  """
  @behaviour HacktuiStore.RepoBehaviour

  @impl true
  def transaction(multi) do
    ops = Ecto.Multi.to_list(multi)

    Enum.reduce_while(ops, {:ok, %{}}, fn
      {name, {:run, fun}}, {:ok, acc} ->
        case fun.(__MODULE__, acc) do
          {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
          {:error, reason} -> {:halt, {:error, name, reason, acc}}
        end

      {name, {:update_all, _q, _u, _o} = op}, {:ok, acc} ->
        _ = op
        {:cont, {:ok, Map.put(acc, name, {1, nil})}}

      {name, op}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, name, op)}}
    end)
  end

  # No correlated alert exists, so the correlation path takes its insert branch.
  @impl true
  def get_by(_schema, _clauses), do: nil

  @impl true
  def all(_query), do: []

  @impl true
  def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
end

defmodule HacktuiHub.TestSupport.FakeQueryRepo do
  @moduledoc """
  Returns rows shaped like the read model, not `{source, schema}` tuples.

  The previous `all(query), do: [query.from.source]` returned a bare
  `{"alerts", Alert}` tuple, which `QueryService.normalize_alert/1` has no clause for —
  so the test asserted against a shape the real repo never produces.
  """
  @behaviour HacktuiStore.RepoBehaviour

  @impl true
  def all(_query) do
    [
      %{
        alert_id: "alert-fake-1",
        title: "Fake alert",
        severity: "high",
        state: "open",
        disposition: "unknown",
        metadata: %{},
        indicators: []
      }
    ]
  end

  @impl true
  def get_by(_schema, _clauses), do: nil

  @impl true
  def transaction(_multi), do: {:ok, %{}}

  @impl true
  def update(changeset), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
end

ExUnit.start(exclude: [integration: true])
