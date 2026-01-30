defmodule Vereis.Assets.Metadata.Video do
  @moduledoc "Embedded schema for video asset metadata."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :width, :integer
    field :height, :integer
    field :duration, :float
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:width, :height, :duration])
    |> add_error(:__stub__, "video metadata not yet implemented")
  end
end
