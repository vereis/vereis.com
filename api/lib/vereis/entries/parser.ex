defmodule Vereis.Entries.Parser do
  @moduledoc "Parses markdown files with YAML frontmatter into Entry attributes."

  alias Floki.HTMLParser.Html5ever
  alias Vereis.Entries.Entry

  @markdown_opts [
    extension: [table: true, strikethrough: true, underline: true, shortcodes: true],
    parse: [smart: true],
    render: [unsafe_: true],
    syntax_highlight: [formatter: {:html_inline, theme: "github_dark"}]
  ]

  @spec parse(String.t()) :: map()
  def parse(content) when is_binary(content) do
    %{}
    |> parse_frontmatter(content)
    |> render_markdown()
  end

  defp parse_frontmatter(attrs, content) do
    [_empty, yaml, body] = String.split(content, ~r/^---\n/m, parts: 3)
    frontmatter = YamlElixir.read_from_string!(yaml)
    valid_fields = :fields |> Entry.__schema__() |> Map.new(&{to_string(&1), &1})

    Enum.reduce(frontmatter, Map.put(attrs, :raw_body, String.trim(body)), fn
      {key, value}, acc when is_map_key(valid_fields, key) ->
        Map.put(acc, valid_fields[key], value)

      _key_value, acc ->
        acc
    end)
  rescue
    _ -> attrs
  end

  defp render_markdown(attrs) do
    with true <- Map.has_key?(attrs, :raw_body),
         {:ok, ast} <- MDEx.parse_document(attrs.raw_body, @markdown_opts),
         {:ok, html} <- MDEx.to_html(ast, @markdown_opts),
         {:ok, {processed_html, headings}} <- postprocess_html(html) do
      attrs
      |> Map.put(:body, processed_html)
      |> Map.put(:headings, headings)
    else
      _error ->
        attrs
    end
  end

  defp postprocess_html(html) do
    with {:ok, ast} <- Floki.parse_document(html, html_parser: Html5ever) do
      {modified_html, headings} = Floki.traverse_and_update(ast, [], &process_node/2)
      {:ok, {Floki.raw_html(modified_html), Enum.reverse(headings)}}
    end
  end

  defp process_node({"h" <> level_str = tag, attrs, children}, acc) when level_str in ["1", "2", "3", "4", "5", "6"] do
    level = String.to_integer(level_str)
    title = Floki.text({tag, attrs, children})
    link = slugify(title)

    heading = %{level: level, title: title, link: link}

    {{tag, [{"id", link} | attrs], children}, [heading | acc]}
  end

  defp process_node(other, acc) do
    {other, acc}
  end

  defp slugify(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-Za-z0-9\s-]/u, "")
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
