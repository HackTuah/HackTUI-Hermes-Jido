defmodule HacktuiHub.RuntimeTest do
  use ExUnit.Case, async: true

  alias HacktuiCore.ActorRef

  alias HacktuiCore.Commands.{
    ApproveAction,
    CreateAlert,
    OpenCase,
    RequestAction,
    TransitionAlert,
    TransitionCase
  }

  alias HacktuiHub.{QueryService, Runtime}
  alias HacktuiHub.TestSupport.{FakeQueryRepo, FakeTransactionRepo}

  setup do
    actor = ActorRef.new!(id: "analyst-1", type: :human, role: :analyst, source: :tui)
    %{actor: actor, now: ~U[2026-03-07 00:00:00Z]}
  end

  test "orchestrates alert creation and persistence", %{actor: actor, now: now} do
    command = %CreateAlert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      observation_refs: ["obs-1"],
      actor: actor
    }

    assert {:ok, result} =
             Runtime.create_alert(command,
               repo: FakeTransactionRepo,
               event_id: "evt-1",
               occurred_at: now
             )

    assert result.aggregate.state == :open
    assert result.event.alert_id == "alert-1"
    assert {:insert, _changeset, _opts} = result.persistence.alert_insert
  end

  test "orchestrates alert transitions", %{actor: actor, now: now} do
    create = %CreateAlert{
      alert_id: "alert-1",
      title: "Suspicious DNS query",
      severity: :high,
      observation_refs: ["obs-1"],
      actor: actor
    }

    {:ok, created} =
      Runtime.create_alert(create, repo: FakeTransactionRepo, event_id: "evt-1", occurred_at: now)

    transition = %TransitionAlert{
      alert_id: "alert-1",
      from_state: :open,
      to_state: :investigating,
      reason: "Investigation started",
      actor: actor
    }

    assert {:ok, result} =
             Runtime.transition_alert(created.aggregate, transition,
               repo: FakeTransactionRepo,
               event_id: "evt-2",
               occurred_at: now
             )

    assert result.aggregate.state == :investigating

    # The double now executes the Multi, so update_all yields Ecto's {rows, nil}.
    # It previously returned the un-executed operation, which meant the state
    # guards added in slice 06 were never invoked by any test.
    assert {1, nil} = result.persistence.alert_state_update
    assert result.persistence.alert_state_guard == 1
  end

  test "orchestrates case and action flows", %{actor: actor, now: now} do
    open_case = %OpenCase{
      case_id: "case-1",
      title: "Investigate suspicious DNS",
      source_alert_ids: ["alert-1"],
      actor: actor
    }

    assert {:ok, opened_case} =
             Runtime.open_case(open_case,
               repo: FakeTransactionRepo,
               event_id: "evt-3",
               opened_at: now
             )

    assert opened_case.aggregate.status == :open

    transition_case = %TransitionCase{
      case_id: opened_case.aggregate.case_id,
      from_status: :open,
      to_status: :triage,
      reason: "Initial triage",
      actor: actor
    }

    assert {:ok, triaged_case} =
             Runtime.transition_case(opened_case.aggregate, transition_case,
               repo: FakeTransactionRepo,
               event_id: "evt-4",
               occurred_at: now
             )

    assert triaged_case.aggregate.status == :triage

    request_action = %RequestAction{
      action_request_id: "act-1",
      case_id: opened_case.aggregate.case_id,
      action_class: :contain,
      target: "host-42",
      requested_by: actor,
      reason: "Contain the host"
    }

    assert {:ok, action_request} =
             Runtime.request_action(request_action,
               repo: FakeTransactionRepo,
               event_id: "evt-5",
               requested_at: now
             )

    assert action_request.aggregate.approval_status == :pending_approval

    approve = %ApproveAction{
      action_request_id: action_request.aggregate.action_request_id,
      approver: actor,
      reason: "Approved by incident commander"
    }

    assert {:ok, approved} =
             Runtime.approve_action(action_request.aggregate, approve,
               repo: FakeTransactionRepo,
               event_id: "evt-6",
               approved_at: now
             )

    assert approved.aggregate.approval_status == :approved
  end

  test "exposes query functions over store read models" do
    # Previously asserted [{"alerts", Alert}] -- the raw {source, schema} tuple the
    # old FakeQueryRepo returned, a shape the real repo never produces and which
    # QueryService.normalize_alert/1 has no clause for. Now asserts the read model.
    assert [alert] = QueryService.alert_queue(FakeQueryRepo)
    assert alert.alert_id == "alert-fake-1"
    assert alert.state == "open"
    assert Map.has_key?(alert, :disposition)

    assert is_list(QueryService.case_board(FakeQueryRepo))
    assert is_list(QueryService.approval_inbox(FakeQueryRepo))
    assert is_list(QueryService.audit_events(FakeQueryRepo))

    assert is_list(QueryService.case_timeline(FakeQueryRepo, "case-1"))
  end
end
