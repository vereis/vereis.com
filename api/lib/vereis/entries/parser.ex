defmodule Vereis.Entries.Parser do
  @moduledoc "Parses markdown files with YAML frontmatter into Entry attributes."

  alias Floki.HTMLParser.Html5ever
  alias Vereis.Assets
  alias Vereis.Assets.Metadata.Image
  alias Vereis.Entries.Entry
  alias Vereis.Entries.Utils

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

  @typep parse_result ::
           {:ok, {map(), [map()]}} | {:error, term()}

  @glob "**/*.md"

  @spec parse(String.t()) :: {:ok, [parse_result()]} | {:error, term()}
  def parse(dir) when is_binary(dir) do
    if File.dir?(dir) do
      {:ok,
       dir
       |> Path.join(@glob)
       |> Path.wildcard()
       |> Task.async_stream(&parse(&1, dir), timeout: :infinity)
       |> Enum.map(fn {:ok, result} -> result end)}
    else
      {:error, {:invalid_directory, "#{dir} is not a valid directory"}}
    end
  end

  @spec parse(String.t(), String.t()) :: parse_result()
  def parse(filepath, base_dir) when is_binary(filepath) and is_binary(base_dir) do
    with {:ok, content} <- File.read(filepath) do
      parse(filepath, content, base_dir)
    end
  end

  @spec parse(String.t(), String.t(), String.t()) :: parse_result()
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
         {:ok, {attrs, inline_refs}} <- render_markdown(attrs, slug) do
      hash = :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

      entry_attrs =
        attrs
        |> Map.put(:slug, slug)
        |> Map.put(:source_hash, hash)

      ref_attrs =
        inline_refs
        |> Enum.map(&%{target_slug: &1, source_slug: slug, type: :inline})
        |> Enum.concat(Enum.map(frontmatter_refs, &%{target_slug: &1, source_slug: slug, type: :frontmatter}))
        |> Enum.uniq_by(&{&1.target_slug, &1.type})

      {:ok, {entry_attrs, ref_attrs}}
    else
      {:error, reason} ->
        {:error, {:parse_error, reason, filepath}}
    end
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
              |> Enum.filter(&is_binary/1)
              |> Enum.map(fn ref -> ref |> String.trim() |> String.trim_leading("/") end)
              |> Enum.reject(&(&1 == ""))

            {acc, normalized_refs}

          {"permalinks", permalinks}, {acc, refs} when is_list(permalinks) ->
            normalized_perms =
              permalinks
              |> Enum.filter(&is_binary/1)
              |> Enum.map(fn perm -> perm |> String.trim() |> String.trim_leading("/") end)
              |> Enum.reject(&(&1 == ""))
              |> Enum.uniq()

            {Map.put(acc, :permalinks, normalized_perms), refs}

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

  defp render_markdown(attrs, slug) when is_map_key(attrs, :raw_body) do
    with {:ok, html} <- MDEx.to_html(attrs.raw_body, @markdown_opts),
         {:ok, {processed_html, headings, inline_refs}} <- postprocess_html(html, slug) do
      result =
        attrs
        |> Map.put(:body, processed_html)
        |> Map.put(:headings, headings)

      {:ok, {result, inline_refs}}
    end
  end

  defp render_markdown(_attrs, _slug) do
    {:error, :missing_raw_body}
  end

  defp postprocess_html(html, slug) do
    with {:ok, ast} <- Floki.parse_document(html, html_parser: Html5ever) do
      {modified_html, {headings, inline_refs}} =
        Floki.traverse_and_update(ast, {[], []}, &process_node(&1, &2, slug))

      {:ok, {Floki.raw_html(modified_html), Enum.reverse(headings), Enum.reverse(inline_refs)}}
    end
  end

  defp process_node({"h" <> level_str = tag, attrs, children}, {headings, refs}, _entry_slug)
       when level_str in ["1", "2", "3", "4", "5", "6"] do
    level = String.to_integer(level_str)
    title = Floki.text({tag, attrs, children})
    link = Utils.slugify(title)

    heading = %{level: level, title: title, link: link}

    {{tag, [{"id", link} | attrs], children}, {[heading | headings], refs}}
  end

  defp process_node({"a", attrs, children}, {headings, refs}, entry_slug) do
    with {"data-wikilink", "true"} <- List.keyfind(attrs, "data-wikilink", 0),
         {"href", url} <- List.keyfind(attrs, "href", 0),
         {:ok, slug} <- Utils.path_to_slug(String.trim(url), entry_slug) do
      updated_attrs = List.keystore(attrs, "href", 0, {"href", "/" <> slug})
      {{"a", updated_attrs, children}, {headings, [slug | refs]}}
    else
      _ ->
        {{"a", attrs, children}, {headings, refs}}
    end
  end

  defp process_node({"img", attrs, children}, {headings, refs}, entry_slug) do
    case List.keyfind(attrs, "src", 0) do
      {"src", src} ->
        process_image(src, attrs, children, {headings, refs}, entry_slug)

      nil ->
        {{"img", attrs, children}, {headings, refs}}
    end
  end

  defp process_node(other, acc, _entry_slug) do
    {other, acc}
  end

  @image_exts [".png", ".jpg", ".jpeg", ".gif"]

  defp process_image(src, attrs, children, acc, entry_slug) do
    with {:ok, path} <- Utils.path_to_slug(src, entry_slug),
         slug = Utils.swap_ext(path, ".webp", @image_exts),
         %{metadata: %Image{} = meta} = asset <- Assets.get_asset(slug: slug) do
      updated_attrs =
        attrs
        |> List.keystore("src", 0, {"src", "/assets/#{asset.slug}"})
        |> List.keystore("style", 0, {"style", "--lqip:#{meta.lqip_hash}"})
        |> List.keystore("width", 0, {"width", to_string(meta.width)})
        |> List.keystore("height", 0, {"height", to_string(meta.height)})

      link_attrs = [
        {"href", "/assets/#{asset.slug}"},
        {"target", "_blank"},
        {"rel", "noopener"}
      ]

      {{"a", link_attrs, [{"img", updated_attrs, children}]}, acc}
    else
      _ -> {{"img", attrs, children}, acc}
    end
  end
end
