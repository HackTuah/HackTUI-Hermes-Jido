defmodule HacktuiStore.Schema.CaseTimelineEntry do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "case_timeline_entries" do
    field(:case_id, :string)
    field(:entry_type, :string)
    field(:summary, :string)
    field(:occurred_at, :utc_datetime_usec)
    field(:actor_id, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:id, :case_id, :entry_type, :summary, :occurred_at, :actor_id, :metadata])
    |> validate_required([:case_id, :entry_type, :occurred_at])
  end
end
