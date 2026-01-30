defmodule Vereis.Entries.Utils do
  @moduledoc "Utility functions for entries."

  import Ecto.Changeset, only: [get_field: 2, add_error: 3]

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
