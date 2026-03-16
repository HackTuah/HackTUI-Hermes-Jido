defmodule HacktuiTui.WorkflowSpec do
  @moduledoc """
  Pure workflow specification for a TUI screen or view.
  """

  @enforce_keys [:name, :title, :read_model, :columns, :command_classes]
  defstruct [:name, :title, :read_model, :columns, :command_classes, :empty_state]

  @type t :: %__MODULE__{
          name: atom(),
          title: String.t(),
          read_model: atom(),
          columns: [atom()],
          command_classes: [atom()],
          empty_state: String.t() | nil
        }
end
