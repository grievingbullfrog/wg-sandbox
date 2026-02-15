defmodule WargamePersistence.Repo.Migrations.CreateLeaders do
  use Ecto.Migration

  def change do
    create table(:leaders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :nationality, :string, null: false
      add :era, :string, null: false
      add :is_historical, :boolean, default: false
      add :rank, :string, null: false
      add :command_radius, :integer, null: false
      add :modifiers, :map, null: false, default: %{}
      add :replacement_leader_id, references(:leaders, type: :binary_id, on_delete: :nilify_all)
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:leaders, [:nationality])
    create index(:leaders, [:era])
    create index(:leaders, [:rank])
    create index(:leaders, [:author_id])
  end
end
