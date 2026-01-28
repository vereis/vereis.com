defmodule VereisWeb.GraphQL.Resolvers.Entry do
  @moduledoc "GraphQL resolvers for Entry queries."

  alias Vereis.Entries
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference
  alias VereisWeb.GraphQL.Pagination

  def node(%{type: :entry, id: id}, _resolution) do
    case Entries.get_entry(id: id) do
      nil -> {:error, "Entry not found"}
      entry -> {:ok, entry}
    end
  end

  def node(_node, _resolution) do
    {:error, "Unknown node type"}
  end

  def entry(_parent, %{slug: slug}, _resolution) do
    case Entries.get_entry(slug: slug) do
      nil -> {:error, "Entry not found"}
      entry -> {:ok, entry}
    end
  end

  def entries(args, _resolution) do
    {pagination_args, args} = Pagination.pop_args!(args)

    args
    |> Keyword.new()
    |> Entry.query()
    |> Pagination.paginate(pagination_args)
  end

  def references(parent, args, _resolution) do
    {pagination_args, args} = Pagination.pop_args!(args)

    args
    |> Keyword.new()
    |> Keyword.put(:slug, parent.slug)
    |> Keyword.put(:direction, :outgoing)
    |> Reference.query()
    |> Pagination.paginate(pagination_args)
  end

  def referenced_by(parent, args, _resolution) do
    {pagination_args, args} = Pagination.pop_args!(args)

    args
    |> Keyword.new()
    |> Keyword.put(:slug, parent.slug)
    |> Keyword.put(:direction, :incoming)
    |> Reference.query()
    |> Pagination.paginate(pagination_args)
  end
end
