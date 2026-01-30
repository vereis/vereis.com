defmodule Vereis.Repo.Migrations.AddPermalinksAndSlugs do
  @moduledoc false
  # excellent_migrations:safety-assured-for-this-file column-added-with-default
  # excellent_migrations:safety-assured-for-this-file column-reference-added
  # excellent_migrations:safety-assured-for-this-file raw-sql-executed

  use Ecto.Migration

  def change do
    alter table(:entries) do
      add :permalinks, {:array, :string}, default: [], null: false
    end

    create table(:slugs, primary_key: false) do
      add :slug, :string, primary_key: true, null: false
      add :entry_id, references(:entries, type: :binary_id, on_delete: :delete_all), null: false
      add :deleted_at, :utc_datetime
      add :inserted_at, :utc_datetime, null: false
    end

    create index(:slugs, [:entry_id])
    create index(:slugs, [:deleted_at], where: "deleted_at IS NULL")

    execute(
      """
      CREATE TRIGGER sync_slugs_insert
      AFTER INSERT ON entries
      FOR EACH ROW
      BEGIN
        INSERT INTO slugs (slug, entry_id, deleted_at, inserted_at)
        VALUES (NEW.slug, NEW.id, NEW.deleted_at, NEW.inserted_at);

        INSERT INTO slugs (slug, entry_id, deleted_at, inserted_at)
        SELECT value, NEW.id, NEW.deleted_at, NEW.inserted_at
        FROM json_each(NEW.permalinks)
        WHERE value IS NOT NULL AND value != '';
      END;
      """,
      "DROP TRIGGER IF EXISTS sync_slugs_insert"
    )

    execute(
      """
      CREATE TRIGGER sync_slugs_update
      AFTER UPDATE ON entries
      FOR EACH ROW
      BEGIN
        DELETE FROM slugs WHERE entry_id = OLD.id;

        INSERT INTO slugs (slug, entry_id, deleted_at, inserted_at)
        VALUES (NEW.slug, NEW.id, NEW.deleted_at, NEW.updated_at);

        INSERT INTO slugs (slug, entry_id, deleted_at, inserted_at)
        SELECT value, NEW.id, NEW.deleted_at, NEW.updated_at
        FROM json_each(NEW.permalinks)
        WHERE value IS NOT NULL AND value != '';
      END;
      """,
      "DROP TRIGGER IF EXISTS sync_slugs_update"
    )
  end
end
