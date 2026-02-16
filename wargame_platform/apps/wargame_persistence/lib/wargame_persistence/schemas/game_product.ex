defmodule WargamePersistence.Schemas.GameProduct do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "game_products" do
    field :name, :string
    field :slug, :string
    field :tagline, :string
    field :description, :string
    field :era, :string
    field :cover_image_url, :string
    field :metadata, :map, default: %{}
    field :published, :boolean, default: false

    belongs_to :author, WargamePersistence.Schemas.User

    has_many :scenarios, WargamePersistence.Schemas.Scenario
    has_many :maps, WargamePersistence.Schemas.Map
    has_many :unit_templates, WargamePersistence.Schemas.UnitTemplate
    has_many :leaders, WargamePersistence.Schemas.Leader

    timestamps()
  end

  @required_fields [:name, :slug, :era]
  @optional_fields [:tagline, :description, :cover_image_url, :metadata, :published, :author_id]

  def changeset(product, attrs) do
    product
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9][a-z0-9-]*[a-z0-9]$/, message: "must be lowercase with hyphens only")
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:author_id)
  end
end
