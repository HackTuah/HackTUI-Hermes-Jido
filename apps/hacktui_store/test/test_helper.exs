defmodule HacktuiStore.TestSupport.Integration do
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

  @spec migration_statuses() :: [tuple()]
  def migration_statuses do
    with_auto_mode(fn ->
      {:ok, _pid, result} = Ecto.Migrator.with_repo(Repo, &Ecto.Migrator.migrations/1)
      result
    end)
  end

  @spec checkout!() :: :ok
  def checkout! do
    :ok = Sandbox.checkout(Repo)
  end

  @spec cleanup!() :: :ok
  def cleanup! do
    sql = "TRUNCATE TABLE " <> Enum.join(@tables, ", ") <> " RESTART IDENTITY CASCADE"
    _ = Ecto.Adapters.SQL.query!(Repo, sql, [])
    :ok
  end

  @spec public_tables!() :: [String.t()]
  def public_tables! do
    with_auto_mode(fn ->
      result =
        Ecto.Adapters.SQL.query!(
          Repo,
          "select tablename from pg_tables where schemaname = 'public' order by tablename",
          []
        )

      Enum.map(result.rows, &hd/1)
    end)
  end

  @spec reset_schema!() :: :ok
  def reset_schema! do
    with_auto_mode(fn ->
      _ = Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA public CASCADE", [])
      _ = Ecto.Adapters.SQL.query!(Repo, "CREATE SCHEMA public AUTHORIZATION CURRENT_USER", [])
      _ = Ecto.Adapters.SQL.query!(Repo, "GRANT ALL ON SCHEMA public TO public", [])
      :ok
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
end

defmodule HacktuiStore.TestSupport.FakeRepo do
  # Executes the Multi rather than merely converting it to a list. The previous version
  # never invoked Multi.run/3, so the state guards added in slice 06 had no executing
  # coverage at all -- they were shape-tested only.
  #
  # Raw operations are recorded so shape assertions remain possible; `operations/0`
  # returns them.
  def transaction(multi) do
    ops = Ecto.Multi.to_list(multi)
    Process.put({__MODULE__, :operations}, Map.new(ops))

    Enum.reduce_while(ops, {:ok, %{}}, fn
      {name, {:run, fun}}, {:ok, acc} ->
        case fun.(__MODULE__, acc) do
          {:ok, value} -> {:cont, {:ok, Map.put(acc, name, value)}}
          {:error, reason} -> {:halt, {:error, name, reason, acc}}
        end

      {name, operation}, {:ok, acc} ->
        {:cont, {:ok, Map.put(acc, name, stub_result(operation))}}
    end)
  end

  @doc "Raw Multi operations from the most recent transaction/1 in this process."
  def operations, do: Process.get({__MODULE__, :operations}, %{})

  @doc "Sets the row count update_all reports, for exercising the state guards."
  def set_update_all_count(count), do: Process.put({__MODULE__, :update_all_count}, count)

  defp stub_result({:update_all, _query, _updates, _opts}),
    do: {Process.get({__MODULE__, :update_all_count}, 1), nil}

  defp stub_result(operation), do: operation
end

ExUnit.start(exclude: [integration: true])
