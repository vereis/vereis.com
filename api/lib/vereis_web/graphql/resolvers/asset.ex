defmodule VereisWeb.GraphQL.Resolvers.Asset do
  @moduledoc "GraphQL resolvers for Asset queries."

  alias Vereis.Assets
  alias Vereis.Assets.Asset
  alias VereisWeb.GraphQL.Pagination

  def asset(_parent, %{slug: slug}, _resolution) do
    case Assets.get_asset(slug: slug) do
      nil -> {:error, "Asset not found"}
      asset -> {:ok, asset}
    end
  end

  def assets(args, _resolution) do
    {pagination_args, args} = Pagination.pop_args!(args)

    args
    |> Keyword.new()
    |> Asset.query()
    |> Pagination.paginate(pagination_args)
  end
end
