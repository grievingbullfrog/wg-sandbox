defmodule WargamePersistence.Schemas.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :email, :string
    field :password_hash, :string

    has_many :maps, WargamePersistence.Schemas.Map, foreign_key: :author_id
    has_many :unit_templates, WargamePersistence.Schemas.UnitTemplate, foreign_key: :author_id
    has_many :leaders, WargamePersistence.Schemas.Leader, foreign_key: :author_id
    has_many :scenarios, WargamePersistence.Schemas.Scenario, foreign_key: :author_id

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password_hash])
    |> validate_required([:username, :email])
    |> validate_length(:username, min: 3, max: 50)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  def create_changeset(user, attrs) do
    user
    |> changeset(attrs)
    |> validate_required([:username, :email])
  end
end
