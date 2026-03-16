defmodule HacktuiStore.Schema.ActionRequest do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @foreign_key_type :binary_id
  schema "action_requests" do
    field(:action_request_id, :string)
    field(:case_id, :string)
    field(:action_class, :string)
    field(:target, :string)
    field(:approval_status, :string)
    field(:requested_by, :string)
    field(:approved_by, :string)
    field(:approved_at, :utc_datetime_usec)
    field(:reason, :string)
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(action_request, attrs) do
    action_request
    |> cast(attrs, [
      :id,
      :action_request_id,
      :case_id,
      :action_class,
      :target,
      :approval_status,
      :requested_by,
      :approved_by,
      :approved_at,
      :reason,
      :metadata
    ])
    |> validate_required([:action_request_id, :case_id, :action_class, :approval_status])
  end
end
