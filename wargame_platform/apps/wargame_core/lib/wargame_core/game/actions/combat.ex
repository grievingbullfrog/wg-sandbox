defmodule WargameCore.Game.Actions.Combat do
  @moduledoc """
  Handles combat actions in the game.

  Validates and executes attacks using the game's rules module.
  Combat in the standard model:
  1. Attackers declare target hex
  2. Odds are calculated (attack strength vs defense + terrain)
  3. 2d6 roll on CRT determines result
  4. Results applied: casualties, retreats, disruption
  """

  alias WargameCore.Units.{UnitInstance, Leader}
  alias WargameCore.Hex.Coord

  @doc """
  Validates and executes a combat action.

  Returns `{:ok, new_state}` or `{:error, reason}`.
  """
  @spec execute(map(), [String.t()], map()) :: {:ok, map()} | {:error, atom() | String.t()}
  def execute(state, attacker_ids, target_coord) do
    rules = state.rules_module

    with :ok <- rules.validate_phase_action(state, :attack),
         :ok <- rules.validate_attack(state, attacker_ids, target_coord),
         {:ok, odds_info} <- rules.calculate_combat_odds(state, attacker_ids, target_coord) do
      # Roll for result
      roll = :rand.uniform(6) + :rand.uniform(6)

      # Look up CRT result
      result = lookup_crt_result(odds_info.final_odds, roll)

      # Apply the combat result to game state
      new_state = apply_result(state, attacker_ids, target_coord, result, odds_info)

      # Mark attackers as having attacked
      new_state = mark_attackers(new_state, attacker_ids)

      # Check for leader casualties in the combat hex
      new_state = check_leader_casualties(new_state, attacker_ids, target_coord)

      {:ok, new_state}
    end
  end

  @doc """
  Executes combat with a specific roll (for testing determinism).
  """
  @spec execute_with_roll(map(), [String.t()], map(), integer()) :: {:ok, map()} | {:error, atom() | String.t()}
  def execute_with_roll(state, attacker_ids, target_coord, roll) do
    rules = state.rules_module

    with :ok <- rules.validate_phase_action(state, :attack),
         :ok <- rules.validate_attack(state, attacker_ids, target_coord),
         {:ok, odds_info} <- rules.calculate_combat_odds(state, attacker_ids, target_coord) do
      result = lookup_crt_result(odds_info.final_odds, roll)
      new_state = apply_result(state, attacker_ids, target_coord, result, odds_info)
      new_state = mark_attackers(new_state, attacker_ids)
      new_state = check_leader_casualties(new_state, attacker_ids, target_coord)
      {:ok, new_state}
    end
  end

  # --- CRT ---

  defp lookup_crt_result(odds, roll) do
    crt = %{
      "1:4": %{2 => :ae, 3 => :ae, 4 => :ae, 5 => :ar, 6 => :ar, 7 => :ar, 8 => :ar, 9 => :ex, 10 => :ex, 11 => :dr, 12 => :dr},
      "1:3": %{2 => :ae, 3 => :ae, 4 => :ar, 5 => :ar, 6 => :ar, 7 => :ex, 8 => :ex, 9 => :dr, 10 => :dr, 11 => :dr, 12 => :de},
      "1:2": %{2 => :ae, 3 => :ar, 4 => :ar, 5 => :ar, 6 => :ex, 7 => :ex, 8 => :dr, 9 => :dr, 10 => :dr, 11 => :de, 12 => :de},
      "2:3": %{2 => :ar, 3 => :ar, 4 => :ar, 5 => :ex, 6 => :ex, 7 => :dr, 8 => :dr, 9 => :dr, 10 => :de, 11 => :de, 12 => :de},
      "1:1": %{2 => :ar, 3 => :ar, 4 => :ex, 5 => :ex, 6 => :dr, 7 => :dr, 8 => :dr, 9 => :de, 10 => :de, 11 => :de, 12 => :de},
      "3:2": %{2 => :ar, 3 => :ex, 4 => :ex, 5 => :dr, 6 => :dr, 7 => :dr, 8 => :de, 9 => :de, 10 => :de, 11 => :de, 12 => :de},
      "2:1": %{2 => :ex, 3 => :ex, 4 => :dr, 5 => :dr, 6 => :dr, 7 => :de, 8 => :de, 9 => :de, 10 => :de, 11 => :de, 12 => :de},
      "3:1": %{2 => :ex, 3 => :dr, 4 => :dr, 5 => :dr, 6 => :de, 7 => :de, 8 => :de, 9 => :de, 10 => :de, 11 => :de, 12 => :de},
      "4:1": %{2 => :dr, 3 => :dr, 4 => :dr, 5 => :de, 6 => :de, 7 => :de, 8 => :de, 9 => :de, 10 => :de, 11 => :de, 12 => :de},
      "5:1": %{2 => :dr, 3 => :dr, 4 => :de, 5 => :de, 6 => :de, 7 => :de, 8 => :de, 9 => :de, 10 => :de, 11 => :de, 12 => :de}
    }

    Map.get(crt[odds], roll, :dr)
  end

  # --- Result application ---

  defp apply_result(state, attacker_ids, _target_coord, :ae, _odds_info) do
    # Attacker Eliminated: all attackers take heavy damage
    Enum.reduce(attacker_ids, state, fn id, acc ->
      update_unit(acc, id, fn unit -> apply_damage_to_unit(unit, unit.current_strength) end)
    end)
  end

  defp apply_result(state, attacker_ids, target_coord, :ar, _odds_info) do
    # Attacker Retreat: attackers lose 1 step and must retreat
    state
    |> damage_units(attacker_ids, 1)
    |> retreat_units(attacker_ids, target_coord, :away_from_target)
  end

  defp apply_result(state, attacker_ids, target_coord, :ex, _odds_info) do
    # Exchange: both sides lose proportional strength
    defender_ids = units_at_coord(state, target_coord) |> Enum.map(& &1.id)

    state
    |> damage_units(attacker_ids, 2)
    |> damage_units(defender_ids, 2)
  end

  defp apply_result(state, attacker_ids, target_coord, :dr, _odds_info) do
    # Defender Retreat: defenders lose 1 step and must retreat
    defender_ids = units_at_coord(state, target_coord) |> Enum.map(& &1.id)
    attacker_positions = Enum.map(attacker_ids, fn id ->
      state.units[id].position
    end)

    state
    |> damage_units(defender_ids, 1)
    |> retreat_defenders(defender_ids, target_coord, attacker_positions)
  end

  defp apply_result(state, _attacker_ids, target_coord, :de, _odds_info) do
    # Defender Eliminated: all defenders take heavy damage
    defender_ids = units_at_coord(state, target_coord) |> Enum.map(& &1.id)
    Enum.reduce(defender_ids, state, fn id, acc ->
      update_unit(acc, id, fn unit -> apply_damage_to_unit(unit, unit.current_strength) end)
    end)
  end

  # --- Helpers ---

  defp damage_units(state, unit_ids, amount) do
    Enum.reduce(unit_ids, state, fn id, acc ->
      update_unit(acc, id, fn unit -> apply_damage_to_unit(unit, amount) end)
    end)
  end

  defp apply_damage_to_unit(%UnitInstance{} = unit, amount) do
    UnitInstance.apply_damage(unit, amount)
  end

  defp apply_damage_to_unit(unit, amount) do
    new_strength = max((unit.current_strength || 0) - amount, 0)
    %{unit | current_strength: new_strength}
  end

  defp retreat_units(state, unit_ids, reference_coord, :away_from_target) do
    Enum.reduce(unit_ids, state, fn id, acc ->
      case Map.get(acc.units, id) do
        nil -> acc
        unit ->
          retreat_hex = find_retreat_hex(acc, unit, reference_coord)
          if retreat_hex do
            update_unit(acc, id, fn u -> %{u | position: retreat_hex} end)
          else
            # Can't retreat - additional step loss
            update_unit(acc, id, fn u -> apply_damage_to_unit(u, 1) end)
          end
      end
    end)
  end

  defp retreat_defenders(state, defender_ids, _target_coord, attacker_positions) do
    # Find the average attacker direction and retreat away from it
    Enum.reduce(defender_ids, state, fn id, acc ->
      case Map.get(acc.units, id) do
        nil -> acc
        unit ->
          retreat_hex = find_retreat_hex_from_attackers(acc, unit, attacker_positions)
          if retreat_hex do
            # Reset entrenchment on retreat
            update_unit(acc, id, fn u -> %{u | position: retreat_hex, entrenchment: 0} end)
          else
            # Can't retreat - additional damage
            update_unit(acc, id, fn u -> apply_damage_to_unit(u, 1) end)
          end
      end
    end)
  end

  defp find_retreat_hex(state, unit, reference_coord) do
    # Retreat to neighbor hex that's farthest from reference and not occupied by enemy
    Coord.neighbors(unit.position)
    |> Enum.filter(fn hex -> valid_retreat_hex?(state, hex, unit.side) end)
    |> Enum.sort_by(fn hex -> -Coord.distance(hex, reference_coord) end)
    |> List.first()
  end

  defp find_retreat_hex_from_attackers(state, unit, attacker_positions) do
    # Retreat away from the center of mass of attackers
    avg_q = Enum.sum(Enum.map(attacker_positions, & &1.q)) / max(length(attacker_positions), 1)
    avg_r = Enum.sum(Enum.map(attacker_positions, & &1.r)) / max(length(attacker_positions), 1)

    Coord.neighbors(unit.position)
    |> Enum.filter(fn hex -> valid_retreat_hex?(state, hex, unit.side) end)
    |> Enum.sort_by(fn hex ->
      # Sort by distance from attacker center (farthest first)
      -(:math.pow(hex.q - avg_q, 2) + :math.pow(hex.r - avg_r, 2))
    end)
    |> List.first()
  end

  defp valid_retreat_hex?(state, hex, side) do
    tiles = Map.get(state, :tiles, %{})
    tile = Map.get(tiles, hex)

    # Must be a valid hex on the map
    tile != nil &&
      # Must not be impassable
      tile.terrain not in [:ocean, :freshwater_lake] &&
      # Must not have enemy units
      not has_enemy_units?(state, hex, side)
  end

  defp has_enemy_units?(state, hex, friendly_side) do
    state.units
    |> Map.values()
    |> Enum.any?(fn unit -> unit.position == hex && unit.side != friendly_side end)
  end

  defp units_at_coord(state, coord) do
    state.units
    |> Map.values()
    |> Enum.filter(fn unit -> unit.position == coord end)
  end

  defp mark_attackers(state, attacker_ids) do
    Enum.reduce(attacker_ids, state, fn id, acc ->
      update_unit(acc, id, fn unit -> %{unit | has_attacked: true} end)
    end)
  end

  defp check_leader_casualties(state, attacker_ids, target_coord) do
    # Check if any leaders at the target hex or attacker hexes might be casualties
    all_combat_hexes = [target_coord | Enum.map(attacker_ids, fn id ->
      case Map.get(state.units, id) do
        nil -> nil
        unit -> unit.position
      end
    end)] |> Enum.reject(&is_nil/1) |> Enum.uniq()

    leaders = Map.get(state, :leaders, %{})

    Enum.reduce(leaders, state, fn {leader_id, leader}, acc ->
      if leader.position in all_combat_hexes do
        case Leader.death_check(leader) do
          :killed ->
            replacement = Leader.generate_replacement(leader)
            put_in(acc, [:leaders, leader_id], replacement)
          :survives ->
            acc
        end
      else
        acc
      end
    end)
  end

  defp update_unit(state, unit_id, update_fn) do
    case Map.get(state.units, unit_id) do
      nil -> state
      unit ->
        updated = update_fn.(unit)
        # Remove dead units
        if is_alive?(updated) do
          %{state | units: Map.put(state.units, unit_id, updated)}
        else
          %{state | units: Map.delete(state.units, unit_id)}
        end
    end
  end

  defp is_alive?(%UnitInstance{} = unit), do: UnitInstance.is_alive?(unit)
  defp is_alive?(unit), do: (unit.current_strength || 0) > 0
end
