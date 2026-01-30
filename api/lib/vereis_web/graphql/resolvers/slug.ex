defmodule VereisWeb.GraphQL.Resolvers.Slug do
  @moduledoc "GraphQL resolvers for Slug queries."

  alias Vereis.Entries
  alias Vereis.Entries.Slug
  alias VereisWeb.GraphQL.Pagination

  def slug(_parent, %{slug: slug_value}, _resolution) do
    case Entries.get_slug(slug: slug_value) do
      nil -> {:error, "Slug not found"}
      slug -> {:ok, slug}
    end
  end

  def slugs(_parent, args, _resolution) do
    {pagination_args, args} = Pagination.pop_args!(args)

    args
    |> Keyword.new()
    |> Slug.query()
    |> Pagination.paginate(pagination_args, :slug)
  end
end
