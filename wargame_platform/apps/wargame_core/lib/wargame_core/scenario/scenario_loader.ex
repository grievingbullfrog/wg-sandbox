defmodule WargameCore.Scenario.ScenarioLoader do
  @moduledoc """
  Converts fully-preloaded DB scenario schemas into WargameCore.Scenario.Scenario structs
  suitable for use with GameSupervisor.start_game/1.

  This is the bridge between the persistence layer and the pure-functional game core.
  """

  alias WargameCore.Scenario.{Scenario, ActionProfile}
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Hex.Coord

  @doc """
  Convert a fully-preloaded DB scenario into a core Scenario struct.

  Expects scenario to have these preloads:
    - :map
    - :action_profile
    - scenario_units: [:unit_template, :leader]
  """
  def from_db_scenario(db_scenario) do
    templates = build_templates(db_scenario.scenario_units)
    game_map = build_map(db_scenario.map)
    action_profile = build_action_profile(db_scenario.action_profile)
    sides = build_sides(db_scenario.sides)
    victory_conditions = build_victory_conditions(db_scenario.victory_conditions)
    weather_schedule = build_weather_schedule(db_scenario.weather_schedule)
    supply_sources = build_supply_sources(db_scenario.supply_sources)
    scenario_units = build_scenario_units(db_scenario.scenario_units)
    leaders = build_leaders(db_scenario.scenario_units)

    Scenario.new(%{
      id: db_scenario.id,
      name: db_scenario.name,
      description: db_scenario.description || "",
      era: db_scenario.era,
      map: game_map,
      action_profile: action_profile,
      sides: sides,
      first_move: safe_to_atom(db_scenario.first_move),
      max_turns: db_scenario.max_turns,
      date_start: db_scenario.date_start,
      date_per_turn: safe_to_atom(db_scenario.date_per_turn || "day"),
      templates: templates,
      scenario_units: scenario_units,
      leaders: leaders,
      victory_conditions: victory_conditions,
      weather_schedule: weather_schedule,
      supply_sources: supply_sources,
      reinforcement_mode: safe_to_atom(db_scenario.reinforcement_mode || "fixed"),
      special_rules: db_scenario.special_rules || %{}
    })
  end

  # -- Map Conversion --

  defp build_map(nil), do: nil

  defp build_map(db_map) do
    tiles = deserialize_tile_data(db_map.tile_data)

    %GameMap{
      id: db_map.id,
      name: db_map.name,
      description: db_map.description || "",
      width: db_map.width,
      height: db_map.height,
      scale: db_map.scale || 500,
      base_elevation: db_map.base_elevation || 0,
      centerpoint_lat: db_map.centerpoint_lat,
      centerpoint_lng: db_map.centerpoint_lng,
      tiles: tiles,
      default_terrain: safe_to_atom(db_map.default_terrain || "clear"),
      metadata: db_map.metadata || %{}
    }
  end

  # -- Action Profile Conversion --

  defp build_action_profile(nil), do: ActionProfile.ww2_standard()

  defp build_action_profile(db_profile) do
    action_options =
      (db_profile.actions["options"] || [])
      |> Enum.map(fn opt ->
        %{
          id: safe_to_atom(opt["id"]),
          move: opt["move"] || false,
          fire: opt["fire"] || false,
          melee: opt["melee"] || false,
          move_penalty: opt["move_penalty"],
          entrench: opt["entrench"]
        }
      end)

    phase_sequence =
      (db_profile.phase_sequence["phases"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {phase, idx} ->
        %{
          id: safe_to_atom(phase["id"]),
          name: phase["name"],
          allows_movement: phase["allows_movement"] || false,
          allows_combat: phase["allows_combat"] || false,
          allows_orders: phase["allows_orders"] || false,
          is_optional: phase["is_optional"] || false,
          order: idx
        }
      end)

    ActionProfile.new(%{
      id: db_profile.id,
      name: db_profile.name,
      era: db_profile.era,
      rules_module: parse_module(db_profile.rules_module),
      action_options: action_options,
      phase_sequence: phase_sequence
    })
  end

  # -- Template Conversion --

  defp build_templates(scenario_units) do
    scenario_units
    |> Enum.map(& &1.unit_template)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
    |> Map.new(fn db_template ->
      {db_template.id, convert_unit_template(db_template)}
    end)
  end

  defp convert_unit_template(db_template) do
    stats = db_template.stats || %{}

    %UnitTemplate{
      id: db_template.id,
      name: db_template.name,
      nationality: db_template.nationality,
      era: db_template.era,
      category: safe_to_atom(db_template.category),
      unit_size: safe_to_atom(db_template.unit_size),
      icon_type: db_template.icon_type || db_template.category,
      attack_soft: stats["attack_soft"] || 0,
      attack_hard: stats["attack_hard"] || 0,
      defense: stats["defense"] || 0,
      armor: stats["armor"] || 0,
      movement_points: stats["movement_points"] || 4,
      movement_type: safe_to_atom(stats["movement_type"] || "foot"),
      range: stats["range"] || 0,
      spotting: stats["spotting"] || 1,
      initiative: stats["initiative"] || 0,
      max_strength: stats["max_strength"] || 10,
      max_ammo: stats["max_ammo"] || 0,
      max_fuel: stats["max_fuel"] || 0,
      can_bridge: stats["can_bridge"] || false,
      can_entrench: stats["can_entrench"] || true,
      is_organic_transport: stats["is_organic_transport"] || false
    }
  end

  # -- Scenario Units Conversion --

  defp build_scenario_units(db_units) do
    Enum.map(db_units, fn db_unit ->
      %{
        id: db_unit.id,
        name: db_unit.name,
        template_id: db_unit.unit_template_id,
        side: safe_to_atom(db_unit.side),
        force: safe_to_atom(db_unit.force),
        arrives_turn: db_unit.arrives_turn || 1,
        deploy_hex: Coord.new(db_unit.position_q, db_unit.position_r),
        experience: db_unit.experience || 0,
        morale: db_unit.morale || 50,
        current_strength: db_unit.strength
      }
    end)
  end

  # -- Leaders Conversion --

  defp build_leaders(db_units) do
    db_units
    |> Enum.filter(& &1.leader)
    |> Enum.map(fn db_unit ->
      leader = db_unit.leader
      modifiers = leader.modifiers || %{}

      %{
        id: leader.id,
        name: leader.name,
        nationality: leader.nationality,
        era: leader.era,
        rank: safe_to_atom(leader.rank),
        command_radius: leader.command_radius,
        attack_modifier: modifiers["attack_modifier"] || 0,
        defense_modifier: modifiers["defense_modifier"] || 0,
        morale_modifier: modifiers["morale_modifier"] || 0,
        initiative_modifier: modifiers["initiative_modifier"] || 0,
        abilities: Enum.map(modifiers["abilities"] || [], &safe_to_atom/1),
        position: Coord.new(db_unit.position_q, db_unit.position_r),
        side: safe_to_atom(db_unit.side),
        force: safe_to_atom(db_unit.force)
      }
    end)
    |> Enum.uniq_by(& &1.id)
  end

  # -- Sides Conversion --

  defp build_sides(%{"sides" => sides}) when is_list(sides) do
    Enum.map(sides, fn side ->
      %{
        id: safe_to_atom(side["id"]),
        name: side["name"],
        forces: Enum.map(side["forces"] || [], &safe_to_atom/1)
      }
    end)
  end

  defp build_sides(_), do: []

  # -- Victory Conditions Conversion --

  defp build_victory_conditions(nil), do: %{type: :victory_points}

  defp build_victory_conditions(vc) when is_map(vc) do
    vp_levels =
      case vc["vp_levels"] do
        nil -> %{}
        levels -> Map.new(levels, fn {k, v} -> {safe_to_atom(k), v} end)
      end

    unit_kill_vp =
      case vc["unit_kill_vp"] do
        nil -> %{}
        kills -> Map.new(kills, fn {k, v} -> {safe_to_atom(k), v} end)
      end

    %{
      type: safe_to_atom(vc["type"] || "victory_points"),
      sudden_death_vp: vc["sudden_death_vp"],
      vp_levels: vp_levels,
      unit_kill_vp: unit_kill_vp
    }
  end

  # -- Weather Schedule Conversion --

  defp build_weather_schedule(nil), do: []

  defp build_weather_schedule(%{"schedule" => schedule}) when is_list(schedule) do
    Enum.flat_map(schedule, fn entry ->
      turns = parse_turn_range(entry["turns"])
      weather = safe_to_atom(entry["weather"] || "clear")
      ground = safe_to_atom(entry["ground"] || "dry")

      case turns do
        first..last//1 -> [%{turns: first..last, weather: weather, ground: ground}]
        _ -> []
      end
    end)
  end

  defp build_weather_schedule(_), do: []

  # -- Supply Sources Conversion --

  defp build_supply_sources(nil), do: []

  defp build_supply_sources(%{"sources" => sources}) when is_list(sources) do
    Enum.map(sources, fn source ->
      %{
        side: safe_to_atom(source["side"]),
        hex: Coord.new(source["hex_q"], source["hex_r"])
      }
    end)
  end

  defp build_supply_sources(_), do: []

  # -- Helpers --

  defp parse_turn_range(range) when is_binary(range) do
    case String.split(range, "-") do
      [first, last] ->
        {f, _} = Integer.parse(first)
        {l, _} = Integer.parse(last)
        f..l

      [single] ->
        {n, _} = Integer.parse(single)
        n..n
    end
  end

  defp parse_turn_range(_), do: 1..1

  defp parse_module(nil), do: WargameCore.Rules.StandardRules

  defp parse_module(module_string) when is_binary(module_string) do
    String.to_existing_atom(module_string)
  rescue
    ArgumentError -> WargameCore.Rules.StandardRules
  end

  defp parse_module(module) when is_atom(module), do: module

  defp safe_to_atom(nil), do: nil
  defp safe_to_atom(value) when is_atom(value), do: value

  defp safe_to_atom(value) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> String.to_atom(value)
  end

  defp deserialize_tile_data(binary) when is_binary(binary) do
    :erlang.binary_to_term(binary)
  end

  defp deserialize_tile_data(nil), do: %{}
end
