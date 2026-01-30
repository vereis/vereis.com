defmodule Vereis.Assets.Metadata.Image do
  @moduledoc "Embedded schema for image asset metadata."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :width, :integer
    field :height, :integer
    field :lqip_hash, :integer
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:width, :height, :lqip_hash])
    |> validate_required([:width, :height])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
  end
end
