defmodule Vereis.Assets do
  @moduledoc "Context module for managing binary assets."

  alias Vereis.Assets.Asset
  alias Vereis.Assets.Importer
  alias Vereis.Repo

  @spec get_asset(keyword()) :: Asset.t() | nil
  def get_asset(filters) when is_list(filters) do
    filters |> Asset.query() |> Repo.one()
  end

  @spec list_assets(keyword()) :: [Asset.t()]
  def list_assets(filters \\ []) when is_list(filters) do
    filters |> Asset.query() |> Repo.all()
  end

  @spec update_asset(Asset.t(), map()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def update_asset(%Asset{} = asset, attrs) when is_map(attrs) do
    asset
    |> Asset.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_asset(Asset.t()) :: {:ok, Asset.t()} | {:error, Ecto.Changeset.t()}
  def delete_asset(%Asset{} = asset) do
    update_asset(asset, %{deleted_at: DateTime.truncate(DateTime.utc_now(), :second)})
  end

  defdelegate import_assets(root), to: Importer
end
