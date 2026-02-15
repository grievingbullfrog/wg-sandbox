defmodule WargameCore.Rules.StandardRules do
  @moduledoc """
  Standard wargame rules implementation.

  Provides a default implementation of the RulesEngine behaviour
  that can be used directly or as a base for scenario-specific rules.

  ## Rule Highlights

  - **Movement**: Terrain-based costs, road bonuses, enemy ZOC effects
  - **Combat**: Odds-based CRT, terrain modifiers, combined arms bonuses
  - **Stacking**: Configurable per-hex limits by unit type
  - **Victory**: Control of victory point hexes
  """

  @behaviour WargameCore.Rules.RulesEngine

  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.TurnState
  alias WargameCore.Units.{UnitInstance, UnitTemplate}

  # Default stacking limit (units per hex)
  @default_stacking_limit 3

  # Combined arms bonus when both infantry and armor categories attack together
  @combined_arms_bonus 2

  @impl true
  def validate_movement(game_state, unit_id, path) do
    with {:ok, unit} <- get_unit(game_state, unit_id),
         :ok <- validate_unit_can_move(game_state, unit),
         :ok <- validate_path_connected(path),
         :ok <- validate_movement_points(game_state, unit, path),
         :ok <- validate_path_traversable(game_state, unit, path),
         :ok <- validate_destination_stacking(game_state, unit, path) do
      :ok
    end
  end

  @impl true
  def execute_movement(game_state, unit_id, path) do
    destination = List.last(path)

    units =
      game_state.units
      |> Map.update!(unit_id, fn unit ->
        movement_spent = calculate_path_cost(game_state, unit, path)

        %{
          unit
          | position: destination,
            movement_remaining: unit.movement_remaining - movement_spent
        }
      end)

    {:ok, %{game_state | units: units}}
  end

  @impl true
  def validate_attack(game_state, attacker_ids, target_coord) do
    with :ok <- validate_attackers_exist(game_state, attacker_ids),
         :ok <- validate_combat_phase(game_state),
         :ok <- validate_target_has_enemy(game_state, attacker_ids, target_coord),
         :ok <- validate_attackers_adjacent(game_state, attacker_ids, target_coord),
         :ok <- validate_attackers_can_attack(game_state, attacker_ids) do
      :ok
    end
  end

  @impl true
  def resolve_attack(game_state, attacker_ids, target_coord) do
    with {:ok, odds_info} <- calculate_combat_odds(game_state, attacker_ids, target_coord) do
      # Roll for result
      roll = :rand.uniform(6) + :rand.uniform(6)

      # Look up result on CRT
      result = lookup_crt_result(odds_info.final_odds, roll)

      # Apply result
      apply_combat_result(game_state, attacker_ids, target_coord, result, odds_info)
    end
  end

  @impl true
  def check_victory(game_state) do
    scores =
      Enum.reduce(game_state.sides, %{}, fn side, acc ->
        vp = WargameCore.Map.victory_points_for(game_state.map, side)
        Map.put(acc, side, vp)
      end)

    victory_conditions = Map.get(game_state, :victory_conditions, %{})
    sudden_death_threshold = Map.get(victory_conditions, :sudden_death_vp, nil)
    turn_limit = Map.get(victory_conditions, :turn_limit, nil)

    cond do
      # Sudden death victory
      sudden_death_threshold != nil and Enum.any?(scores, fn {_side, vp} -> vp >= sudden_death_threshold end) ->
        {winner, _vp} = Enum.max_by(scores, fn {_side, vp} -> vp end)
        {:victory, winner, "Achieved sudden death victory threshold"}

      # Turn limit reached - check who has more VPs
      turn_limit != nil and game_state.turn_state.turn_number > turn_limit ->
        case determine_winner(scores) do
          {:winner, side} ->
            {:victory, side, "Victory points at end of game"}

          :draw ->
            {:draw, "Equal victory points at end of game"}
        end

      # Game continues
      true ->
        {:ongoing, scores}
    end
  end

  @impl true
  def validate_phase_action(game_state, action_type) do
    turn_state = game_state.turn_state

    case action_type do
      :move ->
        if TurnState.can_move?(turn_state), do: :ok, else: {:error, :movement_not_allowed}

      :attack ->
        if TurnState.can_attack?(turn_state), do: :ok, else: {:error, :combat_not_allowed}

      :order ->
        if TurnState.can_order?(turn_state), do: :ok, else: {:error, :orders_not_allowed}

      _ ->
        :ok
    end
  end

  @impl true
  def movement_cost(game_state, unit_id, to_coord, from_coord) do
    case get_unit(game_state, unit_id) do
      {:ok, unit} ->
        tile = WargameCore.Map.get_tile(game_state.map, to_coord)

        if tile do
          direction =
            if from_coord, do: Coord.direction_to(from_coord, to_coord), else: nil

          category = unit_category(unit)
          Tile.movement_cost(tile, category, direction)
        else
          :impassable
        end

      {:error, _} ->
        :impassable
    end
  end

  @impl true
  def calculate_combat_odds(game_state, attacker_ids, target_coord) do
    with {:ok, attackers} <- get_units(game_state, attacker_ids),
         {:ok, defenders} <- get_units_at(game_state, target_coord) do
      # Determine if defenders are hard targets (have armor)
      defenders_are_hard = Enum.any?(defenders, &is_hard_target?/1)

      # Sum attack strengths (soft or hard based on defender type)
      base_attack_strength =
        Enum.reduce(attackers, 0, fn unit, acc ->
          acc + get_attack_strength(unit, defenders_are_hard)
        end)

      # Combined arms bonus: infantry + armor attacking together
      combined_arms = combined_arms_bonus(attackers)

      # Leader modifier bonus
      leader_attack_bonus = leader_bonus(game_state, attackers, :attack)

      attack_strength = base_attack_strength + combined_arms + leader_attack_bonus

      # Sum defense strengths
      base_defense_strength =
        Enum.reduce(defenders, 0, fn unit, acc ->
          acc + get_defense_strength(unit)
        end)

      leader_defense_bonus = leader_bonus(game_state, defenders, :defense)
      defense_strength = base_defense_strength + leader_defense_bonus

      # Get terrain modifier
      target_tile = WargameCore.Map.get_tile(game_state.map, target_coord)
      terrain_modifier = if target_tile, do: Tile.defense_modifier(target_tile), else: 0

      # Apply terrain modifier to defense
      modified_defense = defense_strength + terrain_modifier

      # Calculate odds ratio
      raw_odds = attack_strength / max(modified_defense, 1)

      # Convert to standard odds column
      final_odds = round_to_odds_column(raw_odds)

      {:ok,
       %{
         attack_strength: attack_strength,
         defense_strength: defense_strength,
         terrain_modifier: terrain_modifier,
         modified_defense: modified_defense,
         raw_odds: raw_odds,
         final_odds: final_odds,
         combined_arms: combined_arms,
         leader_attack_bonus: leader_attack_bonus,
         leader_defense_bonus: leader_defense_bonus
       }}
    end
  end

  @impl true
  def has_line_of_sight?(game_state, unit_id, target_coord) do
    case get_unit(game_state, unit_id) do
      {:ok, unit} ->
        WargameCore.Map.has_line_of_sight?(game_state.map, unit.position, target_coord)

      {:error, _} ->
        false
    end
  end

  @impl true
  def stacking_limit(_game_state, _coord, _side) do
    @default_stacking_limit
  end

  @impl true
  def validate_stacking(game_state, coord, side) do
    units_at_coord =
      game_state.units
      |> Map.values()
      |> Enum.filter(fn unit -> unit.position == coord and unit.side == side end)
      |> length()

    limit = stacking_limit(game_state, coord, side)

    if units_at_coord <= limit do
      :ok
    else
      {:error, :stacking_exceeded}
    end
  end

  @impl true
  def on_turn_start(game_state, _turn_number) do
    # Reset movement points for all units
    units =
      game_state.units
      |> Map.new(fn {id, unit} ->
        {id, reset_unit_turn(unit)}
      end)

    %{game_state | units: units}
  end

  @impl true
  def on_turn_end(game_state, _turn_number) do
    # Could handle supply checks, reinforcements, etc.
    game_state
  end

  @impl true
  def on_phase_start(game_state, _phase_id) do
    game_state
  end

  @impl true
  def on_phase_end(game_state, _phase_id) do
    game_state
  end

  # Private helper functions

  defp get_unit(game_state, unit_id) do
    case Map.get(game_state.units, unit_id) do
      nil -> {:error, :unit_not_found}
      unit -> {:ok, unit}
    end
  end

  defp get_units(game_state, unit_ids) do
    units =
      Enum.reduce_while(unit_ids, [], fn id, acc ->
        case get_unit(game_state, id) do
          {:ok, unit} -> {:cont, [unit | acc]}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case units do
      {:error, _} = error -> error
      list -> {:ok, Enum.reverse(list)}
    end
  end

  defp get_units_at(game_state, coord) do
    units =
      game_state.units
      |> Map.values()
      |> Enum.filter(fn unit -> unit.position == coord end)

    if Enum.empty?(units) do
      {:error, :no_units_at_location}
    else
      {:ok, units}
    end
  end

  defp validate_unit_can_move(game_state, unit) do
    cond do
      not TurnState.can_move?(game_state.turn_state) ->
        {:error, :not_movement_phase}

      not TurnState.is_active_side?(game_state.turn_state, unit.side) ->
        {:error, :not_your_turn}

      unit.movement_remaining <= 0 ->
        {:error, :no_movement_remaining}

      true ->
        :ok
    end
  end

  defp validate_path_connected([_single]), do: :ok

  defp validate_path_connected([from, to | rest]) do
    if Coord.distance(from, to) == 1 do
      validate_path_connected([to | rest])
    else
      {:error, :path_not_connected}
    end
  end

  defp validate_path_connected([]), do: {:error, :empty_path}

  defp validate_movement_points(game_state, unit, path) do
    cost = calculate_path_cost(game_state, unit, path)

    cond do
      cost == :impassable -> {:error, :path_blocked}
      cost <= unit.movement_remaining -> :ok
      true -> {:error, :insufficient_movement}
    end
  end

  defp validate_path_traversable(game_state, unit, path) do
    # Check each step of the path
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce_while(:ok, fn [from, to], _acc ->
      cost = movement_cost(game_state, unit.id, to, from)

      if cost == :impassable do
        {:halt, {:error, :path_blocked}}
      else
        {:cont, :ok}
      end
    end)
  end

  defp validate_destination_stacking(game_state, unit, path) do
    destination = List.last(path)

    # Temporarily add unit to destination to check stacking
    current_units =
      game_state.units
      |> Map.values()
      |> Enum.filter(fn u -> u.position == destination and u.side == unit.side and u.id != unit.id end)
      |> length()

    limit = stacking_limit(game_state, destination, unit.side)

    if current_units + 1 <= limit do
      :ok
    else
      {:error, :destination_stacking_exceeded}
    end
  end

  defp calculate_path_cost(game_state, unit, path) do
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce_while(0, fn [from, to], acc ->
      cost = movement_cost(game_state, unit.id, to, from)

      if cost == :impassable do
        {:halt, :impassable}
      else
        {:cont, acc + cost}
      end
    end)
  end

  defp validate_attackers_exist(game_state, attacker_ids) do
    if Enum.all?(attacker_ids, &Map.has_key?(game_state.units, &1)) do
      :ok
    else
      {:error, :attacker_not_found}
    end
  end

  defp validate_combat_phase(game_state) do
    if TurnState.can_attack?(game_state.turn_state) do
      :ok
    else
      {:error, :not_combat_phase}
    end
  end

  defp validate_target_has_enemy(game_state, attacker_ids, target_coord) do
    {:ok, attackers} = get_units(game_state, attacker_ids)
    attacker_side = hd(attackers).side

    defenders =
      game_state.units
      |> Map.values()
      |> Enum.filter(fn unit -> unit.position == target_coord and unit.side != attacker_side end)

    if Enum.empty?(defenders) do
      {:error, :no_enemy_at_target}
    else
      :ok
    end
  end

  defp validate_attackers_adjacent(game_state, attacker_ids, target_coord) do
    {:ok, attackers} = get_units(game_state, attacker_ids)

    all_adjacent =
      Enum.all?(attackers, fn unit ->
        Coord.distance(unit.position, target_coord) == 1
      end)

    if all_adjacent do
      :ok
    else
      {:error, :attacker_not_adjacent}
    end
  end

  defp validate_attackers_can_attack(game_state, attacker_ids) do
    {:ok, attackers} = get_units(game_state, attacker_ids)
    active_side = TurnState.active_side(game_state.turn_state)

    cond do
      Enum.any?(attackers, fn unit -> unit.side != active_side end) ->
        {:error, :not_your_turn}

      Enum.any?(attackers, fn unit -> unit.has_attacked end) ->
        {:error, :already_attacked}

      true ->
        :ok
    end
  end

  # Attack strength: for UnitInstance, use soft/hard based on defender armor
  defp get_attack_strength(%UnitInstance{} = unit, true = _defenders_are_hard) do
    UnitInstance.effective_attack_hard(unit) + UnitInstance.attachment_bonus(unit, :attack_hard)
  end

  defp get_attack_strength(%UnitInstance{} = unit, false = _defenders_are_hard) do
    UnitInstance.effective_attack_soft(unit) + UnitInstance.attachment_bonus(unit, :attack_soft)
  end

  # Plain map fallback for backward compatibility
  defp get_attack_strength(unit, _defenders_are_hard), do: Map.get(unit, :attack, 1)

  # Defense strength: for UnitInstance, use effective_defense
  defp get_defense_strength(%UnitInstance{} = unit) do
    UnitInstance.effective_defense(unit) + UnitInstance.attachment_bonus(unit, :defense)
  end

  defp get_defense_strength(unit), do: Map.get(unit, :defense, 1)

  # Check if a unit is a hard target (has armor)
  defp is_hard_target?(%UnitInstance{template: template}), do: UnitTemplate.is_hard_target?(template)
  defp is_hard_target?(unit), do: Map.get(unit, :armor, 0) > 0

  # Extract unit category for terrain movement costs
  defp unit_category(%UnitInstance{template: template}), do: UnitTemplate.terrain_category(template)
  defp unit_category(unit), do: Map.get(unit, :category, :infantry)

  # Combined arms: bonus when both infantry-type and armor-type categories attack
  defp combined_arms_bonus(attackers) do
    categories = Enum.map(attackers, fn
      %UnitInstance{template: t} -> t.category
      unit -> Map.get(unit, :category, :infantry)
    end) |> Enum.uniq()

    has_infantry = Enum.any?(categories, &(&1 in [:infantry, :motorized, :engineer]))
    has_armor = Enum.any?(categories, &(&1 in [:armor]))

    if has_infantry and has_armor, do: @combined_arms_bonus, else: 0
  end

  # Leader modifier bonus: sum leader attack/defense bonuses for units with leaders in range
  defp leader_bonus(game_state, units, stat_type) do
    leaders = Map.get(game_state, :leaders, %{}) |> Map.values()

    if Enum.empty?(leaders) do
      0
    else
      Enum.reduce(units, 0, fn unit, acc ->
        pos = unit.position

        best_leader_bonus =
          leaders
          |> Enum.filter(fn leader -> leader.side == unit.side end)
          |> Enum.map(fn leader ->
            if WargameCore.Units.Leader.in_command_radius?(leader, pos) do
              case stat_type do
                :attack -> leader.attack_modifier
                :defense -> leader.defense_modifier
              end
            else
              0
            end
          end)
          |> Enum.max(fn -> 0 end)

        acc + best_leader_bonus
      end)
    end
  end

  # Reset unit turn state - handles both UnitInstance and plain maps
  defp reset_unit_turn(%UnitInstance{} = unit), do: UnitInstance.reset_turn_state(unit)
  defp reset_unit_turn(unit), do: %{unit | movement_remaining: unit.movement_points, has_attacked: false}

  defp round_to_odds_column(raw_odds) do
    # Standard CRT odds columns
    cond do
      raw_odds >= 5 -> :"5:1"
      raw_odds >= 4 -> :"4:1"
      raw_odds >= 3 -> :"3:1"
      raw_odds >= 2 -> :"2:1"
      raw_odds >= 1.5 -> :"3:2"
      raw_odds >= 1 -> :"1:1"
      raw_odds >= 0.67 -> :"2:3"
      raw_odds >= 0.5 -> :"1:2"
      raw_odds >= 0.33 -> :"1:3"
      true -> :"1:4"
    end
  end

  defp lookup_crt_result(odds, roll) do
    # Standard Combat Results Table
    # Results: :ae (attacker eliminated), :ar (attacker retreat), :ex (exchange),
    #          :dr (defender retreat), :de (defender eliminated)

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

  defp apply_combat_result(game_state, _attacker_ids, _target_coord, result, _odds_info) do
    # Simplified result application
    case result do
      :ae ->
        # Attacker eliminated - would remove attacker units
        {:ok, game_state}

      :ar ->
        # Attacker retreat - would move attackers back
        {:ok, game_state}

      :ex ->
        # Exchange - both sides lose units
        {:ok, game_state}

      :dr ->
        # Defender retreat - would move defenders
        {:ok, game_state}

      :de ->
        # Defender eliminated - would remove defender units
        {:ok, game_state}
    end
  end

  defp determine_winner(scores) do
    sorted = Enum.sort_by(scores, fn {_side, vp} -> vp end, :desc)

    case sorted do
      [{side1, vp1}, {_side2, vp2} | _] when vp1 > vp2 ->
        {:winner, side1}

      _ ->
        :draw
    end
  end
end
