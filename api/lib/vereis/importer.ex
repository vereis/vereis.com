defmodule Vereis.Importer do
  @moduledoc "Oban worker that orchestrates content imports: assets → entries."

  use Oban.Worker, queue: :imports, max_attempts: 3

  alias Vereis.Assets
  alias Vereis.Entries

  require Logger

  @impl Oban.Worker
  def perform(job) do
    run(job.args["step"] || "assets")
  end

  # NOTE: Import and job scheduling are not wrapped in a transaction.
  # If import succeeds but scheduling fails, Oban retries the whole job.
  # This is safe because imports are idempotent (upserts by source_hash).
  defp run("assets") do
    dir = content_dir()
    Logger.info("Importing assets from #{dir}")

    {:ok, _} = Assets.import_assets(dir)

    %{"step" => "entries"}
    |> new()
    |> Oban.insert!()

    :ok
  end

  defp run("entries") do
    dir = content_dir()
    Logger.info("Importing entries from #{dir}")

    {:ok, _} = Entries.import_entries(dir)
    :ok
  end

  defp content_dir do
    Application.get_env(:vereis, :content_dir, "priv/content")
  end
end
