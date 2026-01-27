defmodule Vereis.Entries.Heading do
  @moduledoc "Embedded schema for entry headings."

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :level, :integer
    field :title, :string
    field :link, :string
  end

  @spec changeset(t() | Ecto.Changeset.t(t()), map()) :: Ecto.Changeset.t(t())
  def changeset(heading, attrs) do
    heading
    |> cast(attrs, [:level, :title, :link])
    |> validate_required([:level, :title, :link])
  end
end
