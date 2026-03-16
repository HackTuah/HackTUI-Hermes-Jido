defmodule HacktuiStore.Schema.AlertTransition do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "alert_transitions" do
    field(:alert_id, :string)
    field(:from_state, :string)
    field(:to_state, :string)
    field(:reason, :string)
    field(:actor_id, :string)
    field(:occurred_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(transition, attrs) do
    transition
    |> cast(attrs, [
      :id,
      :alert_id,
      :from_state,
      :to_state,
      :reason,
      :actor_id,
      :occurred_at,
      :metadata
    ])
    |> validate_required([:alert_id, :from_state, :to_state, :occurred_at])
  end
end
