defmodule WargamePersistence.Schemas.UnitTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_categories ~w(infantry armor motorized artillery recon engineer anti_tank anti_air cavalry naval air)
  @valid_unit_sizes ~w(squad platoon company battalion regiment brigade division corps)

  schema "unit_templates" do
    field :name, :string
    field :nationality, :string
    field :era, :string
    field :category, :string
    field :unit_size, :string
    field :icon_type, :string
    field :stats, :map, default: %{}
    field :published, :boolean, default: false

    belongs_to :author, WargamePersistence.Schemas.User

    timestamps()
  end

  @required_fields [:name, :nationality, :era, :category, :unit_size, :stats]
  @optional_fields [:icon_type, :author_id, :published]

  def changeset(template, attrs) do
    template
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:category, @valid_categories)
    |> validate_inclusion(:unit_size, @valid_unit_sizes)
    |> foreign_key_constraint(:author_id)
  end

  def create_changeset(template, attrs) do
    template
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end

  def valid_categories, do: @valid_categories
  def valid_unit_sizes, do: @valid_unit_sizes
end
