defmodule HacktuiHub.ResponseGovernanceService do
  @moduledoc """
  Hub-facing service wrapper around pure response command handlers.
  """

  alias HacktuiCore.CommandHandlers.Response

  defdelegate request_action(command, opts), to: Response, as: :handle
  defdelegate approve_action(action_request, command, opts), to: Response, as: :handle
end
