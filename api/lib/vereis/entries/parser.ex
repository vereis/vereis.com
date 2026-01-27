defmodule Vereis.Entries.Parser do
  @moduledoc "Parses markdown files with YAML frontmatter into Entry attributes."

  alias Vereis.Entries.Entry

  @spec parse(String.t()) :: map()
  def parse(content) when is_binary(content) do
    parse_frontmatter(%{}, content)
  end

  defp parse_frontmatter(acc, content) do
    [_empty, yaml, body] = String.split(content, ~r/^---\n/m, parts: 3)
    frontmatter = YamlElixir.read_from_string!(yaml)
    valid_fields = :fields |> Entry.__schema__() |> Map.new(&{to_string(&1), &1})

    Enum.reduce(frontmatter, Map.put(acc, :raw_body, String.trim(body)), fn
      {key, value}, acc when is_map_key(valid_fields, key) ->
        Map.put(acc, valid_fields[key], value)

      _key_value, acc ->
        acc
    end)
  rescue
    _ -> acc
  end
end
