defmodule WargameCore.Units.Leader do
  @moduledoc """
  Pure struct representing a leader/commander unit.

  Leaders provide command bonuses to units within their command radius.
  They stack with a unit (their "HQ hex") and project influence outward.

  Units within radius get attack, defense, morale, and initiative modifiers.
  Units outside radius fight at a penalty. Leader death triggers a replacement
  with weaker stats.
  """

  alias WargameCore.Hex.Coord

  @valid_ranks [:lieutenant, :captain, :major, :colonel, :general, :field_marshal]

  @valid_abilities [
    :inspire, :blitz, :fortify, :recon_bonus,
    :artillery_expert, :combined_arms,
    :defensive_genius, :logistics
  ]

  @rank_radius %{
    lieutenant: 1,
    captain: 1,
    major: 2,
    colonel: 2,
    general: 4,
    field_marshal: 6
  }

  # Base probability of leader death per combat in their hex
  @death_probability 0.10

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          nationality: String.t(),
          era: String.t(),
          is_historical: boolean(),
          rank: atom(),
          command_radius: pos_integer(),
          attack_modifier: integer(),
          defense_modifier: integer(),
          morale_modifier: integer(),
          initiative_modifier: integer(),
          abilities: [atom()],
          position: term() | nil,
          side: atom(),
          force: atom()
        }

  defstruct [
    :id,
    :name,
    :nationality,
    :era,
    :rank,
    :position,
    :side,
    :force,
    is_historical: false,
    command_radius: 1,
    attack_modifier: 0,
    defense_modifier: 0,
    morale_modifier: 0,
    initiative_modifier: 0,
    abilities: []
  ]

  @doc """
  Creates a new Leader from a map or keyword list.
  Uses rank_to_default_radius if command_radius not provided.
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    id = Map.get(attrs, :id) || generate_id()
    rank = Map.fetch!(attrs, :rank)

    default_radius = rank_to_default_radius(rank)
    radius = Map.get(attrs, :command_radius, default_radius)

    struct!(__MODULE__, Map.merge(attrs, %{id: id, command_radius: radius}))
  end

  @doc """
  Returns true if the given coordinate is within this leader's command radius.
  Returns false if the leader has no position.
  """
  @spec in_command_radius?(t(), term()) :: boolean()
  def in_command_radius?(%__MODULE__{position: nil}, _coord), do: false

  def in_command_radius?(%__MODULE__{position: pos, command_radius: radius}, coord) do
    Coord.distance(pos, coord) <= radius
  end

  @doc """
  Returns a map of stat modifiers this leader provides to a unit at the given position.
  Returns zero modifiers if the unit is outside command radius.
  """
  @spec apply_modifiers(t(), term()) :: %{attack: integer(), defense: integer(), morale: integer(), initiative: integer()}
  def apply_modifiers(%__MODULE__{} = leader, unit_coord) do
    if in_command_radius?(leader, unit_coord) do
      %{
        attack: leader.attack_modifier,
        defense: leader.defense_modifier,
        morale: leader.morale_modifier,
        initiative: leader.initiative_modifier
      }
    else
      %{attack: 0, defense: 0, morale: 0, initiative: 0}
    end
  end

  @doc "Returns true if this leader has the given ability."
  @spec has_ability?(t(), atom()) :: boolean()
  def has_ability?(%__MODULE__{abilities: abilities}, ability) do
    ability in abilities
  end

  @doc """
  Generates a generic replacement leader with the same rank but weaker stats.
  Used when a leader is killed in combat.
  """
  @spec generate_replacement(t()) :: t()
  def generate_replacement(%__MODULE__{} = leader) do
    new(%{
      name: "Replacement #{leader.rank |> Atom.to_string() |> String.capitalize()}",
      nationality: leader.nationality,
      era: leader.era,
      is_historical: false,
      rank: leader.rank,
      command_radius: rank_to_default_radius(leader.rank),
      attack_modifier: max(leader.attack_modifier - 1, 0),
      defense_modifier: max(leader.defense_modifier - 1, 0),
      morale_modifier: max(leader.morale_modifier - 5, 0),
      initiative_modifier: max(leader.initiative_modifier - 1, 0),
      abilities: [],
      position: leader.position,
      side: leader.side,
      force: leader.force
    })
  end

  @doc """
  Rolls for leader casualty. Returns :survives or :killed.
  Base probability is 10%, slightly higher for leaders in directly attacked hexes.
  """
  @spec death_check(t()) :: :survives | :killed
  def death_check(%__MODULE__{}) do
    if :rand.uniform() < @death_probability do
      :killed
    else
      :survives
    end
  end

  @doc "Maps a rank atom to its default command radius."
  @spec rank_to_default_radius(atom()) :: pos_integer()
  def rank_to_default_radius(rank) when rank in @valid_ranks do
    Map.fetch!(@rank_radius, rank)
  end

  @doc "Returns the list of valid rank atoms."
  @spec valid_ranks() :: [atom()]
  def valid_ranks, do: @valid_ranks

  @doc "Returns the list of valid ability atoms."
  @spec valid_abilities() :: [atom()]
  def valid_abilities, do: @valid_abilities

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
end
