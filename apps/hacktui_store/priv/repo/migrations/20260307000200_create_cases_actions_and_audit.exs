defmodule HacktuiStore.Repo.Migrations.CreateCasesActionsAndAudit do
  use Ecto.Migration

  def change do
    create table(:cases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :case_id, :string, null: false
      add :title, :string, null: false
      add :status, :string, null: false
      add :assigned_to, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:cases, [:case_id])

    create table(:case_timeline_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :case_id, :string, null: false
      add :entry_type, :string, null: false
      add :summary, :text
      add :occurred_at, :utc_datetime_usec, null: false
      add :actor_id, :string
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create table(:action_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action_request_id, :string, null: false
      add :case_id, :string, null: false
      add :action_class, :string, null: false
      add :target, :string
      add :approval_status, :string, null: false
      add :requested_by, :string
      add :approved_by, :string
      add :approved_at, :utc_datetime_usec
      add :reason, :text
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:action_requests, [:action_request_id])

    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :audit_id, :string, null: false
      add :action, :string, null: false
      add :result, :string, null: false
      add :actor_id, :string
      add :subject, :string
      add :occurred_at, :utc_datetime_usec, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:audit_events, [:audit_id])
  end
end
