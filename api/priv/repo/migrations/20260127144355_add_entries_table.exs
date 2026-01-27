defmodule Vereis.Repo.Migrations.AddEntriesTable do
  use Ecto.Migration

  def change do
    create table(:entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :raw_body, :text
      add :description, :text
      add :published_at, :utc_datetime
      add :source_hash, :string
      add :deleted_at, :utc_datetime
      add :headings, :map

      timestamps()
    end

    create unique_index(:entries, [:slug])
    create index(:entries, [:deleted_at])
    create index(:entries, [:published_at])
  end
end
