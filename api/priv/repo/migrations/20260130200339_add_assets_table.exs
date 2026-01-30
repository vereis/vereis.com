defmodule Vereis.Repo.Migrations.AddAssetsTable do
  use Ecto.Migration

  def change do
    create table(:assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :slug, :string, null: false
      add :content_type, :string, null: false
      add :data, :binary, null: false
      add :metadata, :map
      add :source_hash, :string, null: false
      add :deleted_at, :utc_datetime

      timestamps()
    end

    create unique_index(:assets, [:slug])
    create index(:assets, [:deleted_at])
    create index(:assets, [:content_type])
  end
end
