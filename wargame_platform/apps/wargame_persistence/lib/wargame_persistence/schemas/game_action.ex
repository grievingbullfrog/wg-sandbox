defmodule WargamePersistence.Schemas.GameAction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_actions" do
    field :turn, :integer
    field :phase, :string
    field :side, :string
    field :sequence, :integer
    field :action, :map, default: %{}

    belongs_to :game, WargamePersistence.Schemas.Game

    timestamps()
  end

  @required_fields [:game_id, :turn, :phase, :side, :sequence, :action]

  def changeset(action, attrs) do
    action
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:turn, greater_than_or_equal_to: 0)
    |> validate_number(:sequence, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:game_id)
  end

  def create_changeset(action, attrs) do
    action
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end
end
