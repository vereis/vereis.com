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
  end
end
