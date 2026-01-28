defmodule VereisWeb.GraphQL.Types.Stub do
  @moduledoc "Stub (referenced but non-existent entry) GraphQL type."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias Vereis.Entries.Stub
  alias VereisWeb.GraphQL.Resolvers.Entry

  @desc "A stub page (referenced but not yet created)"
  object :stub do
    interface :page

    @desc "Unique identifier (same as slug)"
    field :id, non_null(:id)

    @desc "URL slug (path)"
    field :slug, non_null(:string)

    @desc "Derived title from slug"
    field :title, non_null(:string) do
      resolve(fn stub, _args, _resolution ->
        {:ok, Stub.derive_title(stub.slug)}
      end)
    end

    @desc "Description (always null for stubs)"
    field :description, :string

    @desc "When the stub was published (always null)"
    field :published_at, :datetime

    @desc "When the stub was first referenced"
    field :inserted_at, non_null(:datetime)

    @desc "When the stub was last referenced"
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
  end
end
