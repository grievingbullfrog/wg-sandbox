defmodule WargamePersistence.Schemas.ScenarioUnit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "scenario_units" do
    field :side, :string
    field :force, :string
    field :name, :string
    field :position_q, :integer
    field :position_r, :integer
    field :arrives_turn, :integer, default: 1
    field :deploy_zone, :string
    field :strength, :integer
    field :experience, :integer, default: 0
    field :morale, :integer, default: 50
    field :attachment_ids, :map, default: %{}
    field :reinforcement_config, :map

    belongs_to :scenario, WargamePersistence.Schemas.Scenario
    belongs_to :unit_template, WargamePersistence.Schemas.UnitTemplate
    belongs_to :leader, WargamePersistence.Schemas.Leader

    timestamps()
  end

  @required_fields [:scenario_id, :unit_template_id, :side, :force, :name, :strength]
  @optional_fields [
    :leader_id, :position_q, :position_r, :arrives_turn,
    :deploy_zone, :experience, :morale, :attachment_ids,
    :reinforcement_config
  ]

  def changeset(unit, attrs) do
    unit
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:strength, greater_than: 0)
    |> validate_number(:experience, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_number(:morale, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:arrives_turn, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:scenario_id)
    |> foreign_key_constraint(:unit_template_id)
    |> foreign_key_constraint(:leader_id)
  end

  def create_changeset(unit, attrs) do
    unit
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end
end
