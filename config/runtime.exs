import Config

parse_csv = fn value ->
  value
  |> to_string()
  |> String.split(",", trim: true)
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
end

truthy? = fn value ->
  String.downcase(to_string(value || "")) in ["1", "true", "yes", "on"]
end

if config_env() != :test do
  start_repo = truthy?.(System.get_env("HACKTUI_START_REPO", "false"))

  enabled_backends =
    System.get_env("HACKTUI_AGENT_BACKENDS", "")
    |> parse_csv.()
    |> Enum.map(&String.to_atom/1)

  enabled_providers =
    System.get_env("HACKTUI_COLLAB_PROVIDERS", "")
    |> parse_csv.()
    |> Enum.map(&String.to_atom/1)

  hub_node =
    case System.get_env("HACKTUI_HUB_NODE") do
      nil ->
        nil

      value ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end
    end

  repo_config = [
    username: System.get_env("HACKTUI_DB_USER", "hacktui"),
    password: System.get_env("HACKTUI_DB_PASS", "postgres"),
    hostname: System.get_env("HACKTUI_DB_HOST", "localhost"),
    port: String.to_integer(System.get_env("HACKTUI_DB_PORT", "5432")),
    database: System.get_env("HACKTUI_DB_NAME", "hacktui_qualification_test")
  ]

  if config_env() == :prod do
    errors = HacktuiStore.RuntimeConfig.production_repo_config_errors(start_repo, repo_config)

    if errors != [] do
      formatted_errors = Enum.map_join(errors, "\n", &"  - #{&1}")

      raise """
      invalid production runtime configuration for :hacktui_store
      #{formatted_errors}
      """
    end
  end

  config :hacktui_store, start_repo: start_repo
  config :hacktui_store, HacktuiStore.Repo, repo_config

  config :hacktui_agent, enabled_backends: enabled_backends
  config :hacktui_collab, enabled_providers: enabled_providers
  config :hacktui_sensor, hub_node: hub_node
end
