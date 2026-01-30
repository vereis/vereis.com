defmodule VereisWeb.GraphQL.Types.Reference do
  @moduledoc "Reference GraphQL type."

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  @desc "Type of reference"
  enum :reference_type do
    value :inline, description: "Referenced by entry body"
    value :frontmatter, description: "Referenced by entry metadata"
  end

  @desc "A reference from one entry to another"
  node object(:reference) do
    @desc "Source entry slug"
    field :source_slug, non_null(:string)

    @desc "Target entry slug"
    field :target_slug, non_null(:string)

    @desc "Type of reference"
    field :type, non_null(:reference_type)

    @desc "When the reference was created"
    field :inserted_at, non_null(:datetime)

    @desc "The source entry (where the reference comes from)"
    field :source, non_null(:entry), resolve: dataloader(:db)

    @desc "The target entry (what is being referenced)"
    field :target, non_null(:entry), resolve: dataloader(:db)
  end

  @desc "Paginated references"
  connection(node_type: :reference)
end
