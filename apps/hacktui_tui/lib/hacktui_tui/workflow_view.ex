defmodule HacktuiTui.WorkflowView do
  @moduledoc """
  Loaded workflow view made of a static spec and query-backed rows.
  """

  @enforce_keys [:spec, :rows]
  defstruct [:spec, :rows]

  @type t :: %__MODULE__{
          spec: HacktuiTui.WorkflowSpec.t(),
          rows: list()
        }
end
