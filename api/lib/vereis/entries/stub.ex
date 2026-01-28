defmodule Vereis.Entries.Stub do
  @moduledoc "Schema for stub pages (referenced but non-existent entries)."

  use Ecto.Schema
  use Vereis.Queryable

  import Ecto.Query

  @primary_key {:slug, :string, autogenerate: false}
  @foreign_key_type :string

  @type t :: %__MODULE__{}

  schema "stubs" do
    field :id, :string, virtual: true
    field :title, :string, virtual: true
    field :description, :string, virtual: true
    field :published_at, :utc_datetime, virtual: true

    field :inserted_at, :naive_datetime
    field :updated_at, :naive_datetime
  end

  @spec derive_title(String.t()) :: String.t()
  def derive_title("/"), do: "/"

  def derive_title(slug) when is_binary(slug) do
    slug
    |> String.trim_leading("/")
    |> String.split("/")
    |> Enum.map_join(" / ", &title_case_word/1)
  end

  defp title_case_word(word) do
    word
    |> String.replace(~r/[-_]/, " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @impl Vereis.Queryable
  def base_query do
    from s in __MODULE__, as: :self
  end

  @impl Vereis.Queryable
  def query(base_query \\ base_query(), filters) do
    Enum.reduce(filters, base_query, fn
      {:prefix, prefix}, query when is_binary(prefix) ->
        pattern = "#{prefix}%"
        from s in query, where: like(s.slug, ^pattern)

      filter, query ->
        apply_filter(query, filter)
    end)
  end
end
