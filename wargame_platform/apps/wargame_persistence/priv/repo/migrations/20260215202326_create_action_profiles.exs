defmodule WargamePersistence.Repo.Migrations.CreateActionProfiles do
  use Ecto.Migration

  def change do
    create table(:action_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :era, :string, null: false
      add :actions, :map, null: false, default: %{}
      add :phase_sequence, :map, null: false, default: %{}
      add :rules_module, :string, null: false

      timestamps()
    end

    create index(:action_profiles, [:era])
  end
end
