defmodule VereisWeb.GraphQL.Types.Page do
  @moduledoc "Page interface and related types for entries and stubs."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias VereisWeb.GraphQL.Resolvers.Entry

  @desc "Page type discriminator"
  enum :page_type do
    value(:entry, description: "A full wiki/blog entry")
    value(:stub, description: "A stub page (referenced but not yet created)")
  end

  @desc "A page (entry or stub)"
  interface :page do
    @desc "Unique identifier"
    field :id, non_null(:id)

    @desc "URL slug (path)"
    field :slug, non_null(:string)

    @desc "Page title"
    field :title, non_null(:string)

    @desc "Description or excerpt"
    field :description, :string

    @desc "When the page was published"
    field :published_at, :datetime

    @desc "When the page was created"
    field :inserted_at, non_null(:datetime)

    @desc "When the page was last updated"
    field :updated_at, non_null(:datetime)

    @desc "Outgoing references from this page"
    connection field :references, node_type: :reference do
      arg(:type, :reference_type, description: "Filter by reference type")
      arg(:target, :page_target, description: "Filter by target type")

      resolve(&Entry.references/3)
    end

    @desc "Incoming references to this page"
    connection field :referenced_by, node_type: :reference do
      arg(:type, :reference_type, description: "Filter by reference type")
      arg(:target, :page_target, description: "Filter by target type")

      resolve(&Entry.referenced_by/3)
    end

    resolve_type fn
      %Vereis.Entries.Entry{}, _ -> :entry
      %Vereis.Entries.Stub{}, _ -> :stub
      _, _ -> nil
    end
  end
end
