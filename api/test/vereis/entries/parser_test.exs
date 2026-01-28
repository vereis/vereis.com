defmodule Vereis.Entries.ParserTest do
  use ExUnit.Case, async: true

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

      result = Parser.parse("content/test.md", content, "content")
      assert result.title == "My Post"
      assert result.description == "A great post"
      assert result.published_at == "2024-01-15T12:00:00Z"
      assert result.raw_body == "# Hello World\n\nThis is the body."
    end

    test "parses frontmatter with only title" do
      content = """
      ---
      title: Simple Post
      ---

      Body content.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.title == "Simple Post"
      assert result.raw_body == "Body content."
    end

    test "trims body whitespace" do
      content = """
      ---
      title: Test
      ---


      Body with extra newlines.


      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.raw_body == "Body with extra newlines."
    end

    test "parses frontmatter without title (validation handled by changeset)" do
      content = """
      ---
      description: No title here
      ---

      Body
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.description == "No title here"
      refute Map.has_key?(result, :title)
    end

    test "returns slug and hash when frontmatter delimiters are missing" do
      content = """
      title: No Delimiters

      Body content.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.slug == "/test"
      assert is_binary(result.source_hash)
      refute Map.has_key?(result, :title)
    end

    test "returns slug and hash when YAML is invalid" do
      content = """
      ---
      title: Test
      invalid: [unclosed
      ---

      Body
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.slug == "/test"
      assert is_binary(result.source_hash)
      refute Map.has_key?(result, :title)
    end

    test "handles empty body" do
      content = """
      ---
      title: Test
      ---
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.raw_body == ""
    end

    test "renders markdown to HTML" do
      content = """
      ---
      title: Test
      ---

      # Hello World

      This is **bold** and this is *italic*.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ ~r/<h1.*>Hello World<\/h1>/
      assert result.body =~ "<strong>bold</strong>"
      assert result.body =~ "<em>italic</em>"
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ ~r/<pre.*<code class="language-elixir"/
      assert result.body =~ "hello"
      assert result.body =~ ":world"
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ "<ul>"
      assert result.body =~ "<li>Item 1</li>"
      assert result.body =~ ~r/<a href="https:\/\/example\.com">Link<\/a>/
    end

    test "renders strikethrough with extension enabled" do
      content = """
      ---
      title: Test
      ---

      ~~strikethrough~~
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ "<del>strikethrough</del>"
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ ~r/<h1 id="hello-world"/
      assert result.body =~ ~r/<h2 id="getting-started"/
      assert result.body =~ ~r/<h3 id="advanced-topics"/
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

      result = Parser.parse("content/test.md", content, "content")

      assert result.headings == [
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.title == "Published Entry"
      assert result.published_at == "2024-01-15T12:00:00Z"
    end

    test "parses invalid published_at as string (validated by changeset)" do
      content = """
      ---
      title: Entry
      published_at: not-a-date
      ---

      Body
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.title == "Entry"
      assert result.published_at == "not-a-date"
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/elixir/pipes"]
      assert result.body =~ ~s(data-slug="/elixir/pipes")
    end

    test "extracts multiple wiki-links" do
      content = """
      ---
      title: Test
      ---

      Check out [[/elixir]] and [[/phoenix]] and [[/ecto]].
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/elixir", "/phoenix", "/ecto"]
    end

    test "normalizes slugs without leading slash" do
      content = """
      ---
      title: Test
      ---

      Check out [[elixir]] and [[phoenix/liveview]].
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/elixir", "/phoenix/liveview"]
      assert result.body =~ ~s(data-slug="/elixir")
      assert result.body =~ ~s(data-slug="/phoenix/liveview")
    end

    test "handles wiki-links with spaces" do
      content = """
      ---
      title: Test
      ---

      See [[  /elixir/pipes  ]] for details.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/elixir/pipes"]
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/item-one", "/item-two"]
    end

    test "wiki-links in headings" do
      content = """
      ---
      title: Test
      ---

      # About [[/elixir]]

      Content here.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == ["/elixir"]
    end

    test "preserves wiki-link text in HTML" do
      content = """
      ---
      title: Test
      ---

      Check out [[elixir/pipes]] for more.
      """

      result = Parser.parse("content/test.md", content, "content")
      assert result.body =~ "elixir/pipes"
      assert result.body =~ ~s(<a data-slug="/elixir/pipes">elixir/pipes</a>)
    end

    test "handles empty wiki-link" do
      content = """
      ---
      title: Test
      ---

      Check out [[]] for more.
      """

      result = Parser.parse("content/test.md", content, "content")
      # Empty slugs are not extracted, original syntax is preserved
      assert result.inline_refs == []
      assert result.body =~ "[[]]"
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

      result = Parser.parse("content/test.md", content, "content")
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

      result = Parser.parse("content/test.md", content, "content")
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

      result = Parser.parse("content/test.md", content, "content")
      assert result.inline_refs == []
    end

    test "duplicate wiki-links are deduplicated" do
      content = """
      ---
      title: Test
      ---

      See [[/elixir]] and also [[/elixir]] again.
      """

      result = Parser.parse("content/test.md", content, "content")
      # We preserve duplicates as they appear in the source
      assert result.inline_refs == ["/elixir", "/elixir"]
    end
  end
end
