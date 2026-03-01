defmodule Hacktui.Repo.Migrations.CreateAlerts do
  use Ecto.Migration

  def change do
    create table(:alerts) do
      add :type, :string
      add :message, :text
      
      timestamps(type: :utc_datetime)
    end
  end
end
