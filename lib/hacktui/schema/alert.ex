defmodule Hacktui.Schema.Alert do
  use Ecto.Schema
  import Ecto.Changeset

  schema "alerts" do
    field :type, :string
    field :message, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [:type, :message])
    |> validate_required([:type, :message])
  end
end
