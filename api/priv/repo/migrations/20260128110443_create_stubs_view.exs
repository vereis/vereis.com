defmodule Vereis.Repo.Migrations.CreateStubsView do
  # excellent_migrations:safety-assured-for-this-file raw_sql_executed
  use Ecto.Migration

  def up do
    execute """
    CREATE VIEW stubs AS
    SELECT DISTINCT
      NULL AS id,
      r.target_slug AS slug,
      NULL AS title,
      NULL AS body,
      NULL AS raw_body,
      NULL AS description,
      NULL AS published_at,
      NULL AS source_hash,
      NULL AS deleted_at,
      NULL AS headings,
      MIN(r.inserted_at) AS inserted_at,
      MAX(r.inserted_at) AS updated_at
    FROM "references" r
    WHERE NOT EXISTS (
      SELECT 1 FROM entries e
      WHERE e.slug = r.target_slug
      AND e.deleted_at IS NULL
    )
    GROUP BY r.target_slug
    """
  end

  def down do
    execute "DROP VIEW IF EXISTS stubs"
  end
end
