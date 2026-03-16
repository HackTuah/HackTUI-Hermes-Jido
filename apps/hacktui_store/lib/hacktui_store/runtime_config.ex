defmodule HacktuiStore.RuntimeConfig do
  @moduledoc """
  Production-focused validation helpers for store runtime configuration.
  """

  @default_username "hacktui"
  @default_password "postgres"
  @default_hostname "localhost"
  @qualification_database "hacktui_qualification_test"

  @spec production_repo_config_errors(boolean(), keyword()) :: [String.t()]
  def production_repo_config_errors(start_repo?, repo_config) when is_list(repo_config) do
    []
    |> require_repo_enabled(start_repo?)
    |> require_value(repo_config, :database, "HACKTUI_DB_NAME must be set")
    |> require_value(repo_config, :username, "HACKTUI_DB_USER must be set")
    |> require_value(repo_config, :password, "HACKTUI_DB_PASS must be set")
    |> require_value(repo_config, :hostname, "HACKTUI_DB_HOST must be set")
    |> reject_default(repo_config, :database, @qualification_database,
      "HACKTUI_DB_NAME cannot use the qualification/demo database"
    )
    |> reject_default(repo_config, :username, @default_username,
      "HACKTUI_DB_USER cannot use the default demo username"
    )
    |> reject_default(repo_config, :password, @default_password,
      "HACKTUI_DB_PASS cannot use the default demo password"
    )
    |> reject_default(repo_config, :hostname, @default_hostname,
      "HACKTUI_DB_HOST cannot default to localhost in production"
    )
    |> Enum.reverse()
  end

  def production_repo_config_errors(_start_repo?, _repo_config) do
    ["repo configuration must be a keyword list"]
  end

  defp require_repo_enabled(errors, true), do: errors
  defp require_repo_enabled(errors, false), do: ["HACKTUI_START_REPO must be enabled in production" | errors]

  defp require_value(errors, repo_config, key, message) do
    case Keyword.get(repo_config, key) do
      nil -> [message | errors]
      "" -> [message | errors]
      _value -> errors
    end
  end

  defp reject_default(errors, repo_config, key, forbidden_value, message) do
    if Keyword.get(repo_config, key) == forbidden_value do
      [message | errors]
    else
      errors
    end
  end
end
