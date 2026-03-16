defmodule HacktuiCollab do
  @moduledoc """
  Collaboration provider catalog.
  """

  @providers [:slack]

  @spec providers() :: [atom()]
  def providers, do: @providers

  @spec enabled?() :: boolean()
  def enabled? do
    enabled_providers() != []
  end

  @spec enabled_providers() :: [atom()]
  def enabled_providers do
    Application.get_env(:hacktui_collab, :enabled_providers, [])
  end
end
