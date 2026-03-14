import Config

config :hacktui_store, HacktuiStore.Repo,
  username: System.get_env("HACKTUI_DB_USER", "hacktui"),
  password: System.get_env("HACKTUI_DB_PASS", "postgres"),
  hostname: System.get_env("HACKTUI_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("HACKTUI_DB_PORT", "5432")),
  database: System.get_env("HACKTUI_DB_NAME", "hacktui_qualification_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5
