defmodule HacktuiCore.ContractsTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.{ActorRef, ResourceRef}

  alias HacktuiCore.Commands.{
    AcceptObservation,
    ApproveAction,
    CreateAlert,
    OpenCase,
    RequestAction,
    TransitionAlert
  }

  alias HacktuiCore.Events.{
    ActionApproved,
    ActionRequested,
    AlertCreated,
    AlertTransitioned,
    AuditRecorded,
    CaseOpened,
    ObservationAccepted
  }

  test "builds actor and resource value objects" do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)
    resource = ResourceRef.new!(kind: :case, id: "case-1", scope: :hub)

    assert actor.id == "analyst-1"
    assert actor.type == :human
    assert resource.kind == :case
    assert resource.scope == :hub
  end

  test "defines command structs for the core operational flows" do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)

    assert %AcceptObservation{} = %AcceptObservation{
             observation_id: "obs-1",
             envelope_version: 1,
             summary: "Suspicious process execution observed",
             raw_message: "suspicious process execution observed",
             metadata: %{},
             severity: "medium",
             confidence: 0.75,
             kind: :dns_query,
             source: :sensor,
             payload: %{kind: :dns_query},
             observed_at: ~U[2026-03-07 00:00:00Z],
             received_at: ~U[2026-03-07 00:00:01Z],
             actor: actor
           }

    assert %CreateAlert{} = %CreateAlert{
             alert_id: "alert-1",
             title: "Suspicious DNS query",
             severity: :high,
             observation_refs: ["obs-1"],
             actor: actor
           }

    assert %TransitionAlert{} = %TransitionAlert{
             alert_id: "alert-1",
             from_state: :open,
             to_state: :acknowledged,
             reason: "Analyst picked it up",
             actor: actor
           }

    assert %OpenCase{} = %OpenCase{
             case_id: "case-1",
             title: "Investigate suspicious DNS",
             source_alert_ids: ["alert-1"],
             actor: actor
           }

    assert %RequestAction{} = %RequestAction{
             action_request_id: "act-1",
             case_id: "case-1",
             action_class: :contain,
             target: "host-42",
             requested_by: actor,
             reason: "Contain a suspected compromised host"
           }

    assert %ApproveAction{} = %ApproveAction{
             action_request_id: "act-1",
             approver: actor,
             reason: "Approved by incident commander"
           }
  end

  test "defines domain event structs for the main workflow facts" do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)

    assert %ObservationAccepted{} = %ObservationAccepted{
             event_id: "evt-1",
             observation_id: "obs-1",
             source: :sensor,
             accepted_at: ~U[2026-03-07 00:00:01Z],
             actor: actor
           }

    assert %AlertCreated{} = %AlertCreated{
             event_id: "evt-2",
             alert_id: "alert-1",
             title: "Suspicious DNS query",
             severity: :high,
             occurred_at: ~U[2026-03-07 00:00:02Z],
             actor: actor
           }

    assert %AlertTransitioned{} = %AlertTransitioned{
             event_id: "evt-3",
             alert_id: "alert-1",
             from_state: :open,
             to_state: :acknowledged,
             occurred_at: ~U[2026-03-07 00:00:03Z],
             actor: actor,
             reason: "Analyst review started"
           }

    assert %CaseOpened{} = %CaseOpened{
             event_id: "evt-4",
             case_id: "case-1",
             title: "Investigate suspicious DNS",
             source_alert_ids: ["alert-1"],
             opened_at: ~U[2026-03-07 00:00:04Z],
             actor: actor
           }

    assert %ActionRequested{} = %ActionRequested{
             event_id: "evt-5",
             action_request_id: "act-1",
             case_id: "case-1",
             action_class: :contain,
             target: "host-42",
             requested_at: ~U[2026-03-07 00:00:05Z],
             actor: actor,
             reason: "Contain a suspected compromised host"
           }

    assert %ActionApproved{} = %ActionApproved{
             event_id: "evt-6",
             action_request_id: "act-1",
             approved_at: ~U[2026-03-07 00:00:06Z],
             actor: actor,
             reason: "Approved by incident commander"
           }

    assert %AuditRecorded{} = %AuditRecorded{
             event_id: "evt-7",
             audit_id: "audit-1",
             actor: actor,
             action: :approve_action,
             occurred_at: ~U[2026-03-07 00:00:06Z],
             result: :allowed,
             subject: "act-1"
           }
  end
end
