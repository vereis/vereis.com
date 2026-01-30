defmodule Vereis.Entries.Utils do
  @moduledoc "Utility functions for entries."

  @doc "Derives a human-readable title from a slug."
  @spec slug_to_title(String.t()) :: String.t()
  def slug_to_title(slug) when is_binary(slug) do
    slug
    |> String.split("/")
    |> Enum.map_join(" / ", &title_case_segment/1)
  end

  defp title_case_segment(segment) do
    segment
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
