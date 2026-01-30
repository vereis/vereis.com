defmodule VereisWeb.AssetController do
  @moduledoc "Controller for serving binary assets and metadata."

  use VereisWeb, :controller

  alias Vereis.Assets
  alias Vereis.Assets.Metadata.Image

  @doc """
  Serves an asset by slug.

  Query params:
    - `?info=true` - Returns JSON metadata (content_type, width, height, lqip_hash)
    - `?lqip=true` - Renders HTML page with CSS-only LQIP preview
    - (no param)   - Returns binary asset data with appropriate Content-Type
  """
  def show(conn, %{"slug" => slug_parts} = params) do
    slug = Enum.join(slug_parts, "/")

    case Assets.get_asset(slug: slug) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Asset not found"})

      asset ->
        cond do
          params["info"] == "true" -> serve_metadata(conn, asset)
          params["lqip"] == "true" -> serve_lqip_preview(conn, asset)
          true -> serve_binary(conn, asset)
        end
    end
  end

  defp serve_metadata(conn, asset) do
    metadata = %{
      slug: asset.slug,
      content_type: asset.content_type
    }

    metadata =
      case asset.metadata do
        %Image{} = meta ->
          Map.merge(metadata, %{
            width: meta.width,
            height: meta.height,
            lqip_hash: meta.lqip_hash
          })

        _ ->
          metadata
      end

    json(conn, metadata)
  end

  defp serve_lqip_preview(conn, asset) do
    case asset.metadata do
      %Image{lqip_hash: hash, width: w, height: h} ->
        html = lqip_preview_html(hash, w, h, asset.slug)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "LQIP preview only available for image assets"})
    end
  end

  defp serve_binary(conn, asset) do
    conn
    |> put_resp_content_type(asset.content_type)
    |> put_resp_header("cache-control", "public, max-age=31536000, immutable")
    |> send_resp(200, asset.data)
  end

  defp lqip_preview_html(hash, width, height, _slug) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        * { margin: 0; padding: 0; }
        div { width: #{width}px; height: #{height}px; }

        /* LQIP CSS - based on https://leanrada.com/notes/css-only-lqip/ */
        [style*="--lqip:"] {
          --lqip-ca: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 18))), 4);
          --lqip-cb: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 16))), 4);
          --lqip-cc: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 14))), 4);
          --lqip-cd: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 12))), 4);
          --lqip-ce: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 10))), 4);
          --lqip-cf: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 8))), 4);
          --lqip-ll: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 6))), 4);
          --lqip-aaa: mod(round(down, calc((var(--lqip) + pow(2, 19)) / pow(2, 3))), 8);
          --lqip-bbb: mod(calc(var(--lqip) + pow(2, 19)), 8);

          --lqip-ca-clr: hsl(0 0% calc(var(--lqip-ca) / 3 * 60% + 20%));
          --lqip-cb-clr: hsl(0 0% calc(var(--lqip-cb) / 3 * 60% + 20%));
          --lqip-cc-clr: hsl(0 0% calc(var(--lqip-cc) / 3 * 60% + 20%));
          --lqip-cd-clr: hsl(0 0% calc(var(--lqip-cd) / 3 * 60% + 20%));
          --lqip-ce-clr: hsl(0 0% calc(var(--lqip-ce) / 3 * 60% + 20%));
          --lqip-cf-clr: hsl(0 0% calc(var(--lqip-cf) / 3 * 60% + 20%));
          --lqip-base-clr: oklab(
            calc(var(--lqip-ll) / 3 * 0.6 + 0.2)
            calc(var(--lqip-aaa) / 8 * 0.7 - 0.35)
            calc((var(--lqip-bbb) + 1) / 8 * 0.7 - 0.35)
          );

          --lqip-stop10: 2%;
          --lqip-stop20: 8%;
          --lqip-stop30: 18%;
          --lqip-stop40: 32%;

          background-blend-mode: hard-light, hard-light, hard-light, hard-light, hard-light, hard-light, normal;
          background-image:
            radial-gradient(50% 75% at 16.67% 25%, var(--lqip-ca-clr), rgb(from var(--lqip-ca-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-ca-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-ca-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-ca-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-ca-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-ca-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-ca-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-ca-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            radial-gradient(50% 75% at 50% 25%, var(--lqip-cb-clr), rgb(from var(--lqip-cb-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-cb-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-cb-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-cb-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-cb-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-cb-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-cb-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-cb-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            radial-gradient(50% 75% at 83.33% 25%, var(--lqip-cc-clr), rgb(from var(--lqip-cc-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-cc-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-cc-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-cc-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-cc-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-cc-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-cc-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-cc-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            radial-gradient(50% 75% at 16.67% 75%, var(--lqip-cd-clr), rgb(from var(--lqip-cd-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-cd-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-cd-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-cd-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-cd-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-cd-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-cd-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-cd-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            radial-gradient(50% 75% at 50% 75%, var(--lqip-ce-clr), rgb(from var(--lqip-ce-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-ce-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-ce-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-ce-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-ce-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-ce-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-ce-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-ce-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            radial-gradient(50% 75% at 83.33% 75%, var(--lqip-cf-clr), rgb(from var(--lqip-cf-clr) r g b / calc(100% - var(--lqip-stop10))) 10%, rgb(from var(--lqip-cf-clr) r g b / calc(100% - var(--lqip-stop20))) 20%, rgb(from var(--lqip-cf-clr) r g b / calc(100% - var(--lqip-stop30))) 30%, rgb(from var(--lqip-cf-clr) r g b / calc(100% - var(--lqip-stop40))) 40%, rgb(from var(--lqip-cf-clr) r g b / calc(var(--lqip-stop40))) 60%, rgb(from var(--lqip-cf-clr) r g b / calc(var(--lqip-stop30))) 70%, rgb(from var(--lqip-cf-clr) r g b / calc(var(--lqip-stop20))) 80%, rgb(from var(--lqip-cf-clr) r g b / calc(var(--lqip-stop10))) 90%, transparent),
            linear-gradient(0deg, var(--lqip-base-clr), var(--lqip-base-clr));
        }
      </style>
    </head>
    <body><div style="--lqip:#{hash}"></div></body>
    </html>
    """
  end
end
