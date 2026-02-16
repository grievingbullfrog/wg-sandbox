defmodule WargamePersistence.Repo.Migrations.CreateGameProducts do
  use Ecto.Migration

  def change do
    create table(:game_products, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :tagline, :string
      add :description, :text
      add :era, :string, null: false
      add :cover_image_url, :string
      add :metadata, :map, default: %{}
      add :published, :boolean, default: false
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:game_products, [:slug])
    create index(:game_products, [:era])
    create index(:game_products, [:published])

    # Add game_product_id to existing resource tables
    alter table(:scenarios) do
      add :game_product_id, references(:game_products, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:maps) do
      add :game_product_id, references(:game_products, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:unit_templates) do
      add :game_product_id, references(:game_products, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:leaders) do
      add :game_product_id, references(:game_products, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:scenarios, [:game_product_id])
    create index(:maps, [:game_product_id])
    create index(:unit_templates, [:game_product_id])
    create index(:leaders, [:game_product_id])
  end
end
