defmodule HacktuiCollab.RoutingTest do
  use ExUnit.Case, async: true

  alias HacktuiCollab.Slack.{CommandRequest, Notification, Renderer, Router}

  defmodule FakeHubQueryService do
    def alert_queue, do: [%{alert_id: "alert-1"}]
    def approval_inbox, do: [%{action_request_id: "act-1"}]
    def audit_events, do: [%{audit_id: "audit-1"}]
  end

  test "routes a read-only alerts command to the hub query service" do
    request = %CommandRequest{
      request_id: "req-1",
      slack_user_id: "U123",
      command: "/hacktui",
      text: "alerts",
      channel_id: "C123",
      received_at: ~U[2026-03-07 00:00:00Z]
    }

    assert {:ok, %{command: :list_alerts, data: [%{alert_id: "alert-1"}]}} =
             Router.handle(request, query_service: FakeHubQueryService)
  end

  test "routes a read-only approvals command to the hub query service" do
    request = %CommandRequest{
      request_id: "req-2",
      slack_user_id: "U123",
      command: "/hacktui",
      text: "approvals",
      channel_id: "C123",
      received_at: ~U[2026-03-07 00:00:00Z]
    }

    assert {:ok, %{command: :pending_approvals, data: [%{action_request_id: "act-1"}]}} =
             Router.handle(request, query_service: FakeHubQueryService)
  end

  test "renders outbound Slack notifications" do
    notification = %Notification{
      notification_id: "notif-1",
      destination: "slack:#soc",
      kind: :critical_alert,
      subject_ref: "alert-1",
      body: "Suspicious DNS query detected",
      redactable: true
    }

    rendered = Renderer.render(notification)

    assert rendered.destination == "slack:#soc"
    assert rendered.text =~ "Suspicious DNS query detected"
    assert rendered.kind == :critical_alert
  end
end
