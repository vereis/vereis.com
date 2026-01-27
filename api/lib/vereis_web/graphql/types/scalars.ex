defmodule VereisWeb.GraphQL.Types.Scalars do
  @moduledoc "Custom scalar types for GraphQL."

  use Absinthe.Schema.Notation

  @desc "DateTime scalar in ISO 8601 format"
  scalar :datetime do
    parse(fn
      %Absinthe.Blueprint.Input.String{value: value} ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> {:ok, datetime}
          {:error, _} -> :error
        end

      _ ->
        :error
    end)

    serialize(fn
      %DateTime{} = datetime -> DateTime.to_iso8601(datetime)
      _ -> nil
    end)
  end
end
