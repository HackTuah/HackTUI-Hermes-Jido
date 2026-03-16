defmodule HacktuiCollab.Slack.Renderer do
  @moduledoc """
  Minimal renderer for outbound Slack notifications.
  """

  alias HacktuiCollab.Slack.Notification

  @spec render(Notification.t()) :: map()
  def render(%Notification{} = notification) do
    %{
      destination: notification.destination,
      kind: notification.kind,
      subject_ref: notification.subject_ref,
      redactable: notification.redactable,
      text: "[#{notification.kind}] #{notification.body}"
    }
  end
end
