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

  @spec parse(String.t(), String.t()) :: map()
  def parse(filepath, base_dir) when is_binary(filepath) and is_binary(base_dir) do
    parse(filepath, File.read!(filepath), base_dir)
  end

  @spec parse(String.t(), String.t(), String.t()) :: map()
  def parse(filepath, content, base_dir) when is_binary(filepath) and is_binary(content) and is_binary(base_dir) do
    %{}
    |> Map.put(:slug, derive_slug(filepath, base_dir))
    |> Map.put(:source_hash, compute_hash(content))
    |> parse_frontmatter(content)
    |> render_markdown()
  end

  defp derive_slug(filepath, base_dir) do
    slug =
      filepath
      |> Path.relative_to(base_dir)
      |> Path.rootname()
      |> then(&("/" <> &1))

    if slug == "/index", do: "/", else: slug
  end

  defp compute_hash(content) do
    :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)
  end

  defp parse_frontmatter(attrs, content) do
    [_empty, yaml, body] = String.split(content, ~r/^---\n/m, parts: 3)
    frontmatter = YamlElixir.read_from_string!(yaml)
    valid_fields = :fields |> Entry.__schema__() |> Map.new(&{to_string(&1), &1})
    attrs = Map.put(attrs, :raw_body, String.trim(body))

    attrs =
      case Map.get(frontmatter, "references") do
        refs when is_list(refs) ->
          normalized_refs =
            refs
            |> Enum.map(&normalize_slug/1)
            |> Enum.reject(&(&1 == ""))

          Map.put(attrs, :frontmatter_refs, normalized_refs)

        _ ->
          attrs
      end

    Enum.reduce(frontmatter, attrs, fn
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
         preprocessed_body = preprocess_wikilinks(attrs.raw_body),
         {:ok, ast} <- MDEx.parse_document(preprocessed_body, @markdown_opts),
         {:ok, html} <- MDEx.to_html(ast, @markdown_opts),
         {:ok, {processed_html, headings, inline_refs}} <- postprocess_html(html) do
      attrs
      |> Map.put(:body, processed_html)
      |> Map.put(:headings, headings)
      |> Map.put(:inline_refs, inline_refs)
    else
      _error ->
        attrs
    end
  end

  defp preprocess_wikilinks(markdown) do
    # Replace [[slug]] with <a data-slug="slug">slug</a>
    # This preserves the wiki-link for HTML while marking it for extraction
    Regex.replace(~r/\[\[([^\]]+)\]\]/, markdown, fn _, slug ->
      normalized_slug = normalize_slug(slug)

      if normalized_slug == "" do
        # If slug is empty after normalization, keep the original syntax
        "[[#{slug}]]"
      else
        ~s(<a data-slug="#{normalized_slug}">#{slug}</a>)
      end
    end)
  end

  defp normalize_slug(slug) do
    # Trim and ensure slug starts with /
    slug = String.trim(slug)

    cond do
      slug == "" -> ""
      String.starts_with?(slug, "/") -> slug
      true -> "/" <> slug
    end
  end

  defp postprocess_html(html) do
    with {:ok, ast} <- Floki.parse_document(html, html_parser: Html5ever) do
      {modified_html, {headings, inline_refs}} =
        Floki.traverse_and_update(ast, {[], []}, &process_node/2)

      {:ok, {Floki.raw_html(modified_html), Enum.reverse(headings), Enum.reverse(inline_refs)}}
    end
  end

  defp process_node({"h" <> level_str = tag, attrs, children}, {headings, inline_refs})
       when level_str in ["1", "2", "3", "4", "5", "6"] do
    level = String.to_integer(level_str)
    title = Floki.text({tag, attrs, children})
    link = slugify(title)

    heading = %{level: level, title: title, link: link}

    {{tag, [{"id", link} | attrs], children}, {[heading | headings], inline_refs}}
  end

  defp process_node({"a", attrs, _children} = node, {headings, inline_refs}) do
    case List.keyfind(attrs, "data-slug", 0) do
      {"data-slug", slug} ->
        {node, {headings, [slug | inline_refs]}}

      nil ->
        {node, {headings, inline_refs}}
    end
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
