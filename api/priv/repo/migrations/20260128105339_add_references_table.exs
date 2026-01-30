defmodule Vereis.Repo.Migrations.AddReferencesTable do
  # excellent_migrations:safety-assured-for-this-file column-reference-added
  use Ecto.Migration

  def change do
    create table(:references, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :source_slug,
          references(:entries, column: :slug, type: :string, on_delete: :delete_all),
          null: false

      add :target_slug,
          references(:entries, column: :slug, type: :string, on_delete: :delete_all),
          null: false

      add :type, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:references, [:source_slug])
    create index(:references, [:target_slug])
    create unique_index(:references, [:source_slug, :target_slug, :type])
  end
end
