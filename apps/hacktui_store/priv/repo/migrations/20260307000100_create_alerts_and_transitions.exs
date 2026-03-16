defmodule HacktuiStore.Repo.Migrations.CreateAlertsAndTransitions do
  use Ecto.Migration

  def change do
    create table(:alerts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alert_id, :string, null: false
      add :title, :string, null: false
      add :severity, :string, null: false
      add :state, :string, null: false
      add :disposition, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:alerts, [:alert_id])

    create table(:alert_transitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :alert_id, :string, null: false
      add :from_state, :string, null: false
      add :to_state, :string, null: false
      add :reason, :text
      add :actor_id, :string
      add :occurred_at, :utc_datetime_usec, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end
  end
end
