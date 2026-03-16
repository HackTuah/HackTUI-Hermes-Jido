defmodule HacktuiAgent do
  @moduledoc """
  Agent role catalog for the umbrella scaffold.
  """

  @roles [:triage, :investigation, :reporting, :runbook]

  @spec roles() :: [atom()]
  def roles, do: @roles

  @spec enabled?() :: boolean()
  def enabled? do
    enabled_backends() != []
  end

  @spec enabled_backends() :: [atom()]
  def enabled_backends do
    Application.get_env(:hacktui_agent, :enabled_backends, [])
  end

  @spec backend_enabled?(atom()) :: boolean()
  def backend_enabled?(backend) when is_atom(backend) do
    backend in enabled_backends()
  end
end
