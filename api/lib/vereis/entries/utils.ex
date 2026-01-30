defmodule Vereis.Entries.Utils do
  @moduledoc "Utility functions for entries."

  import Ecto.Changeset, only: [get_field: 2, add_error: 3]

  @doc "Resolves a path (relative or absolute) to a slug."
  @spec path_to_slug(String.t(), String.t()) :: {:ok, String.t()} | {:error, :external}
  def path_to_slug(src, context_slug) do
    cond do
      external_url?(src) ->
        {:error, :external}

      String.starts_with?(src, "/") ->
        {:ok, String.trim_leading(src, "/")}

      true ->
        context_dir = Path.dirname(context_slug)

        resolved =
          context_dir
          |> Path.join(src)
          |> Path.expand("/")
          |> String.trim_leading("/")

        {:ok, resolved}
    end
  end

  @doc "Returns true if the given string is an external URL."
  @spec external_url?(String.t()) :: boolean()
  def external_url?(src) do
    String.match?(src, ~r/^https?:\/\//)
  end

  @doc "Swaps the file extension. Empty list swaps any extension."
  @spec swap_ext(String.t(), String.t(), [String.t()]) :: String.t()
  def swap_ext(path, new_ext, from_exts \\ [])

  def swap_ext(path, new_ext, []) do
    Path.rootname(path) <> new_ext
  end

  def swap_ext(path, new_ext, from_exts) do
    if Path.extname(path) in from_exts do
      Path.rootname(path) <> new_ext
    else
      path
    end
  end

  @doc "Converts text to a URL-safe slug."
  @spec slugify(String.t()) :: String.t()
  def slugify(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-Za-z0-9\s-]/u, "")
    |> String.downcase()
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end

  @doc "Derives a human-readable title from a slug."
  @spec slug_to_title(String.t()) :: String.t()
  def slug_to_title(slug) when is_binary(slug) do
    slug
    |> String.split("/")
    |> Enum.map_join(" / ", &title_case_segment/1)
  end

  @doc "Validates a slug field on a changeset."
  @spec validate_slug(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate_slug(changeset, field) do
    slug = get_field(changeset, field)

    cond do
      is_nil(slug) ->
        changeset

      slug == "" ->
        add_error(changeset, field, "can't be blank")

      String.starts_with?(slug, "/") ->
        add_error(changeset, field, "must not start with /")

      String.ends_with?(slug, "/") ->
        add_error(changeset, field, "must not end with /")

      not String.match?(slug, ~r/^[a-z0-9_\/-]+$/) ->
        add_error(changeset, field, "must be lowercase alphanumeric with hyphens, underscores, or slashes")

      true ->
        changeset
    end
  end

  defp title_case_segment(segment) do
    segment
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
