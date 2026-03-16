defmodule HacktuiCollab.Slack.Contract do
  @moduledoc """
  Slack boundary contract metadata for the collaboration edge.
  """

  @read_only_commands [:list_alerts, :pending_approvals, :audit_events]
  @approval_commands []
  @delivery_kinds [:critical_alert, :case_update, :approval_request, :shift_digest]
  @required_callbacks [:validate_signature, :post_message, :post_ephemeral]

  @spec read_only_commands() :: [atom()]
  def read_only_commands, do: @read_only_commands

  @spec approval_commands() :: [atom()]
  def approval_commands, do: @approval_commands

  @spec delivery_kinds() :: [atom()]
  def delivery_kinds, do: @delivery_kinds

  @spec required_callbacks() :: [atom()]
  def required_callbacks, do: @required_callbacks
end
