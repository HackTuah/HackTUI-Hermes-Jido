defmodule HacktuiHub do
  @moduledoc """
  Authoritative hub runtime boundary.
  """

  @public_surfaces [:sensor_ingest, :tui, :mcp, :slack, :agent]

  @spec public_surfaces() :: [atom()]
  def public_surfaces, do: @public_surfaces
end
