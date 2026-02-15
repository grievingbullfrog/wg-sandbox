defmodule WargamePersistence.Repo.Migrations.CreateGames do
  use Ecto.Migration

  def change do
    create table(:games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scenario_id, references(:scenarios, type: :binary_id, on_delete: :restrict), null: false
      add :status, :string, null: false, default: "setup"
      add :players, :map, null: false, default: %{}
      add :settings, :map, null: false, default: %{}
      add :current_turn, :integer, default: 0
      add :game_state, :binary
      add :result, :map
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime

      timestamps()
    end

    create index(:games, [:scenario_id])
    create index(:games, [:status])
  end
end
