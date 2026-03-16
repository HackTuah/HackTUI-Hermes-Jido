defmodule HacktuiStore.PersistenceTest do
  use ExUnit.Case, async: true

  alias HacktuiStore.Projections.{AlertQueueProjection, CaseBoardProjection}
  alias HacktuiStore.Schema.{ActionRequest, Alert, AlertTransition, AuditEvent, CaseRecord}

  test "defines the repo boundary for postgres persistence" do
    assert HacktuiStore.Repo.__adapter__() == Ecto.Adapters.Postgres
    assert HacktuiStore.Repo.config()[:otp_app] == :hacktui_store
  end

  test "defines durable schemas for alerts, cases, actions, and audits" do
    assert Alert.__schema__(:source) == "alerts"
    assert :alert_id in Alert.__schema__(:fields)
    assert :state in Alert.__schema__(:fields)
    assert :disposition in Alert.__schema__(:fields)

    assert AlertTransition.__schema__(:source) == "alert_transitions"
    assert :from_state in AlertTransition.__schema__(:fields)
    assert :to_state in AlertTransition.__schema__(:fields)

    assert CaseRecord.__schema__(:source) == "cases"
    assert :case_id in CaseRecord.__schema__(:fields)
    assert :status in CaseRecord.__schema__(:fields)

    assert ActionRequest.__schema__(:source) == "action_requests"
    assert :action_class in ActionRequest.__schema__(:fields)
    assert :approval_status in ActionRequest.__schema__(:fields)

    assert AuditEvent.__schema__(:source) == "audit_events"
    assert :action in AuditEvent.__schema__(:fields)
    assert :result in AuditEvent.__schema__(:fields)
  end

  test "defines projection modules for operator-facing read models" do
    assert AlertQueueProjection.name() == :alert_queue
    assert :severity in AlertQueueProjection.fields()
    assert :state in AlertQueueProjection.fields()

    assert CaseBoardProjection.name() == :case_board
    assert :status in CaseBoardProjection.fields()
    assert :assigned_to in CaseBoardProjection.fields()
  end

  test "ships scaffold migrations for workflow records" do
    migrations = Path.wildcard("priv/repo/migrations/*.exs")

    assert length(migrations) >= 2
    assert Enum.any?(migrations, &String.contains?(&1, "create_alerts"))
    assert Enum.any?(migrations, &String.contains?(&1, "create_cases"))
  end
end
