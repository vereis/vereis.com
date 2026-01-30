defmodule Vereis.ImporterTest do
  use Vereis.DataCase, async: false
  use Oban.Testing, repo: Vereis.Repo

  alias Vereis.Assets
  alias Vereis.Entries
  alias Vereis.Importer

  @fixtures_path Path.join([File.cwd!(), "test/support/fixtures"])

  setup do
    {:ok, dir} = Briefly.create(directory: true)

    # Create test content: an entry and an image
    File.mkdir_p!(Path.join(dir, "blog"))

    File.write!(Path.join(dir, "blog/test.md"), """
    ---
    title: Test Entry
    ---
    Hello world
    """)

    tiny_png = File.read!(Path.join(@fixtures_path, "tiny_1x1.png"))
    File.write!(Path.join(dir, "blog/photo.png"), tiny_png)

    Application.put_env(:vereis, :content_dir, dir)
    on_exit(fn -> Application.delete_env(:vereis, :content_dir) end)

    {:ok, dir: dir}
  end

  describe "perform/1" do
    test "assets step imports assets and schedules entries step" do
      assert :ok = perform_job(Importer, %{})
      assert_enqueued(worker: Importer, args: %{"step" => "entries"})
    end

    test "entries step imports entries and completes workflow" do
      assert :ok = perform_job(Importer, %{"step" => "entries"})
      refute_enqueued(worker: Importer)
    end

    test "full workflow imports both assets and entries" do
      Oban.insert!(Importer.new(%{}))
      assert %{success: 2} = Oban.drain_queue(queue: :imports, with_recursion: true)

      assert Assets.list_assets() != []
      assert Entries.list_entries() != []
    end
  end
end
