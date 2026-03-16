import Config

if System.get_env("HACKTUI_MCP_STDIO") in ["1", "true"] do
  config :logger, level: :warning
  config :logger, :default_handler, false
else
  config :logger, level: :info
end

config :tzdata, :autoupdate, :disabled

config :hacktui_hub,
  primary_interface: :tui,
  architecture_doc: "ARCHITECTURE.md"

config :hacktui_sensor,
  forwarding_mode: :hub

config :hacktui_collab,
  enabled_providers: [],
  supported_providers: [:slack]

config :hacktui_agent,
  enabled_backends: [],
  supported_roles: [:triage, :investigation, :reporting, :runbook]

config :hacktui_agent, HacktuiAgent.Jido,
  max_tasks: 100,
  agent_pools: []

config :hacktui_store,
  ecto_repos: [HacktuiStore.Repo],
  start_repo: false

config :hacktui_store, HacktuiStore.Repo,
  username: System.get_env("HACKTUI_DB_USER", "hacktui"),
  password: System.get_env("HACKTUI_DB_PASS", "postgres"),
  hostname: System.get_env("HACKTUI_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("HACKTUI_DB_PORT", "5432")),
  database: System.get_env("HACKTUI_DB_NAME", "hacktui_qualification_test"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: false,
  pool_size: 5

import_config "#{config_env()}.exs"
