defmodule HacktuiHub.AuditService do
  @moduledoc """
  Hub-facing service wrapper around pure audit command handlers.
  """

  alias HacktuiCore.CommandHandlers.Audit

  defdelegate record(action, actor, opts), to: Audit, as: :handle
end
