defmodule HacktuiStore.Projections.AlertQueueProjection do
  @moduledoc """
  Projection metadata for the TUI alert queue read model.
  """

  @fields [:alert_id, :title, :severity, :state, :disposition, :inserted_at]

  @spec name() :: atom()
  def name, do: :alert_queue

  @spec fields() :: [atom()]
  def fields, do: @fields
end
