defmodule Vereis.Entries.ParserTest do
  use Vereis.DataCase, async: false

  alias Vereis.Assets.Metadata.Image
  alias Vereis.Entries.Parser

  describe "parse/2" do
    test "parses frontmatter into flat attrs map" do
      content = """
      ---
      title: My Post
      description: A great post
      published_at: 2024-01-15T12:00:00Z
      ---

      # Hello World

      This is the body.
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.title == "My Post"
      assert entry_attrs.description == "A great post"
      assert entry_attrs.published_at == "2024-01-15T12:00:00Z"
      assert entry_attrs.raw_body == "# Hello World\n\nThis is the body."
    end

    test "parses frontmatter with only title" do
      content = """
      ---
      title: Simple Post
      ---

      Body content.
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.title == "Simple Post"
      assert entry_attrs.raw_body == "Body content."
    end

    test "trims body whitespace" do
      content = """
      ---
      title: Test
      ---


      Body with extra newlines.


      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.raw_body == "Body with extra newlines."
    end

    test "parses frontmatter without title (validation handled by changeset)" do
      content = """
      ---
      description: No title here
      ---

      Body
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.description == "No title here"
      refute Map.has_key?(entry_attrs, :title)
    end

    test "returns error when frontmatter delimiters are missing" do
      content = """
      title: No Delimiters

      Body content.
      """

      assert {:error, _} = Parser.parse("content/test.md", content, "content")
    end

    test "returns error when YAML is invalid" do
      content = """
      ---
      title: Test
      invalid: [unclosed
      ---

      Body
      """

      assert {:error, _} = Parser.parse("content/test.md", content, "content")
    end

    test "handles empty body" do
      content = """
      ---
      title: Test
      ---
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.raw_body == ""
    end

    test "renders markdown to HTML" do
      content = """
      ---
      title: Test
      ---

      # Hello World

      This is **bold** and this is *italic*.
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ ~r/<h1.*>Hello World<\/h1>/
      assert entry_attrs.body =~ "<strong>bold</strong>"
      assert entry_attrs.body =~ "<em>italic</em>"
    end

    test "renders markdown with code blocks" do
      content = """
      ---
      title: Test
      ---

      ```elixir
      def hello do
        :world
      end
      ```
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ ~r/<pre.*<code class="language-elixir"/
      assert entry_attrs.body =~ "hello"
      assert entry_attrs.body =~ ":world"
    end

    test "renders markdown with links and lists" do
      content = """
      ---
      title: Test
      ---

      - Item 1
      - Item 2

      [Link](https://example.com)
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ "<ul>"
      assert entry_attrs.body =~ "<li>Item 1</li>"
      assert entry_attrs.body =~ ~r/<a href="https:\/\/example\.com">Link<\/a>/
    end

    test "renders strikethrough with extension enabled" do
      content = """
      ---
      title: Test
      ---

      ~~strikethrough~~
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ "<del>strikethrough</del>"
    end

    test "adds IDs to headings for anchor links" do
      content = """
      ---
      title: Test
      ---

      # Hello World
      ## Getting Started
      ### Advanced Topics
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ ~r/<h1 id="hello-world"/
      assert entry_attrs.body =~ ~r/<h2 id="getting-started"/
      assert entry_attrs.body =~ ~r/<h3 id="advanced-topics"/
    end

    test "extracts headings metadata" do
      content = """
      ---
      title: Test
      ---

      # Hello World
      ## Getting Started
      ### Advanced Topics
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")

      assert entry_attrs.headings == [
               %{level: 1, title: "Hello World", link: "hello-world"},
               %{level: 2, title: "Getting Started", link: "getting-started"},
               %{level: 3, title: "Advanced Topics", link: "advanced-topics"}
             ]
    end

    test "parses published_at as string (coerced by changeset)" do
      content = """
      ---
      title: Published Entry
      published_at: 2024-01-15T12:00:00Z
      ---

      Body
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.title == "Published Entry"
      assert entry_attrs.published_at == "2024-01-15T12:00:00Z"
    end

    test "parses invalid published_at as string (validated by changeset)" do
      content = """
      ---
      title: Entry
      published_at: not-a-date
      ---

      Body
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.title == "Entry"
      assert entry_attrs.published_at == "not-a-date"
    end

    test "rejects index.md at root" do
      content = """
      ---
      title: Index
      ---

      Content
      """

      assert {:error, {:invalid_slug, "index.md at root is not supported", _}} =
               Parser.parse("content/index.md", content, "content")
    end

    test "rejects nested index.md files" do
      content = """
      ---
      title: Index
      ---

      Content
      """

      assert {:error, {:invalid_slug, "index.md files are not supported", _}} =
               Parser.parse("content/blog/index.md", content, "content")
    end
  end

  describe "wiki-link extraction" do
    test "extracts single wiki-link" do
      content = """
      ---
      title: Test
      ---

      Check out [[/elixir/pipes]] for more info.
      """

      assert {:ok, {entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir/pipes"]
      assert entry_attrs.body =~ ~s(data-wikilink="true")
    end

    test "extracts multiple wiki-links" do
      content = """
      ---
      title: Test
      ---

      Check out [[/elixir]] and [[/phoenix]] and [[/ecto]].
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir", "phoenix", "ecto"]
    end

    test "normalizes slugs without leading slash" do
      content = """
      ---
      title: Test
      ---

      Check out [[elixir]] and [[phoenix/liveview]].
      """

      assert {:ok, {entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir", "phoenix/liveview"]
      assert entry_attrs.body =~ ~s(data-wikilink="true")
    end

    test "handles wiki-links with spaces" do
      content = """
      ---
      title: Test
      ---

      See [[  /elixir/pipes  ]] for details.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir/pipes"]
    end

    test "wiki-links in lists" do
      content = """
      ---
      title: Test
      ---

      - [[/item-one]]
      - [[/item-two]]
      - Regular item
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["item-one", "item-two"]
    end

    test "wiki-links in headings" do
      content = """
      ---
      title: Test
      ---

      # About [[/elixir]]

      Content here.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir"]
    end

    test "preserves wiki-link text in HTML" do
      content = """
      ---
      title: Test
      ---

      Check out [[elixir/pipes]] for more.
      """

      assert {:ok, {entry_attrs, _ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert entry_attrs.body =~ "elixir/pipes"
      assert entry_attrs.body =~ ~s(data-wikilink="true")
      assert entry_attrs.body =~ ~s(href="elixir/pipes")
    end

    test "wiki-links in code blocks are not extracted" do
      content = """
      ---
      title: Test
      ---

      ```
      [[/not-a-link]]
      ```
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      # Wiki-links in code blocks get preprocessed into HTML, but MDEx
      # escapes the HTML tags since they're in a code block. This means
      # Floki won't find them as actual <a> tags, so they won't be extracted.
      # This is correct behavior - we don't want to extract wiki-links from code.
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == []
    end

    test "inline code with wiki-link syntax" do
      content = """
      ---
      title: Test
      ---

      Use `[[/slug]]` syntax for links.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      # Wiki-links in inline code get escaped by MDEx, so they're not extracted.
      # This is correct - we don't want to extract wiki-links from code.
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == []
    end

    test "no wiki-links returns empty list" do
      content = """
      ---
      title: Test
      ---

      Just regular markdown content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert ref_attrs == []
    end

    test "duplicate wiki-links are deduplicated" do
      content = """
      ---
      title: Test
      ---

      See [[/elixir]] and also [[/elixir]] again.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      # Duplicates are deduplicated by {target_slug, type}
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert inline_refs == ["elixir"]
    end
  end

  describe "frontmatter references extraction" do
    test "extracts references from frontmatter" do
      content = """
      ---
      title: Test
      references:
        - /elixir
        - /phoenix
      ---

      Content here.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "phoenix"]
    end

    test "normalizes slugs without leading slash" do
      content = """
      ---
      title: Test
      references:
        - elixir
        - phoenix/liveview
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "phoenix/liveview"]
    end

    test "handles references with spaces" do
      content = """
      ---
      title: Test
      references:
        - "  /elixir  "
        - " phoenix "
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "phoenix"]
    end

    test "handles empty references array" do
      content = """
      ---
      title: Test
      references: []
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == []
    end

    test "skips empty references after normalization" do
      content = """
      ---
      title: Test
      references:
        - /elixir
        - ""
        - "   "
        - /phoenix
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "phoenix"]
    end

    test "no references field returns empty list" do
      content = """
      ---
      title: Test
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      assert ref_attrs == []
    end

    test "non-array references value is ignored" do
      content = """
      ---
      title: Test
      references: "not-an-array"
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == []
    end

    test "non-string values in references array are filtered out" do
      content = """
      ---
      title: Test
      references:
        - elixir
        - 123
        - true
        - null
        - phoenix
      ---

      Content.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "phoenix"]
    end

    test "handles mixed inline and frontmatter references" do
      content = """
      ---
      title: Test
      references:
        - /elixir
        - /ecto
      ---

      Check out [[/phoenix]] for more info.
      """

      assert {:ok, {_entry_attrs, ref_attrs}} = Parser.parse("content/test.md", content, "content")
      fm_refs = ref_attrs |> Enum.filter(&(&1.type == :frontmatter)) |> Enum.map(& &1.target_slug)
      inline_refs = ref_attrs |> Enum.filter(&(&1.type == :inline)) |> Enum.map(& &1.target_slug)
      assert fm_refs == ["elixir", "ecto"]
      assert inline_refs == ["phoenix"]
    end
  end

  describe "image processing" do
    test "rewrites relative image src to asset path" do
      insert(:image_asset,
        slug: "blog/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      content = """
      ---
      title: Test
      ---

      ![alt](./photo.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(src="/assets/blog/photo.webp")
    end

    test "injects LQIP hash as CSS variable" do
      insert(:image_asset,
        slug: "blog/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      content = """
      ---
      title: Test
      ---

      ![alt](./photo.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(style="--lqip:42")
    end

    test "injects width and height" do
      insert(:image_asset,
        slug: "blog/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      content = """
      ---
      title: Test
      ---

      ![alt](./photo.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(width="800")
      assert attrs.body =~ ~s(height="600")
    end

    test "wraps image in link to full size" do
      insert(:image_asset,
        slug: "blog/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      content = """
      ---
      title: Test
      ---

      ![alt](./photo.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(<a href="/assets/blog/photo.webp")
      assert attrs.body =~ ~s(target="_blank")
      assert attrs.body =~ ~s(rel="noopener")
    end

    test "skips external URLs" do
      content = """
      ---
      title: Test
      ---

      ![alt](https://example.com/photo.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(src="https://example.com/photo.png")
      refute attrs.body =~ ~s(--lqip)
    end

    test "leaves image unchanged if asset not found" do
      content = """
      ---
      title: Test
      ---

      ![alt](./nonexistent.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(src="./nonexistent.png")
      refute attrs.body =~ ~s(--lqip)
    end

    test "handles absolute paths from content root" do
      insert(:image_asset,
        slug: "images/hero.webp",
        metadata: %Image{width: 1920, height: 1080, lqip_hash: 123}
      )

      content = """
      ---
      title: Test
      ---

      ![hero](/images/hero.png)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(src="/assets/images/hero.webp")
      assert attrs.body =~ ~s(style="--lqip:123")
    end

    test "handles nested relative paths" do
      insert(:image_asset,
        slug: "assets/photo.webp",
        metadata: %Image{width: 400, height: 300, lqip_hash: 99}
      )

      content = """
      ---
      title: Test
      ---

      ![photo](../assets/photo.jpg)
      """

      # Entry at posts/entry.md, image at ../assets/photo.jpg resolves to assets/photo.jpg
      assert {:ok, {attrs, _refs}} = Parser.parse("posts/entry.md", content, ".")
      assert attrs.body =~ ~s(src="/assets/assets/photo.webp")
    end

    test "handles webp images without conversion" do
      insert(:image_asset,
        slug: "blog/photo.webp",
        metadata: %Image{width: 800, height: 600, lqip_hash: 42}
      )

      content = """
      ---
      title: Test
      ---

      ![alt](./photo.webp)
      """

      assert {:ok, {attrs, _refs}} = Parser.parse("blog/entry.md", content, ".")
      assert attrs.body =~ ~s(src="/assets/blog/photo.webp")
    end
  end
end
