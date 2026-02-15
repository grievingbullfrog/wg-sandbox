defmodule WargamePersistence.Schemas.Scenario do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_reinforcement_modes ~w(fixed variable conditional)

  schema "scenarios" do
    field :name, :string
    field :description, :string
    field :era, :string
    field :date_start, :string
    field :date_per_turn, :string
    field :max_turns, :integer
    field :first_move, :string
    field :sides, :map, default: %{}
    field :victory_conditions, :map, default: %{}
    field :weather_schedule, :map, default: %{}
    field :supply_sources, :map, default: %{}
    field :reinforcement_mode, :string, default: "fixed"
    field :special_rules, :map, default: %{}
    field :published, :boolean, default: false

    belongs_to :author, WargamePersistence.Schemas.User
    belongs_to :map, WargamePersistence.Schemas.Map
    belongs_to :action_profile, WargamePersistence.Schemas.ActionProfile

    has_many :scenario_units, WargamePersistence.Schemas.ScenarioUnit
    has_many :games, WargamePersistence.Schemas.Game

    timestamps()
  end

  @required_fields [:name, :era, :max_turns, :first_move, :map_id, :action_profile_id, :sides, :victory_conditions]
  @optional_fields [
    :description, :date_start, :date_per_turn,
    :weather_schedule, :supply_sources, :reinforcement_mode,
    :special_rules, :author_id, :published
  ]

  def changeset(scenario, attrs) do
    scenario
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:name, min: 1, max: 255)
    |> validate_number(:max_turns, greater_than: 0)
    |> validate_inclusion(:reinforcement_mode, @valid_reinforcement_modes)
    |> foreign_key_constraint(:map_id)
    |> foreign_key_constraint(:action_profile_id)
    |> foreign_key_constraint(:author_id)
  end

  def create_changeset(scenario, attrs) do
    scenario
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end
end
