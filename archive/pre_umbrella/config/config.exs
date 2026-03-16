import Config

config :hacktui, ecto_repos: [Hacktui.Repo]

config :hacktui, Hacktui.Repo,
  username: "hacktui",
  password: System.get_env("HACKTUI_DB_PASS"),
  hostname: "localhost",
  database: "hacktui_dev"

config :logger, :default_handler, false

# Keep file logs for forensic analysis (ensure logger_file_backend is in mix.exs)
config :logger, :error_log,
  path: "logs/forensics.log",
  level: :debug
