defmodule Vereis.Entries.ParserTest do
  use ExUnit.Case, async: true

  alias Vereis.Entries.Parser

  describe "parse/1" do
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
      assert result.raw_body == "Body with extra newlines."
    end

    test "parses frontmatter without title (validation handled by changeset)" do
      content = """
      ---
      description: No title here
      ---

      Body
      """

      result = Parser.parse(content)
      assert result.description == "No title here"
      refute Map.has_key?(result, :title)
    end

    test "returns empty map when frontmatter delimiters are missing" do
      content = """
      title: No Delimiters

      Body content.
      """

      result = Parser.parse(content)
      assert result == %{}
    end

    test "returns empty map when YAML is invalid" do
      content = """
      ---
      title: Test
      invalid: [unclosed
      ---

      Body
      """

      result = Parser.parse(content)
      assert result == %{}
    end

    test "handles empty body" do
      content = """
      ---
      title: Test
      ---
      """

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)
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

      result = Parser.parse(content)

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
end
