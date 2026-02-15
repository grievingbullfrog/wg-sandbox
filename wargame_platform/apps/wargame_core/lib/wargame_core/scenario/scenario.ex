defmodule WargameCore.Scenario.Scenario do
  @moduledoc """
  Pure struct representing a complete scenario definition.

  A scenario bundles everything needed to play a game:
  - Map reference
  - Order of battle per side
  - Reinforcement schedule
  - Victory conditions
  - Weather schedule
  - Supply sources
  - Action profile (turn structure)

  The critical function `initial_game_state/1` converts a scenario into
  a complete game state map that the GameServer manages.
  """

  alias WargameCore.Scenario.{ActionProfile, Weather, Supply, Reinforcements}
  alias WargameCore.Turns.TurnState
  alias WargameCore.Units.{UnitInstance, Leader}

  @type victory_type :: :victory_points | :territorial | :elimination | :custom

  @type side :: %{
          id: atom(),
          name: String.t(),
          forces: [atom()]
        }

  @type victory_conditions :: %{
          type: victory_type(),
          sudden_death_vp: integer() | nil,
          vp_levels: %{atom() => integer()},
          unit_kill_vp: %{atom() => integer()}
        }

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t(),
          era: String.t(),
          map: map() | nil,
          action_profile: ActionProfile.t() | nil,
          sides: [side()],
          first_move: atom(),
          max_turns: pos_integer(),
          date_start: String.t() | nil,
          date_per_turn: atom(),
          scenario_units: [map()],
          leaders: [map()],
          victory_conditions: victory_conditions(),
          weather_schedule: [Weather.schedule_entry()],
          supply_sources: [Supply.supply_source()],
          reinforcement_mode: Reinforcements.reinforcement_mode(),
          special_rules: map(),
          templates: %{String.t() => map()}
        }

  defstruct [
    :id,
    :name,
    :map,
    :action_profile,
    :first_move,
    :date_start,
    description: "",
    era: "ww2",
    sides: [],
    max_turns: 10,
    date_per_turn: :day,
    scenario_units: [],
    leaders: [],
    victory_conditions: %{
      type: :victory_points,
      sudden_death_vp: nil,
      vp_levels: %{decisive: 80, tactical: 60, marginal: 40},
      unit_kill_vp: %{armor: 3, infantry: 1, leader: 5}
    },
    weather_schedule: [],
    supply_sources: [],
    reinforcement_mode: :fixed,
    special_rules: %{},
    templates: %{}
  ]

  @doc """
  Creates a new Scenario from a map of attributes.
  """
  @spec new(map()) :: t()
  def new(attrs) when is_map(attrs) do
    struct!(__MODULE__, attrs)
  end

  @doc """
  Returns the side config by side id.
  """
  @spec get_side(t(), atom()) :: side() | nil
  def get_side(%__MODULE__{sides: sides}, side_id) do
    Enum.find(sides, fn side -> side.id == side_id end)
  end

  @doc """
  Returns the list of forces for a given side.
  """
  @spec forces_for_side(t(), atom()) :: [atom()]
  def forces_for_side(%__MODULE__{} = scenario, side_id) do
    case get_side(scenario, side_id) do
      nil -> []
      side -> side.forces
    end
  end

  @doc """
  Converts a scenario into a complete initial game state.

  This is the critical function that bootstraps a new game:
  1. Sets up the map
  2. Instantiates all turn-1 units into UnitInstance structs
  3. Places leaders
  4. Creates the TurnState from the action profile's phase sequence
  5. Sets initial weather from schedule
  6. Calculates initial supply
  7. Returns the complete game state map
  """
  @spec initial_game_state(t()) :: map()
  def initial_game_state(%__MODULE__{} = scenario) do
    # 1. Build the phase sequence and turn state
    phases = if scenario.action_profile do
      ActionProfile.phases(scenario.action_profile)
    else
      WargameCore.Turns.Phase.standard_phases()
    end

    side_ids = Enum.map(scenario.sides, & &1.id)

    turn_state = TurnState.new(phases, side_ids,
      max_turns: scenario.max_turns
    )

    # 2. Deploy turn-1 units
    turn_1_units = Reinforcements.deploy_reinforcements(1, scenario.scenario_units, scenario.reinforcement_mode)

    units = instantiate_units(turn_1_units, scenario.templates)

    # 3. Place leaders
    leaders = instantiate_leaders(scenario.leaders)

    # 4. Initial weather
    weather = Weather.current_weather(scenario.weather_schedule, 1)

    # 5. Get tiles map from the scenario map
    tiles = extract_tiles(scenario.map)

    # 6. Calculate initial supply for each side
    supply_cache = Enum.reduce(side_ids, %{}, fn side_id, acc ->
      side_supply = Supply.calculate_supply_status(tiles, units, scenario.supply_sources, side_id)
      Map.merge(acc, side_supply)
    end)

    # 7. Remaining reinforcements (units not yet deployed)
    pending_units = scenario.scenario_units
      |> Enum.reject(fn u -> u.arrives_turn == 1 end)

    %{
      scenario_id: scenario.id,
      scenario_name: scenario.name,
      map: scenario.map,
      tiles: tiles,
      units: units,
      leaders: leaders,
      turn_state: turn_state,
      action_profile: scenario.action_profile,
      rules_module: resolve_rules_module(scenario),
      weather: weather,
      weather_schedule: scenario.weather_schedule,
      supply_cache: supply_cache,
      supply_sources: scenario.supply_sources,
      victory_conditions: scenario.victory_conditions,
      reinforcement_mode: scenario.reinforcement_mode,
      pending_reinforcements: pending_units,
      templates: scenario.templates,
      fog_of_war: %{},
      action_log: [],
      players: %{},
      settings: %{fog_of_war: :none},
      status: :playing,
      result: nil
    }
  end

  # --- Private helpers ---

  defp instantiate_units(unit_defs, templates) do
    Enum.into(unit_defs, %{}, fn unit_def ->
      template = Map.get(templates, unit_def.template_id) || Map.get(templates, unit_def[:unit_template_id])

      instance = if template do
        Reinforcements.instantiate_reinforcement(unit_def, template)
      else
        # Fallback: create a minimal instance from the unit def
        UnitInstance.new(
          %WargameCore.Units.UnitTemplate{
            name: unit_def[:name] || "Unknown",
            nationality: "unknown",
            era: "ww2",
            category: :infantry,
            unit_size: :platoon,
            icon_type: "infantry",
            attack_soft: 1, attack_hard: 1, defense: 1, armor: 0,
            movement_points: 4, movement_type: :foot, range: 1,
            spotting: 2, initiative: 1, max_strength: 10,
            max_ammo: 10, max_fuel: 0,
            can_bridge: false, can_entrench: true, is_organic_transport: false
          },
          %{
            id: unit_def[:id],
            name: unit_def[:name],
            side: unit_def[:side],
            force: unit_def[:force],
            position: unit_def[:deploy_hex],
            experience: unit_def[:experience] || 0,
            morale: unit_def[:morale] || 80
          }
        )
      end

      {instance.id, instance}
    end)
  end

  defp instantiate_leaders(leader_defs) do
    Enum.into(leader_defs, %{}, fn leader_def ->
      leader = if is_struct(leader_def, Leader) do
        leader_def
      else
        Leader.new(leader_def)
      end

      {leader.id, leader}
    end)
  end

  defp extract_tiles(nil), do: %{}
  defp extract_tiles(%{tiles: tiles}) when is_map(tiles), do: tiles
  defp extract_tiles(map) when is_map(map), do: Map.get(map, :tiles, %{})

  defp resolve_rules_module(%__MODULE__{action_profile: %ActionProfile{rules_module: mod}})
       when is_atom(mod) and not is_nil(mod) do
    mod
  end

  defp resolve_rules_module(%__MODULE__{action_profile: %ActionProfile{rules_module: mod}})
       when is_binary(mod) do
    String.to_existing_atom(mod)
  rescue
    ArgumentError -> WargameCore.Rules.StandardRules
  end

  defp resolve_rules_module(_), do: WargameCore.Rules.StandardRules
end
