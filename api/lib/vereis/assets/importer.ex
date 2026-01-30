defmodule Vereis.Assets.Importer do
  @moduledoc "Handles bulk import of assets from a directory."

  alias Vereis.Assets.Asset
  alias Vereis.Assets.Metadata
  alias Vereis.Assets.Parser
  alias Vereis.Repo

  require Logger

  @spec import_assets(String.t()) :: {:ok, map()} | {:error, term()}
  def import_assets(dir) when is_binary(dir) do
    now = NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)

    with {:ok, parse_results} <- Parser.parse(dir) do
      {parsed, parse_errors} = Enum.split_with(parse_results, &match?({:ok, _}, &1))

      if parse_errors != [] do
        Logger.warning("Parse errors during asset import: #{inspect(Enum.take(parse_errors, 5))}")
      end

      assets = Enum.map(parsed, fn {:ok, attrs} -> attrs end)

      Repo.transaction(fn ->
        asset_attrs = build_asset_attrs(assets)

        {asset_count, _inserted_assets} =
          Repo.insert_all(
            Asset,
            asset_attrs,
            on_conflict: {:replace_all_except, [:id, :inserted_at]},
            conflict_target: [:slug],
            placeholders: %{now: now}
          )

        Logger.info("Imported #{asset_count} assets")

        %{assets_count: asset_count}
      end)
    end
  end

  defp build_asset_attrs(assets) do
    Enum.map(assets, fn asset ->
      %{
        slug: asset.slug,
        content_type: asset.content_type,
        data: asset.data,
        source_hash: asset.source_hash,
        metadata: build_metadata(asset[:metadata]),
        inserted_at: {:placeholder, :now},
        updated_at: {:placeholder, :now}
      }
    end)
  end

  defp build_metadata(nil) do
    nil
  end

  defp build_metadata(%{__type__: "image"} = meta) do
    %Metadata.Image{
      width: meta.width,
      height: meta.height,
      lqip_hash: meta.lqip_hash
    }
  end

  defp build_metadata(%{__type__: "video"} = meta) do
    %Metadata.Video{
      width: meta[:width],
      height: meta[:height],
      duration: meta[:duration]
    }
  end

  defp build_metadata(%{__type__: "document"} = meta) do
    %Metadata.Document{
      page_count: meta[:page_count]
    }
  end
end
