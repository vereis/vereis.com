defmodule Vereis.Assets.Metadata.Document do
  @moduledoc "Embedded schema for document asset metadata."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :page_count, :integer
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:page_count])
    |> add_error(:__stub__, "document metadata not yet implemented")
  end
end
