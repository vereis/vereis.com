defmodule Vereis.Assets.Parser do
  @moduledoc "Parses asset files (images, etc.) into Asset attributes with metadata."

  alias Vereis.Assets.Metadata.Image.LQIP
  alias Vereis.Entries.Utils
  alias Vix.Vips.Image, as: VixImage

  @supported_extensions ~w(.png .jpg .jpeg .gif .webp .svg)
  @glob "**/*{#{Enum.join(@supported_extensions, ",")}}"

  @typep parse_result :: {:ok, map()} | {:error, term()}

  @spec parse(String.t()) :: {:ok, [parse_result()]} | {:error, term()}
  def parse(dir) when is_binary(dir) do
    if File.dir?(dir) do
      {:ok,
       dir
       |> Path.join(@glob)
       |> Path.wildcard()
       |> Task.async_stream(&parse(&1, dir), timeout: :infinity)
       |> Enum.map(fn {:ok, result} -> result end)}
    else
      {:error, {:invalid_directory, "#{dir} is not a valid directory"}}
    end
  end

  @spec parse(String.t(), String.t()) :: parse_result()
  def parse(filepath, base_dir) when is_binary(filepath) and is_binary(base_dir) do
    with {:ok, data} <- File.read(filepath) do
      parse(filepath, data, base_dir)
    end
  end

  @spec parse(String.t(), binary(), String.t()) :: parse_result()
  def parse(filepath, data, base_dir) when is_binary(filepath) and is_binary(data) and is_binary(base_dir) do
    content_type = MIME.from_path(filepath)

    case content_type do
      "image/" <> _ ->
        parse_image(filepath, data, base_dir, content_type)

      other ->
        {:error, {:unsupported_type, "#{other} is not supported", filepath}}
    end
  end

  defp parse_image(filepath, data, base_dir, content_type) do
    slug = derive_slug(filepath, base_dir)
    hash = :sha256 |> :crypto.hash(data) |> Base.encode16(case: :lower)

    with {:ok, image} <- VixImage.new_from_file(filepath),
         {:ok, optimized_data, final_type} <- optimize_image(image, content_type),
         {:ok, lqip_hash} <- LQIP.generate(image) do
      {:ok,
       %{
         slug: slug,
         content_type: final_type,
         data: optimized_data,
         source_hash: hash,
         metadata: %{
           __type__: "image",
           width: VixImage.width(image),
           height: VixImage.height(image),
           lqip_hash: lqip_hash
         }
       }}
    end
  end

  defp derive_slug(filepath, base_dir) do
    filepath
    |> Path.relative_to(base_dir)
    |> Utils.swap_ext(".webp")
  end

  defp optimize_image(image, "image/svg" <> _) do
    case VixImage.write_to_buffer(image, ".png") do
      {:ok, data} -> {:ok, data, "image/png"}
      error -> error
    end
  end

  defp optimize_image(image, _content_type) do
    case VixImage.write_to_buffer(image, ".webp", Q: 80, strip: true) do
      {:ok, data} -> {:ok, data, "image/webp"}
      error -> error
    end
  end
end
