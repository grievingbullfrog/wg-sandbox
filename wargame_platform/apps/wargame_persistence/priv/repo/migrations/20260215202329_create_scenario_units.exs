defmodule WargamePersistence.Repo.Migrations.CreateScenarioUnits do
  use Ecto.Migration

  def change do
    create table(:scenario_units, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scenario_id, references(:scenarios, type: :binary_id, on_delete: :delete_all),
        null: false
      add :unit_template_id, references(:unit_templates, type: :binary_id, on_delete: :restrict),
        null: false
      add :leader_id, references(:leaders, type: :binary_id, on_delete: :nilify_all)
      add :side, :string, null: false
      add :force, :string, null: false
      add :name, :string, null: false
      add :position_q, :integer
      add :position_r, :integer
      add :arrives_turn, :integer, default: 1
      add :deploy_zone, :string
      add :strength, :integer, null: false
      add :experience, :integer, null: false, default: 0
      add :morale, :integer, null: false, default: 50
      add :attachment_ids, :map, default: %{}
      add :reinforcement_config, :map

      timestamps()
    end

    create index(:scenario_units, [:scenario_id])
    create index(:scenario_units, [:unit_template_id])
    create index(:scenario_units, [:leader_id])
  end
end
