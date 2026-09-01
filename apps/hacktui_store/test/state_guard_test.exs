defmodule HacktuiStore.StateGuardTest do
  @moduledoc """
  Exercises the state guards added in slice 06.

  These had **zero** executing coverage when they landed: `FakeRepo.transaction/1`
  converted the Multi to a list without running it, so `Multi.run/3` was never invoked
  and the guards were shape-tested only. The slice's FINDINGS claimed they were
  "unit-tested against stubs"; they were not.
  """
  use ExUnit.Case, async: false

  alias HacktuiCore.Aggregates.ActionRequest, as: DomainActionRequest
  alias HacktuiCore.Aggregates.Alert, as: DomainAlert
  alias HacktuiCore.Events.{ActionApproved, AlertTransitioned}
  alias HacktuiStore.{Actions, Alerts}
  alias HacktuiStore.TestSupport.FakeRepo

  setup do
    Process.delete({FakeRepo, :update_all_count})
    :ok
  end

  defp actor,
    do: %HacktuiCore.ActorRef{id: "analyst-1", type: :human, role: :analyst, source: :tui}

  defp alert_pair do
    alert = %DomainAlert{
      alert_id: "alert-1",
      title: "t",
      severity: :high,
      state: :investigating,
      disposition: :unknown,
      observation_refs: []
    }

    event = %AlertTransitioned{
      event_id: "evt-1",
      alert_id: "alert-1",
      from_state: :open,
      to_state: :investigating,
      occurred_at: ~U[2026-03-07 00:00:00Z],
      actor: actor(),
      reason: "r"
    }

    {alert, event}
  end

  defp action_pair do
    request = %DomainActionRequest{
      action_request_id: "ar-1",
      case_id: "c-1",
      action_class: :contain,
      target: "h1",
      approval_status: :approved,
      requested_by: actor(),
      reason: "r",
      approved_by: actor(),
      approved_at: ~U[2026-03-07 00:00:00Z]
    }

    event = %ActionApproved{
      event_id: "evt-2",
      action_request_id: "ar-1",
      approved_at: ~U[2026-03-07 00:00:00Z],
      actor: actor(),
      reason: "r"
    }

    {request, event}
  end

  describe "alert transition guard" do
    test "succeeds when exactly one row matched the expected state" do
      {alert, event} = alert_pair()
      FakeRepo.set_update_all_count(1)

      assert {:ok, result} = Alerts.persist_transition(FakeRepo, alert, event)
      assert result.alert_state_guard == 1
    end

    test "fails when no row matched, rather than reporting success" do
      {alert, event} = alert_pair()
      FakeRepo.set_update_all_count(0)

      assert {:error, :alert_state_guard, {:stale_transition, "open"}, _} =
               Alerts.persist_transition(FakeRepo, alert, event)
    end

    test "the query carries the from_state guard" do
      {alert, event} = alert_pair()
      FakeRepo.set_update_all_count(1)
      {:ok, _} = Alerts.persist_transition(FakeRepo, alert, event)

      {:update_all, query, _updates, _opts} = FakeRepo.operations().alert_state_update
      assert inspect(query) =~ "a0.state ==", "transition must be guarded on the prior state"
    end
  end

  describe "action approval guard" do
    test "succeeds when exactly one pending row matched" do
      {request, event} = action_pair()
      FakeRepo.set_update_all_count(1)

      assert {:ok, result} = Actions.persist_approval(FakeRepo, request, event)
      assert result.action_request_guard == 1
    end

    test "a second approval fails rather than overwriting the first approver" do
      {request, event} = action_pair()
      FakeRepo.set_update_all_count(0)

      assert {:error, :action_request_guard, :already_decided, _} =
               Actions.persist_approval(FakeRepo, request, event)
    end

    test "the query is scoped to pending_approval" do
      {request, event} = action_pair()
      FakeRepo.set_update_all_count(1)
      {:ok, _} = Actions.persist_approval(FakeRepo, request, event)

      {:update_all, query, _updates, _opts} = FakeRepo.operations().action_request_update
      assert inspect(query) =~ "pending_approval"
    end
  end
end
