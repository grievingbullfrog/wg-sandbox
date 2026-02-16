defmodule WargamePersistence.Schemas.Map do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "maps" do
    field :name, :string
    field :description, :string
    field :version, :string
    field :width, :integer
    field :height, :integer
    field :scale, :integer
    field :base_elevation, :integer, default: 0
    field :centerpoint_lat, :float
    field :centerpoint_lng, :float
    field :default_terrain, :string, default: "clear"
    field :metadata, :map, default: %{}
    field :tile_data, :binary
    field :published, :boolean, default: false

    belongs_to :author, WargamePersistence.Schemas.User
    belongs_to :game_product, WargamePersistence.Schemas.GameProduct

    has_many :scenarios, WargamePersistence.Schemas.Scenario

    timestamps()
  end

  @required_fields [:name, :width, :height]
  @optional_fields [
    :description, :version, :scale, :base_elevation,
    :centerpoint_lat, :centerpoint_lng, :default_terrain,
    :metadata, :tile_data, :author_id, :published, :game_product_id
  ]

  def changeset(map, attrs) do
    map
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:game_product_id)
  end

  def create_changeset(map, attrs) do
    map
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end

  @doc "Serialize a WargameCore.Map struct's tiles to compressed binary."
  def serialize_tile_data(%{tiles: tiles}) do
    :erlang.term_to_binary(tiles, [:compressed])
  end

  @doc "Deserialize binary tile data back to a tiles map."
  def deserialize_tile_data(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end

  def deserialize_tile_data(nil), do: %{}
end
