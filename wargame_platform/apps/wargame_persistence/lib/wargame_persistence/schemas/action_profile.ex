defmodule WargamePersistence.Schemas.ActionProfile do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "action_profiles" do
    field :name, :string
    field :era, :string
    field :actions, :map, default: %{}
    field :phase_sequence, :map, default: %{}
    field :rules_module, :string

    has_many :scenarios, WargamePersistence.Schemas.Scenario

    timestamps()
  end

  @required_fields [:name, :era, :actions, :phase_sequence, :rules_module]

  def changeset(profile, attrs) do
    profile
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
  end

  def create_changeset(profile, attrs) do
    profile
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end
end
