defmodule VereisWeb.Dataloader do
  @moduledoc """
  Unified Dataloader source for efficient batched loading across all schemas.
  """

  alias Vereis.Repo

  @doc """
  Returns a Dataloader source for efficient batched loading.
  """
  @spec source() :: Dataloader.Ecto.t()
  def source do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  defp query(schema, params) do
    filters = Map.to_list(params)

    if function_exported?(schema, :query, 1) do
      schema.query(filters)
    else
      raise ArgumentError,
            "Schema #{inspect(schema)} must implement query/1 for Dataloader support"
    end
  end
end
