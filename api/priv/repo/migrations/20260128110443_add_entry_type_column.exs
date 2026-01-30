defmodule Vereis.Repo.Migrations.AddEntryTypeColumn do
  # excellent_migrations:safety-assured-for-this-file column-added-with-default
  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :type, :string, null: false, default: "entry"
    end

    create index(:entries, [:type])
  end
end
