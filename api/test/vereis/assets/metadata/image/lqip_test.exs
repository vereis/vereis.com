defmodule Vereis.Assets.Metadata.Image.LQIPTest do
  use ExUnit.Case, async: true

  alias Vereis.Assets.Metadata.Image.LQIP
  alias Vix.Vips.Image, as: VixImage

  @fixtures_path Path.join([File.cwd!(), "test/support/fixtures"])

  describe "generate/1" do
    test "returns 0 for images smaller than 3x2" do
      tiny_path = Path.join(@fixtures_path, "tiny_1x1.png")
      {:ok, image} = VixImage.new_from_file(tiny_path)

      assert {:ok, 0} = LQIP.generate(image)
    end

    test "returns valid 20-bit signed integer for normal images" do
      large_path = Path.join(@fixtures_path, "test_image.jpg")
      {:ok, image} = VixImage.new_from_file(large_path)

      assert {:ok, lqip} = LQIP.generate(image)
      assert lqip >= -524_288
      assert lqip <= 524_287
      assert lqip != 0
    end

    test "generates consistent hash for same image" do
      large_path = Path.join(@fixtures_path, "test_image.jpg")
      {:ok, image1} = VixImage.new_from_file(large_path)
      {:ok, image2} = VixImage.new_from_file(large_path)

      assert {:ok, lqip1} = LQIP.generate(image1)
      assert {:ok, lqip2} = LQIP.generate(image2)
      assert lqip1 == lqip2
    end
  end
end
