defmodule Vereis.Factory do
  @moduledoc "ExMachina factory for generating test data."

  use ExMachina.Ecto, repo: Vereis.Repo

  alias Vereis.Entries.Entry
  alias Vereis.Entries.Reference

  def entry_factory do
    %Entry{
      slug: sequence(:slug, &"entry-#{&1}"),
      title: sequence(:title, &"Entry #{&1}"),
      type: :entry,
      body: "<p>Test body content</p>",
      raw_body: "Test body content",
      description: "Test description"
    }
  end

  def stub_factory do
    %Entry{
      slug: sequence(:slug, &"stub-#{&1}"),
      title: sequence(:title, &"Stub #{&1}"),
      type: :stub
    }
  end

  def reference_factory do
    %Reference{
      source_slug: sequence(:source_slug, &"source-#{&1}"),
      target_slug: sequence(:target_slug, &"target-#{&1}"),
      type: :inline
    }
  end
end
