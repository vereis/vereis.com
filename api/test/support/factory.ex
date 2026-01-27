defmodule Vereis.Factory do
  @moduledoc "ExMachina factory for generating test data."

  use ExMachina.Ecto, repo: Vereis.Repo

  alias Vereis.Entries.Entry

  def entry_factory do
    %Entry{
      slug: sequence(:slug, &"/entry-#{&1}"),
      title: sequence(:title, &"Entry #{&1}"),
      body: "<p>Test body content</p>",
      raw_body: "Test body content",
      description: "Test description"
    }
  end
end
