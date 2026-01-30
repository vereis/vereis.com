defmodule Vereis.Assets.Metadata.Image.LQIP do
  @moduledoc """
  Generates 20-bit LQIP (Low Quality Image Placeholder) hashes from images.

  Based on https://leanrada.com/notes/css-only-lqip/

  The hash encodes a 3x2 grid of OKLab color samples into a signed 20-bit integer,
  allowing CSS-only placeholder rendering without base64 data URIs.
  """

  import Bitwise

  alias Vix.Vips.Image, as: VixImage
  alias Vix.Vips.Operation

  @l_levels 4
  @ab_levels 8
  @l_min 0.2
  @l_max 0.8
  @a_min -0.35
  @a_max 0.35
  @b_min -0.35
  @b_max 0.35

  @spec generate(VixImage.t()) :: {:ok, integer()} | {:error, term()}
  def generate(image) do
    width = VixImage.width(image)
    height = VixImage.height(image)

    if width < 3 or height < 2 do
      {:ok, 0}
    else
      generate_from_thumbnail(image)
    end
  end

  defp generate_from_thumbnail(image) do
    with {:ok, thumbnail} <- Operation.thumbnail_image(image, 3, height: 2),
         {:ok, sharpened} <- Operation.sharpen(thumbnail, sigma: 1.0),
         {:ok, binary} <- VixImage.write_to_binary(sharpened) do
      oklab_pixels = extract_oklab_pixels(binary)
      {:ok, encode_pixels(oklab_pixels)}
    end
  end

  defp extract_oklab_pixels(binary) do
    pixels =
      binary
      |> :binary.bin_to_list()
      |> Enum.chunk_every(3)
      |> Enum.take(6)
      |> Enum.map(fn
        [r, g, b] -> rgb_to_oklab(r, g, b)
        [r, g, b, _a] -> rgb_to_oklab(r, g, b)
        _other -> rgb_to_oklab(0, 0, 0)
      end)

    pixels ++ List.duplicate({0.5, 0.0, 0.0}, 6 - length(pixels))
  end

  defp encode_pixels(oklab_pixels) do
    {base_l, base_a, base_b} = average_oklab(oklab_pixels)
    {ll, aaa, bbb} = find_best_bits(base_l, base_a, base_b)
    decoded_base_l = ll / 3.0 * 0.6 + 0.2

    components =
      Enum.map(oklab_pixels, fn {cell_l, _a, _b} ->
        relative = 0.5 + (cell_l - decoded_base_l)
        clamped = max(0.0, min(1.0, relative))
        round(clamped * 3)
      end)

    encode_signed(ll, aaa, bbb, components)
  end

  defp rgb_to_oklab(r, g, b) do
    r_lin = gamma_to_linear(r / 255.0)
    g_lin = gamma_to_linear(g / 255.0)
    b_lin = gamma_to_linear(b / 255.0)

    l = 0.4122214708 * r_lin + 0.5363325363 * g_lin + 0.0514459929 * b_lin
    m = 0.2119034982 * r_lin + 0.6806995451 * g_lin + 0.1073969566 * b_lin
    s = 0.0883024619 * r_lin + 0.2817188376 * g_lin + 0.6299787005 * b_lin

    l_ = :math.pow(max(l, 1.0e-10), 1 / 3)
    m_ = :math.pow(max(m, 1.0e-10), 1 / 3)
    s_ = :math.pow(max(s, 1.0e-10), 1 / 3)

    ok_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
    ok_a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    ok_b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

    {ok_l, ok_a, ok_b}
  end

  defp gamma_to_linear(v) when v <= 0.04045 do
    v / 12.92
  end

  defp gamma_to_linear(v) do
    :math.pow((v + 0.055) / 1.055, 2.4)
  end

  defp average_oklab([]) do
    {0.5, 0.0, 0.0}
  end

  defp average_oklab(pixels) do
    {l_sum, a_sum, b_sum} =
      Enum.reduce(pixels, {0.0, 0.0, 0.0}, fn {l, a, b}, {l_acc, a_acc, b_acc} ->
        {l_acc + l, a_acc + a, b_acc + b}
      end)

    count = length(pixels)
    {l_sum / count, a_sum / count, b_sum / count}
  end

  defp find_best_bits(target_l, target_a, target_b) do
    target_chroma = :math.sqrt(target_a * target_a + target_b * target_b)

    candidates =
      for ll <- 0..3, aaa <- 0..7, bbb <- 0..7 do
        {l, a, b} = bits_to_oklab(ll, aaa, bbb)
        chroma = :math.sqrt(a * a + b * b)
        scaled_a = scale_for_diff(a, chroma)
        scaled_b = scale_for_diff(b, chroma)
        scaled_target_a = scale_for_diff(target_a, target_chroma)
        scaled_target_b = scale_for_diff(target_b, target_chroma)

        diff =
          :math.sqrt(
            :math.pow(l - target_l, 2) +
              :math.pow(scaled_a - scaled_target_a, 2) +
              :math.pow(scaled_b - scaled_target_b, 2)
          )

        {diff, ll, aaa, bbb}
      end

    {_, ll, aaa, bbb} = Enum.min_by(candidates, fn {diff, _, _, _} -> diff end)
    {ll, aaa, bbb}
  end

  defp scale_for_diff(x, chroma) do
    x / (1.0e-6 + :math.pow(chroma, 0.5))
  end

  defp bits_to_oklab(ll, aaa, bbb) do
    l = ll / (@l_levels - 1) * (@l_max - @l_min) + @l_min
    a = aaa / @ab_levels * (@a_max - @a_min) + @a_min
    b = (bbb + 1) / @ab_levels * (@b_max - @b_min) + @b_min
    {l, a, b}
  end

  defp encode_signed(ll, aaa, bbb, [ca, cb, cc, cd, ce, cf]) do
    unsigned =
      (ca &&& 0b11) <<< 18 |||
        (cb &&& 0b11) <<< 16 |||
        (cc &&& 0b11) <<< 14 |||
        (cd &&& 0b11) <<< 12 |||
        (ce &&& 0b11) <<< 10 |||
        (cf &&& 0b11) <<< 8 |||
        (ll &&& 0b11) <<< 6 |||
        (aaa &&& 0b111) <<< 3 |||
        (bbb &&& 0b111)

    unsigned - Integer.pow(2, 19)
  end

  defp encode_signed(ll, aaa, bbb, components) do
    padded = components ++ List.duplicate(0, 6 - length(components))
    encode_signed(ll, aaa, bbb, Enum.take(padded, 6))
  end
end
