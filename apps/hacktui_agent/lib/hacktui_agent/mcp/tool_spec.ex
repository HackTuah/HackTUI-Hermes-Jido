defmodule HacktuiAgent.MCP.ToolSpec do
  @moduledoc """
  Typed MCP tool contract exposed to bounded agent runs.
  """

  @enforce_keys [:name, :command_class, :mode, :description]
  defstruct [:name, :command_class, :mode, :description]

  @type t :: %__MODULE__{
          name: atom(),
          command_class: atom(),
          mode: :read_only | :proposal,
          description: String.t()
        }
end
