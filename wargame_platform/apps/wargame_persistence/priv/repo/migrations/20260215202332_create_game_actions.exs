defmodule WargamePersistence.Repo.Migrations.CreateGameActions do
  use Ecto.Migration

  def change do
    create table(:game_actions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :game_id, references(:games, type: :binary_id, on_delete: :delete_all), null: false
      add :turn, :integer, null: false
      add :phase, :string, null: false
      add :side, :string, null: false
      add :sequence, :integer, null: false
      add :action, :map, null: false, default: %{}

      timestamps()
    end

    create index(:game_actions, [:game_id])
    create index(:game_actions, [:game_id, :turn])
  end
end
