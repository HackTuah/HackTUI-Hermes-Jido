defmodule HacktuiStore.DemoDatabase do
  @moduledoc """
  Ensures the dedicated demo database exists, is configured, and is migrated.
  """

  alias HacktuiStore.Repo

  @default_demo_db "hacktui_qualification_test"

  @spec ensure_ready!(keyword() | map()) :: :ok
  def ensure_ready!(opts \\ []) do
    opts = normalize_opts(opts)
    config = repo_config(opts)

    case Repo.__adapter__().storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, reason} -> raise "failed to create demo database: #{inspect(reason)}"
    end

    restart_store_with_repo(config)
    migrate!()
    :ok
  end

  @spec demo_db_name(keyword() | map()) :: String.t()
  def demo_db_name(opts \\ []) do
    opts = normalize_opts(opts)
    Keyword.get(opts, :database, System.get_env("HACKTUI_DB_NAME") || @default_demo_db)
  end

  defp repo_config(opts) do
    Application.get_env(:hacktui_store, Repo, [])
    |> Keyword.put(:database, demo_db_name(opts))
  end

  defp restart_store_with_repo(config) do
    if Process.whereis(HacktuiStore.Supervisor) do
      Application.stop(:hacktui_store)
    end

    Application.put_env(:hacktui_store, Repo, config)
    Application.put_env(:hacktui_store, :start_repo, true)
    {:ok, _} = Application.ensure_all_started(:hacktui_store)
  end

  defp migrate! do
    migrations_path = Path.join(to_string(:code.priv_dir(:hacktui_store)), "repo/migrations")

    {:ok, _pid, _result} =
      Ecto.Migrator.with_repo(Repo, fn repo ->
        Ecto.Migrator.run(repo, migrations_path, :up, all: true, log: false)
      end)

    :ok
  end

  defp normalize_opts(opts) when is_list(opts), do: opts
  defp normalize_opts(opts) when is_map(opts), do: Map.to_list(opts)
end
