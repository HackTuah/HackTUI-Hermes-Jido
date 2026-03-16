defmodule HacktuiStore.Schema.AuditEvent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "audit_events" do
    field(:audit_id, :string)
    field(:action, :string)
    field(:result, :string)
    field(:actor_id, :string)
    field(:subject, :string)
    field(:occurred_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(audit_event, attrs) do
    audit_event
    |> cast(attrs, [
      :id,
      :audit_id,
      :action,
      :result,
      :actor_id,
      :subject,
      :occurred_at,
      :metadata
    ])
    |> validate_required([:audit_id, :action, :result, :occurred_at])
  end
end
