defmodule HacktuiStore.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    children =
      [{Task.Supervisor, name: HacktuiStore.TaskSupervisor}] ++ maybe_repo_child()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp maybe_repo_child do
    if Application.get_env(:hacktui_store, :start_repo, false) do
      validate_repo_configuration!()
      [HacktuiStore.Repo]
    else
      []
    end
  end

  defp validate_repo_configuration! do
    config = Application.get_env(:hacktui_store, HacktuiStore.Repo, [])

    cond do
      config == nil or config == [] ->
        raise ArgumentError,
              "hacktui_store repo start requested but no repo config present for HacktuiStore.Repo"

      Keyword.has_key?(config, :url) ->
        :ok

      Keyword.has_key?(config, :database) and Keyword.has_key?(config, :hostname) ->
        :ok

      true ->
        raise ArgumentError,
              "hacktui_store repo start requested but repo config is incomplete; expected :url or :database + :hostname"
    end
  end
end
