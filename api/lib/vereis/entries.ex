defmodule Vereis.Entries do
  @moduledoc "Context module for managing wiki/blog entries."

  alias Vereis.Entries.Entry
  alias Vereis.Entries.Importer
  alias Vereis.Entries.Reference
  alias Vereis.Repo

  require Logger

  @spec get_entry(keyword()) :: Entry.t() | nil
  def get_entry(filters) when is_list(filters) do
    filters |> Entry.query() |> Repo.one()
  end

  @spec get_entry(any(), keyword()) :: Entry.t() | nil
  def get_entry(id, filters) do
    filters |> Keyword.put(:id, id) |> get_entry()
  end

  @spec list_entries(keyword()) :: [Entry.t()]
  def list_entries(filters \\ []) when is_list(filters) do
    filters |> Entry.query() |> Repo.all()
  end

  @spec update_entry(Entry.t(), map()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def update_entry(%Entry{} = entry, attrs) do
    entry
    |> Entry.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_entry(Entry.t()) :: {:ok, Entry.t()} | {:error, Ecto.Changeset.t()}
  def delete_entry(%Entry{} = entry) do
    update_entry(entry, %{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
  end

  @spec list_references(Entry.t() | keyword()) :: [Reference.t()]
  @spec list_references(Entry.t(), keyword()) :: [Reference.t()]
  def list_references(%Entry{} = entry) do
    list_references(entry, [])
  end

  def list_references(filters) when is_list(filters) do
    filters |> Reference.query() |> Repo.all()
  end

  def list_references(%Entry{slug: slug}, filters) when is_list(filters) do
    filters
    |> Keyword.put(:slug, slug)
    |> Keyword.put_new(:direction, :outgoing)
    |> list_references()
  end

  defdelegate import_entries(root), to: Importer
end
