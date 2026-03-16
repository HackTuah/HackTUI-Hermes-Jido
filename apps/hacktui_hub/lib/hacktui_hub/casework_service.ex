defmodule HacktuiHub.CaseworkService do
  @moduledoc """
  Hub-facing service wrapper around pure casework command handlers.
  """

  alias HacktuiCore.CommandHandlers.Casework

  defdelegate open_case(command, opts), to: Casework, as: :handle
  defdelegate transition_case(case_record, command, opts), to: Casework, as: :handle
end
