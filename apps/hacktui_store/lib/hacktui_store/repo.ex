defmodule HacktuiStore.Repo do
  @moduledoc """
  Ecto repository boundary for HackTUI durable workflow records.
  """

  use Ecto.Repo,
    otp_app: :hacktui_store,
    adapter: Ecto.Adapters.Postgres
end
