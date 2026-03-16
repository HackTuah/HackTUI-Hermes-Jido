defmodule HacktuiStore.Health do
  @moduledoc """
  Reports the current store runtime mode and production-relevant health facts.
  """

  @health_query "SELECT 1"

  @spec status() :: map()
  def status do
    repo_enabled? = Application.get_env(:hacktui_store, :start_repo, false)
    repo_config = Application.get_env(:hacktui_store, HacktuiStore.Repo)
    repo_started? = Process.whereis(HacktuiStore.Repo) != nil
    connectivity = connectivity_status(repo_enabled?, repo_started?)
    config_errors = production_config_errors(repo_enabled?, repo_config)

    %{
      mode: runtime_mode(repo_enabled?, connectivity),
      repo_enabled?: repo_enabled?,
      repo_started?: repo_started?,
      repo_configured?: repo_config != nil,
      repo_configuration_valid?: valid_repo_config?(repo_config),
      repo_configuration_errors: config_errors,
      production_configuration_ready?: config_errors == [],
      repo_connectivity: connectivity,
      supervisor_started?: Process.whereis(HacktuiStore.Supervisor) != nil,
      task_supervisor_started?: Process.whereis(HacktuiStore.TaskSupervisor) != nil
    }
  end

  defp runtime_mode(false, _connectivity), do: :safe_no_repo
  defp runtime_mode(true, :ok), do: :db_backed
  defp runtime_mode(true, status), do: {:degraded, status}

  defp connectivity_status(false, _repo_started?), do: :disabled
  defp connectivity_status(true, false), do: :repo_not_started

  defp connectivity_status(true, true) do
    case query_repo() do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp query_repo do
    case Ecto.Adapters.SQL.query(HacktuiStore.Repo, @health_query, [], timeout: 5_000) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, Exception.message(error)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp valid_repo_config?(nil), do: false

  defp valid_repo_config?(config) when is_list(config) do
    Keyword.has_key?(config, :url) or
      (Keyword.has_key?(config, :database) and Keyword.has_key?(config, :hostname))
  end

  defp valid_repo_config?(_), do: false

  defp production_config_errors(false, _repo_config), do: ["repo disabled"]
  defp production_config_errors(_repo_enabled?, nil), do: ["repo configuration missing"]

  defp production_config_errors(repo_enabled?, repo_config) do
    HacktuiStore.RuntimeConfig.production_repo_config_errors(repo_enabled?, repo_config)
  end
end
