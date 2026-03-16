defmodule HacktuiStore.Projections.CaseBoardProjection do
  @moduledoc """
  Projection metadata for the TUI case board read model.
  """

  @fields [:case_id, :title, :status, :assigned_to, :updated_at]

  @spec name() :: atom()
  def name, do: :case_board

  @spec fields() :: [atom()]
  def fields, do: @fields
end
