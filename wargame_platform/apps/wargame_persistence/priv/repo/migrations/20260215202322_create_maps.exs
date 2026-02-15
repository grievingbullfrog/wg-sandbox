defmodule WargamePersistence.Repo.Migrations.CreateMaps do
  use Ecto.Migration

  def change do
    create table(:maps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :version, :string
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :scale, :integer
      add :base_elevation, :integer, default: 0
      add :centerpoint_lat, :float
      add :centerpoint_lng, :float
      add :default_terrain, :string, default: "clear"
      add :metadata, :map, default: %{}
      add :tile_data, :binary
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :published, :boolean, default: false

      timestamps()
    end

    create index(:maps, [:author_id])
    create index(:maps, [:published])
  end
end
