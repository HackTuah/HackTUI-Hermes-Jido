defmodule HacktuiCore.AggregatesTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.ActorRef
  alias HacktuiCore.Aggregates.{ActionRequest, Alert, InvestigationCase}

  alias HacktuiCore.Commands.{
    ApproveAction,
    CreateAlert,
    OpenCase,
    RequestAction,
    TransitionAlert,
    TransitionCase
  }

  alias HacktuiCore.Events.{
    ActionApproved,
    ActionRequested,
    AlertCreated,
    AlertTransitioned,
    CaseOpened,
    CaseTransitioned
  }

  setup do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)
    %{actor: actor, now: ~U[2026-03-07 00:00:00Z]}
  end

  test "creates and transitions an alert aggregate", %{actor: actor, now: now} do
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
      reason: "Analyst picked up the alert",
      actor: actor
    }

    assert {:ok, %Alert{} = alert, %AlertCreated{} = created} =
             Alert.create(create, event_id: "evt-1", occurred_at: now)

    assert alert.state == :open
    assert alert.disposition == :unknown
    assert created.alert_id == alert.alert_id

    assert {:ok, %Alert{} = transitioned, %AlertTransitioned{} = transition_event} =
             Alert.transition(alert, transition, event_id: "evt-2", occurred_at: now)

    assert transitioned.state == :acknowledged
    assert transition_event.to_state == :acknowledged
  end

  test "opens and transitions a case aggregate", %{actor: actor, now: now} do
    open_case = %OpenCase{
      case_id: "case-1",
      title: "Investigate suspicious DNS",
      source_alert_ids: ["alert-1"],
      actor: actor
    }

    transition_case = %TransitionCase{
      case_id: "case-1",
      from_status: :open,
      to_status: :triage,
      reason: "Analyst started triage",
      actor: actor
    }

    assert {:ok, %InvestigationCase{} = case_record, %CaseOpened{} = opened} =
             InvestigationCase.open(open_case, event_id: "evt-3", opened_at: now)

    assert case_record.status == :open
    assert opened.case_id == case_record.case_id

    assert {:ok, %InvestigationCase{} = transitioned, %CaseTransitioned{} = event} =
             InvestigationCase.transition(case_record, transition_case,
               event_id: "evt-4",
               occurred_at: now
             )

    assert transitioned.status == :triage
    assert event.to_status == :triage
  end

  test "requests and approves an action aggregate", %{actor: actor, now: now} do
    request = %RequestAction{
      action_request_id: "act-1",
      case_id: "case-1",
      action_class: :contain,
      target: "host-42",
      requested_by: actor,
      reason: "Contain the host"
    }

    approve = %ApproveAction{
      action_request_id: "act-1",
      approver: actor,
      reason: "Approved by incident commander"
    }

    assert {:ok, %ActionRequest{} = action_request, %ActionRequested{} = requested} =
             ActionRequest.request(request, event_id: "evt-5", requested_at: now)

    assert action_request.approval_status == :pending_approval
    assert requested.action_request_id == action_request.action_request_id

    assert {:ok, %ActionRequest{} = approved_request, %ActionApproved{} = approved} =
             ActionRequest.approve(action_request, approve, event_id: "evt-6", approved_at: now)

    assert approved_request.approval_status == :approved
    assert approved.action_request_id == action_request.action_request_id
  end

  test "rejects invalid aggregate transitions", %{actor: actor, now: now} do
    create = %CreateAlert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      observation_refs: ["obs-1"],
      actor: actor
    }

    assert {:ok, %Alert{} = alert, _event} =
             Alert.create(create, event_id: "evt-1", occurred_at: now)

    invalid_transition = %TransitionAlert{
      alert_id: "alert-1",
      from_state: :open,
      to_state: :closed,
      reason: "Invalid close from open",
      actor: actor
    }

    assert {:error, {:invalid_transition, :open, :closed}} =
             Alert.transition(alert, invalid_transition, event_id: "evt-2", occurred_at: now)
  end
end
