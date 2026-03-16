defmodule HacktuiCollab.Slack.Router do
  @moduledoc """
  Minimal Slack command routing onto hub query services.
  """

  alias HacktuiCollab.Slack.CommandRequest
  alias HacktuiHub.QueryService

  @spec handle(CommandRequest.t(), keyword()) :: {:ok, map()} | {:error, :unsupported_command}
  def handle(%CommandRequest{text: text}, opts) do
    query_service = Keyword.get(opts, :query_service, QueryService)

    case String.trim(text) do
      "alerts" ->
        {:ok, %{command: :list_alerts, data: query_service.alert_queue()}}

      "approvals" ->
        {:ok, %{command: :pending_approvals, data: query_service.approval_inbox()}}

      "audit" ->
        {:ok, %{command: :audit_events, data: query_service.audit_events()}}

      _other ->
        {:error, :unsupported_command}
    end
  end
end
