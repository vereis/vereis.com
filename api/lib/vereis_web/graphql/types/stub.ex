defmodule VereisWeb.GraphQL.Types.Stub do
  @moduledoc "Stub (referenced but non-existent entry) GraphQL type."

  use Absinthe.Schema.Notation

  alias Vereis.Entries.Stub

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
  end
end
