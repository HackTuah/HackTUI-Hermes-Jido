defmodule Hacktui.Repo do
  use Ecto.Repo,
    otp_app: :hacktui,
    adapter: Ecto.Adapters.Postgres
end
