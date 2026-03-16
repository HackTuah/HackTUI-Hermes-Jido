defmodule HacktuiAgent.MCP.ToolCatalog do
  @moduledoc """
  Bounded MCP tool catalog derived from the approved architecture.
  """

  alias HacktuiAgent.MCP.ToolSpec

  @read_only_tools [
    %ToolSpec{
      name: :get_latest_alerts,
      command_class: :observe,
      mode: :read_only,
      description: "Read the latest alert queue entries."
    },
    %ToolSpec{
      name: :get_sensor_logs,
      command_class: :observe,
      mode: :read_only,
      description: "Read recent sensor logs."
    },
    %ToolSpec{
      name: :get_jido_responses,
      command_class: :observe,
      mode: :read_only,
      description: "Read recent Jido agent responses."
    },
    %ToolSpec{
      name: :get_case_timeline,
      command_class: :observe,
      mode: :read_only,
      description: "Read the timeline for a single case."
    }
  ]

  @proposal_tools [
    %ToolSpec{
      name: :draft_report,
      command_class: :notify_export,
      mode: :proposal,
      description: "Draft a report for analyst review."
    },
    %ToolSpec{
      name: :propose_action,
      command_class: :contain,
      mode: :proposal,
      description: "Propose an approval-governed action request."
    }
  ]

  @spec read_only_tools() :: [ToolSpec.t()]
  def read_only_tools, do: @read_only_tools

  @spec proposal_tools() :: [ToolSpec.t()]
  def proposal_tools, do: @proposal_tools

  @spec all() :: [ToolSpec.t()]
  def all, do: @read_only_tools ++ @proposal_tools
end
