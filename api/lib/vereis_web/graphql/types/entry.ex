defmodule VereisWeb.GraphQL.Types.Entry do
  @moduledoc "Entry (wiki/blog page) GraphQL type."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias VereisWeb.GraphQL.Resolvers.Entry, as: EntryResolver

  @desc "A heading extracted from an entry's markdown"
  object :heading do
    @desc "Heading level (1-6)"
    field :level, non_null(:integer)

    @desc "Heading text"
    field :title, non_null(:string)

    @desc "Anchor link slug"
    field :link, non_null(:string)
  end

  @desc "A wiki or blog entry"
  node object(:entry) do
    @desc "URL slug (path)"
    field :slug, non_null(:string)

    @desc "Entry title"
    field :title, non_null(:string)

    @desc "Description or excerpt"
    field :description, :string

    @desc "When the entry was published"
    field :published_at, :datetime

    @desc "When the entry was created"
    field :inserted_at, non_null(:datetime)

    @desc "When the entry was last updated"
    field :updated_at, non_null(:datetime)

    @desc "Rendered HTML body (null for stubs)"
    field :body, :string

    @desc "Original markdown body (null for stubs)"
    field :raw_body, :string

    @desc "Table of contents headings"
    field :headings, list_of(non_null(:heading))

    @desc "Outgoing references from this entry"
    connection field :references, node_type: :reference do
      arg :type, :reference_type, description: "Filter by reference type"
      arg :order_by, list_of(:reference_order_by), description: "Sort references"

      resolve &EntryResolver.references/3
    end

    @desc "Incoming references to this entry (backlinks)"
    connection field :referenced_by, node_type: :reference do
      arg :type, :reference_type, description: "Filter by reference type"
      arg :order_by, list_of(:reference_order_by), description: "Sort references"

      resolve &EntryResolver.referenced_by/3
    end
  end

  @desc "Relay connection for paginated entries"
  connection(node_type: :entry)

  @desc "Sort direction"
  enum :order_direction do
    value(:asc, description: "Ascending order")
    value(:desc, description: "Descending order")
  end

  @desc "Ordering options for entries"
  input_object :entry_order_by do
    field(:slug, :order_direction)
    field(:title, :order_direction)
    field(:published_at, :order_direction)
    field(:inserted_at, :order_direction)
    field(:updated_at, :order_direction)
  end
end
