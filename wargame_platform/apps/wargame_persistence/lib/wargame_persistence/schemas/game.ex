defmodule WargamePersistence.Schemas.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_statuses ~w(setup playing paused finished)

  schema "games" do
    field :status, :string, default: "setup"
    field :players, :map, default: %{}
    field :settings, :map, default: %{}
    field :current_turn, :integer, default: 0
    field :game_state, :binary
    field :result, :map
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime

    belongs_to :scenario, WargamePersistence.Schemas.Scenario

    has_many :game_actions, WargamePersistence.Schemas.GameAction

    timestamps()
  end

  @required_fields [:scenario_id, :players, :settings]
  @optional_fields [:status, :current_turn, :game_state, :result, :started_at, :finished_at]

  def changeset(game, attrs) do
    game
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:current_turn, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:scenario_id)
  end

  def create_changeset(game, attrs) do
    game
    |> changeset(attrs)
    |> validate_required(@required_fields)
  end

  @doc "Serialize game state to compressed binary."
  def serialize_game_state(state) do
    :erlang.term_to_binary(state, [:compressed])
  end

  @doc "Deserialize game state from binary."
  def deserialize_game_state(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end

  def deserialize_game_state(nil), do: nil
end
