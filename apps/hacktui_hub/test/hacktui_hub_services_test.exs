defmodule HacktuiHub.ServicesTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.ActorRef

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

  alias HacktuiHub.{
    AuditService,
    CaseworkService,
    DetectionService,
    IngestService,
    PolicyService,
    ResponseGovernanceService
  }

  setup do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)

    %{actor: actor, now: ~U[2026-03-07 00:00:00Z]}
  end

  test "ingest accepts an observation command into an observation accepted event", %{
    actor: actor,
    now: now
  } do
    command = %AcceptObservation{
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

    assert {:ok, %ObservationAccepted{} = event} =
             IngestService.accept_observation(command,
               event_id: "evt-1",
               accepted_at: now
             )

    assert event.observation_id == "obs-1"
    assert event.event_id == "evt-1"
  end

  test "detection creates and transitions alerts", %{actor: actor, now: now} do
    create = %CreateAlert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      observation_refs: ["obs-1"],
      actor: actor
    }

    transition = %TransitionAlert{
      alert_id: "alert-1",
      from_state: :open,
      to_state: :acknowledged,
      reason: "Analyst review started",
      actor: actor
    }

    assert {:ok, alert, %AlertCreated{} = created} =
             DetectionService.create_alert(create, event_id: "evt-2", occurred_at: now)

    assert {:ok, _updated_alert, %AlertTransitioned{} = moved} =
             DetectionService.transition_alert(alert, transition,
               event_id: "evt-3",
               occurred_at: now
             )

    assert created.alert_id == "alert-1"
    assert moved.to_state == :acknowledged
  end

  test "detection rejects invalid alert state transitions", %{actor: actor, now: now} do
    command = %TransitionAlert{
      alert_id: "alert-1",
      from_state: :closed,
      to_state: :suppressed,
      reason: "This should fail",
      actor: actor
    }

    create = %CreateAlert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      observation_refs: ["obs-1"],
      actor: actor
    }

    assert {:ok, _alert, _created} =
             DetectionService.create_alert(create, event_id: "evt-2", occurred_at: now)

    closed_alert = %HacktuiCore.Aggregates.Alert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      state: :closed,
      disposition: :unknown,
      observation_refs: ["obs-1"],
      inserted_at: now,
      updated_at: now
    }

    assert {:error, {:invalid_transition, :closed, :suppressed}} =
             DetectionService.transition_alert(closed_alert, command,
               event_id: "evt-3",
               occurred_at: now
             )
  end

  test "casework opens cases from alerts", %{actor: actor, now: now} do
    command = %OpenCase{
      case_id: "case-1",
      title: "Investigate suspicious DNS",
      source_alert_ids: ["alert-1"],
      actor: actor
    }

    assert {:ok, _case_record, %CaseOpened{} = event} =
             CaseworkService.open_case(command, event_id: "evt-4", opened_at: now)

    assert event.case_id == "case-1"
  end

  test "response governance emits request and approval events", %{actor: actor, now: now} do
    request = %RequestAction{
      action_request_id: "act-1",
      case_id: "case-1",
      action_class: :contain,
      target: "host-42",
      requested_by: actor,
      reason: "Contain suspicious host"
    }

    approve = %ApproveAction{
      action_request_id: "act-1",
      approver: actor,
      reason: "Approved by incident commander"
    }

    assert {:ok, action_request, %ActionRequested{} = request_event} =
             ResponseGovernanceService.request_action(request,
               event_id: "evt-5",
               requested_at: now
             )

    assert {:ok, _approved_request, %ActionApproved{} = approve_event} =
             ResponseGovernanceService.approve_action(action_request, approve,
               event_id: "evt-6",
               approved_at: now
             )

    assert request_event.action_class == :contain
    assert approve_event.action_request_id == "act-1"
  end

  test "policy classifies commands and audit records actions", %{actor: actor, now: now} do
    command = %OpenCase{
      case_id: "case-1",
      title: "Investigate suspicious DNS",
      source_alert_ids: ["alert-1"],
      actor: actor
    }

    assert {:ok, :curate} = PolicyService.command_class(command)

    assert {:ok, %AuditRecorded{} = event} =
             AuditService.record(:open_case, actor,
               event_id: "evt-7",
               audit_id: "audit-1",
               occurred_at: now,
               result: :allowed,
               subject: "case-1"
             )

    assert event.action == :open_case
    assert event.subject == "case-1"
  end
end
