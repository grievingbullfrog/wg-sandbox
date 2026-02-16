defmodule WargamePersistence.Schemas.Leader do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_ranks ~w(lieutenant captain major colonel general field_marshal)

  schema "leaders" do
    field :name, :string
    field :nationality, :string
    field :era, :string
    field :is_historical, :boolean, default: false
    field :rank, :string
    field :command_radius, :integer
    field :modifiers, :map, default: %{}

    belongs_to :replacement_leader, __MODULE__
    belongs_to :author, WargamePersistence.Schemas.User
    belongs_to :game_product, WargamePersistence.Schemas.GameProduct

    timestamps()
  end

  @required_fields [:name, :nationality, :era, :rank, :command_radius, :modifiers]
  @optional_fields [:is_historical, :replacement_leader_id, :author_id, :game_product_id]

  def changeset(leader, attrs) do
    leader
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_inclusion(:rank, @valid_ranks)
    |> validate_number(:command_radius, greater_than: 0, less_than_or_equal_to: 6)
    |> foreign_key_constraint(:replacement_leader_id)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:game_product_id)
  end

  def create_changeset(leader, attrs) do
    leader
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end

  def valid_ranks, do: @valid_ranks
end
