defmodule Vereis do
  @moduledoc false

  @doc "Returns the git SHA of the current version."
  @spec version() :: String.t()
  def version do
    release_sha = System.get_env("RELEASE_SHA")

    if release_sha in [nil, ""] do
      "git"
      |> System.cmd(["rev-parse", "HEAD"])
      |> then(fn {sha, 0} -> String.trim(sha) end)
    else
      release_sha
    end
  end

  @doc "Returns the current build environment."
  @spec env() :: atom()
  def env do
    Mix.env()
  end
end
