defmodule Vereis.Queryable do
  @moduledoc """
  Behavior for queryable schemas. Schemas implementing this behavior
  define their own `query/2` function that handles filtering logic.

  Inspired by Vetspire's Queryable pattern - contexts call `Schema.query(filters)`,
  and GraphQL resolvers use the same interface via dataloader.
  """

  import Ecto.Query

  defmacro __using__(_opts) do
    quote do
      @behaviour unquote(__MODULE__)

      import Ecto.Query
      import Vereis.Queryable

      @impl unquote(__MODULE__)
      def base_query do
        from(x in __MODULE__, as: :self)
      end

      @impl unquote(__MODULE__)
      def query(base_query \\ base_query(), filters) do
        Enum.reduce(filters, base_query, &apply_filter(&2, &1))
      end

      defoverridable base_query: 0, query: 1, query: 2
    end
  end

  @callback query(Ecto.Queryable.t(), Keyword.t()) :: Ecto.Queryable.t()
  @callback base_query() :: Ecto.Queryable.t()
  @optional_callbacks base_query: 0, query: 2

  @doc """
  Default filter implementations that can be used in schema `query/2` callbacks.
  """
  @spec apply_filter(Ecto.Queryable.t(), {field :: atom(), value :: term()}) :: Ecto.Queryable.t()
  def apply_filter(query, {:union, union_query}) do
    from(x in query, union_all: ^union_query)
  end

  def apply_filter(query, {:select, value}) when is_atom(value) do
    from(x in query, select: field(x, ^value))
  end

  def apply_filter(query, {:select, value}) do
    from(x in query, select: ^value)
  end

  def apply_filter(query, {:preload, value}) do
    from(x in query, preload: ^value)
  end

  def apply_filter(query, {:limit, value}) do
    from(x in query, limit: ^value)
  end

  def apply_filter(query, {:offset, value}) do
    from(x in query, offset: ^value)
  end

  def apply_filter(query, {:distinct, value}) do
    from(x in query, distinct: ^value)
  end

  def apply_filter(query, {:deleted, false}) do
    from x in query, where: is_nil(x.deleted_at)
  end

  def apply_filter(query, {field, {:not, value}}) when is_list(value) do
    from(x in query, where: field(x, ^field) not in ^value)
  end

  def apply_filter(query, {field, value}) when is_list(value) do
    from(x in query, where: field(x, ^field) in ^value)
  end

  def apply_filter(query, {field, {:not, nil}}) do
    from x in query, where: not is_nil(field(x, ^field))
  end

  def apply_filter(query, {field, {:not, value}}) do
    from(x in query, where: field(x, ^field) != ^value)
  end

  def apply_filter(query, {field, nil}) do
    from x in query, where: is_nil(field(x, ^field))
  end

  def apply_filter(query, {field, value}) do
    from(x in query, where: field(x, ^field) == ^value)
  end

  def apply_filter(query, _unsupported) do
    query
  end
end
