defmodule HacktuiCore.CommandClass do
  @moduledoc """
  Shared command classes used across the TUI, Slack, MCP, and agent surfaces.
  """

  @classes [:observe, :curate, :notify_export, :change, :contain, :destructive]

  @spec all() :: [atom()]
  def all, do: @classes
end
