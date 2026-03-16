defmodule HacktuiCollab.ContractsTest do
  use ExUnit.Case, async: true

  alias HacktuiCollab.Slack.{CommandRequest, Contract, Notification}

  test "defines Slack inbound and outbound contract structs" do
    assert %CommandRequest{} = %CommandRequest{
             request_id: "req-1",
             slack_user_id: "U123",
             command: "/hacktui",
             text: "alerts",
             channel_id: "C123",
             received_at: ~U[2026-03-07 00:00:00Z]
           }

    assert %Notification{} = %Notification{
             notification_id: "notif-1",
             destination: "slack:#soc",
             kind: :critical_alert,
             subject_ref: "alert-1",
             body: "Suspicious DNS query detected",
             redactable: true
           }
  end

  test "defines the Slack contract for currently wired commands" do
    assert :list_alerts in Contract.read_only_commands()
    assert :pending_approvals in Contract.read_only_commands()
    assert :audit_events in Contract.read_only_commands()
    assert Contract.approval_commands() == []
    assert :critical_alert in Contract.delivery_kinds()
    assert :approval_request in Contract.delivery_kinds()
    assert :validate_signature in Contract.required_callbacks()
  end
end
