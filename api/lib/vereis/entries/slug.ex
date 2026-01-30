defmodule Vereis.Entries.Slug do
  @moduledoc "Schema for entry slugs, including current slugs and permalinks."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Query

  alias Vereis.Entries.Entry

  @primary_key {:slug, :string, autogenerate: false}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "slugs" do
    field :deleted_at, :utc_datetime

    belongs_to :entry, Entry

    timestamps(updated_at: false)
  end

  @impl Vereis.Queryable
  def base_query do
    from s in __MODULE__,
      as: :self,
      where: is_nil(s.deleted_at)
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    {include_deleted, filters} = Keyword.pop(filters, :include_deleted)
    base_query = (include_deleted && from(s in __MODULE__, as: :self)) || base_query

    Enum.reduce(filters, base_query, fn
      {:slug, slug}, query ->
        from s in query, where: s.slug == ^slug

      {:entry_id, entry_id}, query ->
        from s in query, where: s.entry_id == ^entry_id

      filter, query ->
        apply_filter(query, filter)
    end)
  end
end
