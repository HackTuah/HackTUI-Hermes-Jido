import Config

# 1. Tell Elixir which Repo belongs to this app
config :hacktui, ecto_repos: [Hacktui.Repo]

# 2. Configure the database connection using your secure environment variable
config :hacktui, Hacktui.Repo,
  username: "hacktui",
  password: System.get_env("HACKTUI_DB_PASS"),
  hostname: "localhost",
  database: "hacktui_dev"

# 3. CRITICAL UI FIX: Stop debug logs from printing over the TUI
# This removes the purple [debug] SQL text from your screen.
config :logger, :console,
  level: :info

# 4. Redirect all background logs to a file for Blue Team analysis
config :logger,
  backends: [{LoggerFileBackend, :error_log}]

config :logger, :error_log,
  path: "logs/error.log",
  level: :debug
