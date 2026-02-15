defmodule WargamePersistence.Repo.Migrations.CreateScenarios do
  use Ecto.Migration

  def change do
    create table(:scenarios, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :map_id, references(:maps, type: :binary_id, on_delete: :restrict), null: false
      add :action_profile_id, references(:action_profiles, type: :binary_id, on_delete: :restrict),
        null: false
      add :era, :string, null: false
      add :date_start, :string
      add :date_per_turn, :string
      add :max_turns, :integer, null: false
      add :first_move, :string, null: false
      add :sides, :map, null: false, default: %{}
      add :victory_conditions, :map, null: false, default: %{}
      add :weather_schedule, :map, null: false, default: %{}
      add :supply_sources, :map, null: false, default: %{}
      add :reinforcement_mode, :string, default: "fixed"
      add :special_rules, :map, default: %{}
      add :published, :boolean, default: false

      timestamps()
    end

    create index(:scenarios, [:era])
    create index(:scenarios, [:map_id])
    create index(:scenarios, [:action_profile_id])
    create index(:scenarios, [:author_id])
  end
end
