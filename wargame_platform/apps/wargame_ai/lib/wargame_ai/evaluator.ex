defmodule WargameAi.Evaluator do
  @moduledoc """
  Scores board positions from a given side's perspective.

  Returns a numeric score where higher is better for the evaluated side.
  Weights are configurable via personality profiles.
  """

  alias WargameCore.Map, as: GameMap
  alias WargameCore.Hex.Coord

  @default_weights %{
    vp_control: 10.0,
    unit_strength: 3.0,
    unit_count: 5.0,
    leader_survival: 8.0,
    territorial_depth: 1.5,
    supply_status: 2.0,
    enemy_disruption: 2.0
  }

  @doc """
  Evaluates the board position for the given side.

  Returns a numeric score. Higher is better for `side`.

  ## Options
    - `:weights` - Map of weight overrides (merged with defaults)
  """
  @spec evaluate_position(map(), atom(), keyword()) :: float()
  def evaluate_position(game_state, side, opts \\ []) do
    weights = Map.merge(@default_weights, Keyword.get(opts, :weights, %{}))
    enemy_sides = other_sides(game_state, side)

    vp_score = vp_control_score(game_state, side, enemy_sides) * weights.vp_control
    strength_score = unit_strength_score(game_state, side, enemy_sides) * weights.unit_strength
    count_score = unit_count_score(game_state, side, enemy_sides) * weights.unit_count
    leader_score = leader_survival_score(game_state, side) * weights.leader_survival
    depth_score = territorial_depth_score(game_state, side) * weights.territorial_depth
    disruption_score = enemy_disruption_score(game_state, enemy_sides) * weights.enemy_disruption

    vp_score + strength_score + count_score + leader_score + depth_score + disruption_score
  end

  @doc """
  Returns the default evaluation weights.
  """
  @spec default_weights() :: map()
  def default_weights, do: @default_weights

  @doc """
  Scores a single hex for a unit considering tactical value.

  Used by movement AI to evaluate destination quality.
  """
  @spec score_hex(map(), atom(), Coord.t(), keyword()) :: float()
  def score_hex(game_state, side, coord, opts \\ []) do
    map = game_state.map
    tile = GameMap.get_tile(map, coord)

    if tile == nil do
      -100.0
    else
      vp_value = tile.victory_points * 10.0
      terrain_defense = terrain_defense_value(tile.terrain)

      # Proximity to nearest enemy
      enemy_proximity = nearest_enemy_distance(game_state, side, coord)
      proximity_score = if enemy_proximity > 0, do: 5.0 / enemy_proximity, else: 0.0

      # Friendly support (count allies within 2 hexes)
      support = count_friendly_nearby(game_state, side, coord, 2)
      support_score = min(support, 3) * 1.5

      # Leader command bonus
      leader_bonus = if in_leader_command_radius?(game_state, side, coord), do: 2.0, else: 0.0

      # VP proximity - closer to uncontrolled VP hexes is better
      vp_proximity_score = vp_proximity_value(game_state, side, coord)

      objective_weight = Keyword.get(opts, :objective_weight, 1.0)

      (vp_value + vp_proximity_score) * objective_weight + terrain_defense + proximity_score + support_score + leader_bonus
    end
  end

  # --- VP Control ---

  defp vp_control_score(game_state, side, enemy_sides) do
    map = game_state.map
    my_vp = GameMap.victory_points_for(map, side)

    enemy_vp =
      Enum.reduce(enemy_sides, 0, fn es, acc ->
        acc + GameMap.victory_points_for(map, es)
      end)

    (my_vp - enemy_vp) * 1.0
  end

  # --- Unit Strength ---

  defp unit_strength_score(game_state, side, enemy_sides) do
    my_strength = total_strength(game_state, side)
    enemy_strength = Enum.reduce(enemy_sides, 0, fn es, acc -> acc + total_strength(game_state, es) end)

    if enemy_strength > 0 do
      (my_strength - enemy_strength) / max(enemy_strength, 1)
    else
      my_strength * 1.0
    end
  end

  defp total_strength(game_state, side) do
    game_state.units
    |> Map.values()
    |> Enum.filter(&(&1.side == side and &1.position != nil))
    |> Enum.reduce(0, fn unit, acc -> acc + unit.current_strength end)
  end

  # --- Unit Count ---

  defp unit_count_score(game_state, side, enemy_sides) do
    my_count = count_active_units(game_state, side)
    enemy_count = Enum.reduce(enemy_sides, 0, fn es, acc -> acc + count_active_units(game_state, es) end)
    (my_count - enemy_count) * 1.0
  end

  defp count_active_units(game_state, side) do
    game_state.units
    |> Map.values()
    |> Enum.count(&(&1.side == side and &1.position != nil and &1.current_strength > 0))
  end

  # --- Leaders ---

  defp leader_survival_score(game_state, side) do
    leaders = Map.get(game_state, :leaders, %{})

    leaders
    |> Map.values()
    |> Enum.count(&(&1.side == side and &1.position != nil))
    |> Kernel.*(1.0)
  end

  # --- Territorial Depth ---

  defp territorial_depth_score(game_state, side) do
    units = units_for_side(game_state, side)

    if Enum.empty?(units) do
      0.0
    else
      positions = Enum.map(units, & &1.position) |> Enum.reject(&is_nil/1)

      if length(positions) < 2 do
        0.0
      else
        # Average distance between our own units - spread is good for territory
        pairs = for a <- positions, b <- positions, a != b, do: Coord.distance(a, b)

        if Enum.empty?(pairs) do
          0.0
        else
          avg_spread = Enum.sum(pairs) / length(pairs)
          # Moderate spread is good, too much is bad (isolated units)
          if avg_spread <= 4, do: avg_spread * 1.0, else: max(8 - avg_spread, 0) * 1.0
        end
      end
    end
  end

  # --- Enemy Disruption ---

  defp enemy_disruption_score(game_state, enemy_sides) do
    enemy_units =
      game_state.units
      |> Map.values()
      |> Enum.filter(&(&1.side in enemy_sides))

    disrupted = Enum.count(enemy_units, & &1.is_disrupted)
    routed = Enum.count(enemy_units, & &1.is_routed)

    disrupted * 1.0 + routed * 2.0
  end

  # --- Hex Scoring Helpers ---

  defp terrain_defense_value(:forest), do: 3.0
  defp terrain_defense_value(:mountain), do: 4.0
  defp terrain_defense_value(:urban), do: 4.0
  defp terrain_defense_value(:town), do: 3.0
  defp terrain_defense_value(:hill), do: 2.0
  defp terrain_defense_value(:swamp), do: 1.0
  defp terrain_defense_value(_), do: 0.0

  defp vp_proximity_value(game_state, side, coord) do
    game_state.map.tiles
    |> Map.values()
    |> Enum.filter(&(&1.victory_points > 0 and &1.control != side))
    |> Enum.map(fn tile ->
      dist = Coord.distance(coord, tile.coord)
      if dist == 0, do: 0.0, else: tile.victory_points * 2.0 / dist
    end)
    |> Enum.sum()
  end

  defp nearest_enemy_distance(game_state, side, coord) do
    game_state.units
    |> Map.values()
    |> Enum.filter(&(&1.side != side and &1.position != nil and &1.current_strength > 0))
    |> Enum.map(&Coord.distance(coord, &1.position))
    |> Enum.min(fn -> 99 end)
  end

  defp count_friendly_nearby(game_state, side, coord, radius) do
    game_state.units
    |> Map.values()
    |> Enum.count(fn unit ->
      unit.side == side and unit.position != nil and
        unit.position != coord and
        Coord.distance(coord, unit.position) <= radius
    end)
  end

  defp in_leader_command_radius?(game_state, side, coord) do
    leaders = Map.get(game_state, :leaders, %{})

    leaders
    |> Map.values()
    |> Enum.any?(fn leader ->
      leader.side == side and leader.position != nil and
        Coord.distance(leader.position, coord) <= leader.command_radius
    end)
  end

  # --- Utility ---

  defp units_for_side(game_state, side) do
    game_state.units
    |> Map.values()
    |> Enum.filter(&(&1.side == side))
  end

  defp other_sides(game_state, side) do
    game_state.turn_state.sides
    |> Enum.reject(&(&1 == side))
  end
end
