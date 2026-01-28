defmodule Vereis.Entries.Parser do
  @moduledoc "Parses markdown files with YAML frontmatter into Entry attributes."

  alias Floki.HTMLParser.Html5ever
  alias Vereis.Entries.Entry

  @markdown_opts [
    extension: [
      table: true,
      strikethrough: true,
      underline: true,
      shortcodes: true,
      wikilinks_title_after_pipe: true
    ],
    parse: [smart: true],
    render: [unsafe_: true],
    syntax_highlight: [formatter: {:html_inline, theme: "github_dark"}]
  ]

  @spec parse(String.t(), String.t()) :: {:ok, {map(), [map()]}} | {:error, term()}
  def parse(filepath, base_dir) when is_binary(filepath) and is_binary(base_dir) do
    parse(filepath, File.read!(filepath), base_dir)
  end

  @spec parse(String.t(), String.t(), String.t()) :: {:ok, {map(), [map()]}} | {:error, term()}
  def parse(filepath, content, base_dir) when is_binary(filepath) and is_binary(content) and is_binary(base_dir) do
    slug = derive_slug(filepath, base_dir)

    cond do
      slug == "index" ->
        {:error, {:invalid_slug, "index.md at root is not supported", filepath}}

      String.ends_with?(slug, "/index") ->
        {:error, {:invalid_slug, "index.md files are not supported", filepath}}

      true ->
        do_parse(filepath, content, slug)
    end
  end

  defp derive_slug(filepath, base_dir) do
    filepath
    |> Path.relative_to(base_dir)
    |> Path.rootname()
  end

  defp do_parse(filepath, content, slug) do
    with {:ok, {attrs, frontmatter_refs}} <- parse_frontmatter(content),
         {:ok, {attrs, inline_refs}} <- render_markdown(attrs) do
      hash = :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

      entry_attrs =
        attrs
        |> Map.put(:slug, slug)
        |> Map.put(:source_hash, hash)

      ref_attrs = build_ref_attrs(inline_refs, frontmatter_refs)

      {:ok, {entry_attrs, ref_attrs}}
    else
      {:error, reason} ->
        {:error, {:parse_error, reason, filepath}}
    end
  end

  defp build_ref_attrs(inline_refs, frontmatter_refs) do
    inline = Enum.map(inline_refs, &%{target_slug: &1, type: :inline})
    frontmatter = Enum.map(frontmatter_refs, &%{target_slug: &1, type: :frontmatter})
    Enum.uniq_by(inline ++ frontmatter, &{&1.target_slug, &1.type})
  end

  defp parse_frontmatter(content) do
    valid_fields = :fields |> Entry.__schema__() |> Map.new(&{to_string(&1), &1})

    with [_empty, yaml, body] <- String.split(content, ~r/^---\n/m, parts: 3),
         {:ok, frontmatter} <- YamlElixir.read_from_string(yaml) do
      {attrs, refs} =
        Enum.reduce(frontmatter, {%{raw_body: String.trim(body)}, []}, fn
          {"references", references}, {acc, _refs} when is_list(references) ->
            normalized_refs =
              references
              |> Enum.map(fn ref -> ref |> String.trim() |> String.trim_leading("/") end)
              |> Enum.reject(&(&1 == ""))

            {acc, normalized_refs}

          {key, value}, {acc, refs} when is_map_key(valid_fields, key) ->
            {Map.put(acc, valid_fields[key], value), refs}

          _key_value, acc_refs ->
            acc_refs
        end)

      {:ok, {attrs, refs}}
    else
      error when is_list(error) ->
        {:error, {:invalid_frontmatter, error}}

      error ->
        error
    end
  end

  defp render_markdown(attrs) when is_map_key(attrs, :raw_body) do
    with {:ok, html} <- MDEx.to_html(attrs.raw_body, @markdown_opts),
         {:ok, {processed_html, headings, inline_refs}} <- postprocess_html(html) do
      result =
        attrs
        |> Map.put(:body, processed_html)
        |> Map.put(:headings, headings)

      {:ok, {result, inline_refs}}
    end
  end

  defp render_markdown(_attrs) do
    {:error, :missing_raw_body}
  end

  defp postprocess_html(html) do
    with {:ok, ast} <- Floki.parse_document(html, html_parser: Html5ever) do
      {modified_html, {headings, inline_refs}} =
        Floki.traverse_and_update(ast, {[], []}, &process_node/2)

      {:ok, {Floki.raw_html(modified_html), Enum.reverse(headings), Enum.reverse(inline_refs)}}
    end
  end

  defp process_node({"h" <> level_str = tag, attrs, children}, {headings, refs})
       when level_str in ["1", "2", "3", "4", "5", "6"] do
    level = String.to_integer(level_str)
    title = Floki.text({tag, attrs, children})
    link = slugify(title)

    heading = %{level: level, title: title, link: link}

    {{tag, [{"id", link} | attrs], children}, {[heading | headings], refs}}
  end

  defp process_node({"a", attrs, children}, {headings, refs}) do
    with {"data-wikilink", "true"} <- List.keyfind(attrs, "data-wikilink", 0),
         {"href", url} <- List.keyfind(attrs, "href", 0) do
      slug = url |> String.trim() |> String.trim_leading("/")
      {{"a", attrs, children}, {headings, [slug | refs]}}
    else
      _ ->
        {{"a", attrs, children}, {headings, refs}}
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
