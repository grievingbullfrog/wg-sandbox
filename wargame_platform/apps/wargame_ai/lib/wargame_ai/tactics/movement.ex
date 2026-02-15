defmodule WargameAi.Tactics.Movement do
  @moduledoc """
  AI movement decision making.

  For each movable unit, scores all reachable hexes and selects the best
  destination based on tactical value, then generates move actions.
  """

  alias WargameAi.{Evaluator, Player}
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Units.UnitInstance
  alias WargameCore.Hex.Coord

  @doc """
  Plans movement actions for all AI units that can move.

  Returns a list of `{:move, unit_id, path}` and `{:hold, unit_id}` tuples.
  """
  @spec plan_moves(map(), Player.config()) :: [tuple()]
  def plan_moves(game_state, config) do
    side = config.side
    personality = Map.get(config, :personality, :balanced)

    movable_units =
      game_state.units
      |> Map.values()
      |> Enum.filter(&(&1.side == side and UnitInstance.can_move?(&1) and &1.position != nil))
      |> prioritize_units(game_state, personality)

    # Move units one at a time, updating occupied hexes as we go
    {actions, _occupied} =
      Enum.reduce(movable_units, {[], occupied_hexes(game_state, side)}, fn unit, {acc, occupied} ->
        case plan_unit_move(game_state, unit, config, occupied) do
          {:move, _id, path} = action ->
            new_pos = List.last(path)
            new_occupied = MapSet.put(MapSet.delete(occupied, Coord.to_key(unit.position)), Coord.to_key(new_pos))
            {acc ++ [action], new_occupied}

          {:hold, _id} = action ->
            {acc ++ [action], occupied}
        end
      end)

    actions
  end

  @doc """
  Plans movement for a single unit. Returns an action tuple.
  """
  @spec plan_unit_move(map(), UnitInstance.t(), Player.config(), MapSet.t()) :: tuple()
  def plan_unit_move(game_state, unit, config, occupied_keys) do
    map = game_state.map
    category = unit.template.category
    difficulty = Map.get(config, :difficulty, :normal)
    personality = Map.get(config, :personality, :balanced)

    # Get reachable hexes - returns %{"q,r" => movement_remaining}
    reachable = GameMap.reachable_hexes(map, unit.position, unit.movement_remaining, category)
    unit_key = Coord.to_key(unit.position)

    # Filter out already-occupied hexes (except current position)
    # Keys are already strings like "q,r"
    reachable =
      Enum.reject(reachable, fn {key, _remaining} ->
        key != unit_key and MapSet.member?(occupied_keys, key)
      end)

    if Enum.empty?(reachable) do
      {:hold, unit.id}
    else
      # Score each reachable hex - convert string keys back to Coord structs
      objective_weight = if personality == :aggressive, do: 2.0, else: 1.0

      scored =
        reachable
        |> Enum.map(fn {key, _remaining} ->
          {:ok, coord} = Coord.from_key(key)
          score = Evaluator.score_hex(game_state, config.side, coord, objective_weight: objective_weight)

          # Bonus for staying put if entrenched
          stay_bonus =
            if key == unit_key and unit.entrenchment > 0 do
              unit.entrenchment * 3.0
            else
              0.0
            end

          # Penalty for moving away from cover when defensive
          defensive_penalty =
            if personality == :defensive and key != unit_key do
              current_tile = GameMap.get_tile(map, unit.position)
              current_defense = if current_tile, do: terrain_defense_bonus(current_tile.terrain), else: 0
              -current_defense * 0.5
            else
              0.0
            end

          {coord, score + stay_bonus + defensive_penalty}
        end)
        |> Enum.sort_by(fn {_coord, score} -> score end, :desc)

      best_coord = Player.apply_difficulty(scored, difficulty)

      cond do
        best_coord == nil ->
          {:hold, unit.id}

        Coord.to_key(best_coord) == unit_key ->
          {:hold, unit.id}

        true ->
          # Find path to the best coordinate
          case find_move_path(map, unit, best_coord) do
            {:ok, path} -> {:move, unit.id, path}
            _ -> {:hold, unit.id}
          end
      end
    end
  end

  # --- Helpers ---

  defp prioritize_units(units, game_state, personality) do
    Enum.sort_by(units, fn unit ->
      strength_ratio = unit.current_strength / max(unit.template.max_strength, 1)
      damaged_priority = if strength_ratio < 0.5, do: -10, else: 0

      vp_proximity =
        game_state.map.tiles
        |> Map.values()
        |> Enum.filter(&(&1.victory_points > 0 and &1.control != unit.side))
        |> Enum.map(&Coord.distance(unit.position, &1.coord))
        |> Enum.min(fn -> 99 end)

      offensive_priority = if personality == :aggressive, do: -vp_proximity, else: 0

      damaged_priority + offensive_priority - vp_proximity
    end)
  end

  defp occupied_hexes(game_state, side) do
    game_state.units
    |> Map.values()
    |> Enum.filter(&(&1.side == side and &1.position != nil))
    |> Enum.map(&Coord.to_key(&1.position))
    |> MapSet.new()
  end

  defp find_move_path(map, unit, destination) do
    GameMap.find_path(map, unit.position, destination, unit.template.category)
  end

  defp terrain_defense_bonus(:forest), do: 3
  defp terrain_defense_bonus(:mountain), do: 4
  defp terrain_defense_bonus(:urban), do: 4
  defp terrain_defense_bonus(:town), do: 3
  defp terrain_defense_bonus(:hill), do: 2
  defp terrain_defense_bonus(_), do: 0
end
