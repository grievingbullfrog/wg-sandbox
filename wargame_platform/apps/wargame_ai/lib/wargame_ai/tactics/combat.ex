defmodule WargameAi.Tactics.Combat do
  @moduledoc """
  AI combat decision making.

  Enumerates possible attacks, calculates expected value for each,
  and greedily allocates attackers to targets.
  """

  alias WargameAi.Player
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Units.UnitInstance
  alias WargameCore.Hex.Coord
  alias WargameCore.Rules.StandardRules

  # Minimum odds the AI will accept for an attack
  @odds_thresholds %{
    aggressive: :"1:2",
    balanced: :"1:1",
    defensive: :"2:1"
  }

  @odds_ordering [:"1:4", :"1:3", :"1:2", :"2:3", :"1:1", :"3:2", :"2:1", :"3:1", :"4:1", :"5:1"]

  @doc """
  Plans attack actions for the AI's combat phase.

  Returns a list of `{:attack, [attacker_ids], target_coord}` tuples.
  Uses greedy allocation: picks the best attack first, removes used units,
  then evaluates remaining options.
  """
  @spec plan_attacks(map(), Player.config()) :: [tuple()]
  def plan_attacks(game_state, config) do
    side = config.side
    personality = Map.get(config, :personality, :balanced)
    difficulty = Map.get(config, :difficulty, :normal)
    min_odds = Map.get(@odds_thresholds, personality, :"1:1")

    # Find all attackable targets (enemy units adjacent to our units)
    targets = find_attack_targets(game_state, side)

    if Enum.empty?(targets) do
      []
    else
      # Greedily assign attacks
      available_units = available_attackers(game_state, side)
      greedy_allocate(game_state, targets, available_units, min_odds, difficulty, personality, [])
    end
  end

  @doc """
  Evaluates potential combat odds for an attack.

  Returns `{:ok, odds_info}` or `{:error, reason}`.
  """
  @spec evaluate_attack(map(), [String.t()], Coord.t()) :: {:ok, map()} | {:error, term()}
  def evaluate_attack(game_state, attacker_ids, target_coord) do
    StandardRules.calculate_combat_odds(game_state, attacker_ids, target_coord)
  end

  # --- Private ---

  defp find_attack_targets(game_state, side) do
    # Find all enemy units on the map
    enemy_positions =
      game_state.units
      |> Map.values()
      |> Enum.filter(&(&1.side != side and &1.position != nil and &1.current_strength > 0))
      |> Enum.map(& &1.position)
      |> Enum.uniq()

    # For each enemy position, find which of our units could attack it
    my_units =
      game_state.units
      |> Map.values()
      |> Enum.filter(&(&1.side == side and &1.position != nil and UnitInstance.can_attack?(&1)))

    Enum.flat_map(enemy_positions, fn target_pos ->
      # Find our units adjacent to this target
      adjacent_attackers =
        Enum.filter(my_units, fn unit ->
          dist = Coord.distance(unit.position, target_pos)
          dist <= unit.template.range
        end)

      if Enum.empty?(adjacent_attackers) do
        []
      else
        [%{target: target_pos, potential_attackers: Enum.map(adjacent_attackers, & &1.id)}]
      end
    end)
  end

  defp available_attackers(game_state, side) do
    game_state.units
    |> Map.values()
    |> Enum.filter(&(&1.side == side and &1.position != nil and UnitInstance.can_attack?(&1)))
    |> Map.new(&{&1.id, &1})
  end

  defp greedy_allocate(_game_state, [], _available, _min_odds, _difficulty, _personality, attacks) do
    Enum.reverse(attacks)
  end

  defp greedy_allocate(_game_state, _targets, available, _min_odds, _difficulty, _personality, attacks)
       when map_size(available) == 0 do
    Enum.reverse(attacks)
  end

  defp greedy_allocate(game_state, targets, available, min_odds, difficulty, personality, attacks) do
    # Score each possible attack (using all available attackers for each target)
    scored_attacks =
      targets
      |> Enum.map(fn target_info ->
        # Only use attackers still available
        valid_attackers =
          target_info.potential_attackers
          |> Enum.filter(&Map.has_key?(available, &1))

        if Enum.empty?(valid_attackers) do
          nil
        else
          case evaluate_attack(game_state, valid_attackers, target_info.target) do
            {:ok, odds_info} ->
              if odds_meet_threshold?(odds_info.final_odds, min_odds) do
                ev = expected_value(odds_info, game_state, target_info.target, personality)
                %{
                  target: target_info.target,
                  attacker_ids: valid_attackers,
                  odds: odds_info.final_odds,
                  expected_value: ev
                }
              else
                nil
              end

            {:error, _} ->
              nil
          end
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.expected_value, :desc)

    if Enum.empty?(scored_attacks) do
      Enum.reverse(attacks)
    else
      # Pick the best attack (with difficulty-based noise)
      scored_for_difficulty = Enum.map(scored_attacks, fn a -> {a, a.expected_value} end)
      best = Player.apply_difficulty(scored_for_difficulty, difficulty)

      if best == nil do
        Enum.reverse(attacks)
      else
        action = {:attack, best.attacker_ids, best.target}

        # Remove used attackers from available pool
        new_available = Map.drop(available, best.attacker_ids)

        # Remove this target from targets
        new_targets = Enum.reject(targets, &(&1.target == best.target))

        greedy_allocate(game_state, new_targets, new_available, min_odds, difficulty, personality, [action | attacks])
      end
    end
  end

  defp odds_meet_threshold?(actual_odds, minimum_odds) do
    actual_idx = Enum.find_index(@odds_ordering, &(&1 == actual_odds)) || 0
    min_idx = Enum.find_index(@odds_ordering, &(&1 == minimum_odds)) || 0
    actual_idx >= min_idx
  end

  defp expected_value(odds_info, game_state, target_coord, personality) do
    # Higher odds = better expected value
    odds_idx = Enum.find_index(@odds_ordering, &(&1 == odds_info.final_odds)) || 0
    base_ev = odds_idx * 10.0

    # Bonus for attacking VP hexes
    tile = GameMap.get_tile(game_state.map, target_coord)
    vp_bonus = if tile && tile.victory_points > 0, do: tile.victory_points * 15.0, else: 0.0

    # Aggressive personality gets bonus for any attack
    aggression_bonus = if personality == :aggressive, do: 10.0, else: 0.0

    # Penalty for high defense (harder to take)
    defense_penalty = odds_info.defense_strength * 0.5

    base_ev + vp_bonus + aggression_bonus - defense_penalty
  end
end
