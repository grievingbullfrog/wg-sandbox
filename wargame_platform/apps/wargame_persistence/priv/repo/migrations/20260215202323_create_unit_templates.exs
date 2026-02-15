defmodule WargamePersistence.Repo.Migrations.CreateUnitTemplates do
  use Ecto.Migration

  def change do
    create table(:unit_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :nationality, :string, null: false
      add :era, :string, null: false
      add :category, :string, null: false
      add :unit_size, :string, null: false
      add :icon_type, :string
      add :stats, :map, null: false, default: %{}
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :published, :boolean, default: false

      timestamps()
    end

    create index(:unit_templates, [:nationality])
    create index(:unit_templates, [:era])
    create index(:unit_templates, [:category])
    create index(:unit_templates, [:author_id])
  end
end
