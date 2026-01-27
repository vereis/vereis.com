defmodule VereisWeb.GraphQL.Pagination do
  @moduledoc "Helper for cursor-based pagination in GraphQL."

  @max_limit 100
  @pagination_keys [:first, :last, :after, :before, :order_by]

  @spec pop_args!(map()) :: {map(), map()}
  def pop_args!(args) do
    pagination_args = Map.take(args, @pagination_keys)
    args = Map.drop(args, @pagination_keys)

    {pagination_args, args}
  end

  @spec paginate(Ecto.Queryable.t(), map()) :: {:ok, map()} | {:error, String.t()}
  def paginate(query, args \\ %{}) do
    sorts =
      (args[:order_by] || [])
      |> Enum.flat_map(fn map -> Enum.map(map, fn {k, v} -> %{k => v} end) end)
      |> Kernel.++([%{id: :asc}])

    args =
      args
      |> Map.update(:first, nil, &min(&1, @max_limit))
      |> Map.update(:last, nil, &min(&1, @max_limit))
      |> Map.put(:sorts, sorts)

    fields_to_drop =
      args
      |> Enum.filter(&(match?({:order_by, _v}, &1) || match?({_k, nil}, &1)))
      |> Enum.map(fn {k, _v} -> k end)

    AbsintheRelayKeysetConnection.from_query(query, &Vereis.Repo.all/1, Map.drop(args, fields_to_drop), %{
      unique_column: :id
    })
  end
end
