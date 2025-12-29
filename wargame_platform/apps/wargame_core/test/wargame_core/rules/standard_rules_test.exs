defmodule WargameCore.Rules.StandardRulesTest do
  use ExUnit.Case, async: true

  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Rules.StandardRules
  alias WargameCore.Turns.Phase
  alias WargameCore.Turns.TurnState

  # Helper to create a unique game state for each test
  # Uses test PID to ensure uniqueness across parallel tests
  defp create_game_state(opts \\ []) do
    test_id = :erlang.phash2(self())
    map_name = "Test Map #{test_id}"

    map = GameMap.new(map_name, 10, 10, 200)

    phases =
      Keyword.get(opts, :phases, [
        Phase.new(:movement, "Movement", 0, allows_movement: true),
        Phase.new(:combat, "Combat", 1, allows_combat: true),
        Phase.new(:end, "End", 2)
      ])

    sides = Keyword.get(opts, :sides, [:german, :soviet])
    turn_state = TurnState.new(phases, sides)

    units = Keyword.get(opts, :units, %{})

    %{
      map: map,
      turn_state: turn_state,
      units: units,
      sides: sides,
      victory_conditions: Keyword.get(opts, :victory_conditions, %{})
    }
  end

  # Helper to create a unit with unique ID
  defp create_unit(opts \\ []) do
    test_id = :erlang.phash2(self())
    unit_id = Keyword.get(opts, :id, "unit_#{test_id}_#{:erlang.unique_integer([:positive])}")

    %{
      id: unit_id,
      side: Keyword.get(opts, :side, :german),
      position: Keyword.get(opts, :position, Coord.new(0, 0)),
      category: Keyword.get(opts, :category, :infantry),
      movement_points: Keyword.get(opts, :movement_points, 4),
      movement_remaining: Keyword.get(opts, :movement_remaining, 4),
      attack: Keyword.get(opts, :attack, 3),
      defense: Keyword.get(opts, :defense, 2),
      has_attacked: Keyword.get(opts, :has_attacked, false)
    }
  end

  describe "validate_movement/3" do
    test "returns :ok for valid single-step movement" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 4)
      state = create_game_state(units: %{unit.id => unit})
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert :ok = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns :ok for valid multi-step movement" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 4)
      state = create_game_state(units: %{unit.id => unit})
      path = [Coord.new(0, 0), Coord.new(1, 0), Coord.new(2, 0)]

      assert :ok = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error for non-existent unit" do
      state = create_game_state()
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:error, :unit_not_found} = StandardRules.validate_movement(state, "nonexistent", path)
    end

    test "returns error when not movement phase" do
      unit = create_unit()
      state = create_game_state(units: %{unit.id => unit})

      # Advance to combat phase
      {:ok, turn_state} = TurnState.advance_phase(state.turn_state)
      state = %{state | turn_state: turn_state}
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:error, :not_movement_phase} = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error when not unit's side's turn" do
      unit = create_unit(side: :soviet)
      state = create_game_state(units: %{unit.id => unit}, sides: [:german, :soviet])
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:error, :not_your_turn} = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error when no movement remaining" do
      unit = create_unit(movement_remaining: 0)
      state = create_game_state(units: %{unit.id => unit})
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:error, :no_movement_remaining} =
               StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error for disconnected path" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 10)
      state = create_game_state(units: %{unit.id => unit})
      # Skip a hex
      path = [Coord.new(0, 0), Coord.new(2, 0)]

      assert {:error, :path_not_connected} = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error for empty path" do
      unit = create_unit()
      state = create_game_state(units: %{unit.id => unit})

      assert {:error, :empty_path} = StandardRules.validate_movement(state, unit.id, [])
    end

    test "returns error when path crosses impassable terrain" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 10)
      state = create_game_state(units: %{unit.id => unit})

      # Set lake in path
      {:ok, map} = GameMap.set_terrain(state.map, Coord.new(1, 0), :freshwater_lake)
      state = %{state | map: map}

      path = [Coord.new(0, 0), Coord.new(1, 0), Coord.new(2, 0)]

      assert {:error, :path_blocked} = StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error when insufficient movement points" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 1)
      state = create_game_state(units: %{unit.id => unit})

      # Set forest which costs 2 for infantry
      {:ok, map} = GameMap.set_terrain(state.map, Coord.new(1, 0), :forest_pine)
      state = %{state | map: map}

      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:error, :insufficient_movement} =
               StandardRules.validate_movement(state, unit.id, path)
    end

    test "returns error when destination exceeds stacking" do
      # Create 3 units at destination (default limit)
      dest = Coord.new(1, 0)
      moving_unit = create_unit(position: Coord.new(0, 0))

      existing_units =
        for i <- 1..3, into: %{} do
          u = create_unit(position: dest, id: "stacked_#{i}_#{:erlang.phash2(self())}")
          {u.id, u}
        end

      units = Map.put(existing_units, moving_unit.id, moving_unit)
      state = create_game_state(units: units)

      path = [Coord.new(0, 0), dest]

      assert {:error, :destination_stacking_exceeded} =
               StandardRules.validate_movement(state, moving_unit.id, path)
    end
  end

  describe "execute_movement/3" do
    test "updates unit position" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 4)
      state = create_game_state(units: %{unit.id => unit})
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:ok, new_state} = StandardRules.execute_movement(state, unit.id, path)
      assert Coord.equal?(new_state.units[unit.id].position, Coord.new(1, 0))
    end

    test "deducts movement points" do
      unit = create_unit(position: Coord.new(0, 0), movement_remaining: 4)
      state = create_game_state(units: %{unit.id => unit})
      path = [Coord.new(0, 0), Coord.new(1, 0)]

      assert {:ok, new_state} = StandardRules.execute_movement(state, unit.id, path)
      # Clear terrain costs 1
      assert new_state.units[unit.id].movement_remaining == 3
    end
  end

  describe "validate_attack/3" do
    test "returns :ok for valid attack" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0))
      defender = create_unit(side: :soviet, position: Coord.new(1, 0))
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert :ok = StandardRules.validate_attack(state, [attacker.id], Coord.new(1, 0))
    end

    test "returns error when not combat phase" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0))
      defender = create_unit(side: :soviet, position: Coord.new(1, 0))
      units = %{attacker.id => attacker, defender.id => defender}
      state = create_game_state(units: units)

      assert {:error, :not_combat_phase} =
               StandardRules.validate_attack(state, [attacker.id], Coord.new(1, 0))
    end

    test "returns error for non-existent attacker" do
      defender = create_unit(side: :soviet, position: Coord.new(1, 0))

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: %{defender.id => defender}, phases: phases)

      assert {:error, :attacker_not_found} =
               StandardRules.validate_attack(state, ["nonexistent"], Coord.new(1, 0))
    end

    test "returns error when no enemy at target" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0))

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: %{attacker.id => attacker}, phases: phases)

      assert {:error, :no_enemy_at_target} =
               StandardRules.validate_attack(state, [attacker.id], Coord.new(1, 0))
    end

    test "returns error when attacker not adjacent" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0))
      defender = create_unit(side: :soviet, position: Coord.new(2, 0))
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert {:error, :attacker_not_adjacent} =
               StandardRules.validate_attack(state, [attacker.id], Coord.new(2, 0))
    end

    test "returns error when attacker already attacked" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0), has_attacked: true)
      defender = create_unit(side: :soviet, position: Coord.new(1, 0))
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert {:error, :already_attacked} =
               StandardRules.validate_attack(state, [attacker.id], Coord.new(1, 0))
    end
  end

  describe "calculate_combat_odds/3" do
    test "calculates basic odds correctly" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0), attack: 6)
      defender = create_unit(side: :soviet, position: Coord.new(1, 0), defense: 3)
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert {:ok, odds} =
               StandardRules.calculate_combat_odds(state, [attacker.id], Coord.new(1, 0))

      assert odds.attack_strength == 6
      assert odds.defense_strength == 3
      assert odds.final_odds == :"2:1"
    end

    test "applies terrain defense modifier" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0), attack: 6)
      defender = create_unit(side: :soviet, position: Coord.new(1, 0), defense: 3)
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      # Set urban terrain (defense +3)
      {:ok, map} = GameMap.set_terrain(state.map, Coord.new(1, 0), :heavy_urban)
      state = %{state | map: map}

      assert {:ok, odds} =
               StandardRules.calculate_combat_odds(state, [attacker.id], Coord.new(1, 0))

      assert odds.terrain_modifier == 3
      assert odds.modified_defense == 6
    end

    test "combines multiple attackers" do
      attacker1 = create_unit(side: :german, position: Coord.new(0, 0), attack: 3)
      attacker2 = create_unit(side: :german, position: Coord.new(1, 1), attack: 3)
      defender = create_unit(side: :soviet, position: Coord.new(1, 0), defense: 3)
      units = %{attacker1.id => attacker1, attacker2.id => attacker2, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert {:ok, odds} =
               StandardRules.calculate_combat_odds(
                 state,
                 [attacker1.id, attacker2.id],
                 Coord.new(1, 0)
               )

      assert odds.attack_strength == 6
    end
  end

  describe "resolve_attack/3" do
    test "returns updated game state" do
      attacker = create_unit(side: :german, position: Coord.new(0, 0), attack: 6)
      defender = create_unit(side: :soviet, position: Coord.new(1, 0), defense: 3)
      units = %{attacker.id => attacker, defender.id => defender}

      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(units: units, phases: phases)

      assert {:ok, _new_state} =
               StandardRules.resolve_attack(state, [attacker.id], Coord.new(1, 0))
    end
  end

  describe "validate_phase_action/2" do
    test "allows movement during movement phase" do
      state = create_game_state()
      assert :ok = StandardRules.validate_phase_action(state, :move)
    end

    test "rejects movement during combat phase" do
      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(phases: phases)

      assert {:error, :movement_not_allowed} =
               StandardRules.validate_phase_action(state, :move)
    end

    test "allows combat during combat phase" do
      phases = [
        Phase.new(:combat, "Combat", 0, allows_combat: true),
        Phase.new(:end, "End", 1)
      ]

      state = create_game_state(phases: phases)
      assert :ok = StandardRules.validate_phase_action(state, :attack)
    end

    test "rejects combat during movement phase" do
      state = create_game_state()
      assert {:error, :combat_not_allowed} = StandardRules.validate_phase_action(state, :attack)
    end
  end

  describe "movement_cost/4" do
    test "returns terrain movement cost" do
      unit = create_unit(category: :infantry)
      state = create_game_state(units: %{unit.id => unit})

      cost = StandardRules.movement_cost(state, unit.id, Coord.new(1, 0), nil)
      assert cost == 1
    end

    test "returns :impassable for impassable terrain" do
      unit = create_unit(category: :infantry)
      state = create_game_state(units: %{unit.id => unit})

      {:ok, map} = GameMap.set_terrain(state.map, Coord.new(1, 0), :freshwater_lake)
      state = %{state | map: map}

      cost = StandardRules.movement_cost(state, unit.id, Coord.new(1, 0), nil)
      assert cost == :impassable
    end

    test "returns :impassable for nonexistent unit" do
      state = create_game_state()
      cost = StandardRules.movement_cost(state, "nonexistent", Coord.new(1, 0), nil)
      assert cost == :impassable
    end
  end

  describe "has_line_of_sight?/3" do
    test "returns true when clear LOS" do
      unit = create_unit(position: Coord.new(0, 0))
      state = create_game_state(units: %{unit.id => unit})

      assert StandardRules.has_line_of_sight?(state, unit.id, Coord.new(3, 0))
    end

    test "returns false when blocked" do
      unit = create_unit(position: Coord.new(0, 0))
      state = create_game_state(units: %{unit.id => unit})

      # Add blocking terrain
      {:ok, map} = GameMap.set_terrain(state.map, Coord.new(1, 0), :forest_pine)
      state = %{state | map: map}

      refute StandardRules.has_line_of_sight?(state, unit.id, Coord.new(3, 0))
    end

    test "returns false for nonexistent unit" do
      state = create_game_state()
      refute StandardRules.has_line_of_sight?(state, "nonexistent", Coord.new(3, 0))
    end
  end

  describe "stacking_limit/3" do
    test "returns default stacking limit" do
      state = create_game_state()
      limit = StandardRules.stacking_limit(state, Coord.new(0, 0), :german)
      assert limit == 3
    end
  end

  describe "validate_stacking/3" do
    test "returns :ok when under limit" do
      units =
        for i <- 1..2, into: %{} do
          u = create_unit(position: Coord.new(0, 0), id: "stacked_#{i}_#{:erlang.phash2(self())}")
          {u.id, u}
        end

      state = create_game_state(units: units)

      assert :ok = StandardRules.validate_stacking(state, Coord.new(0, 0), :german)
    end

    test "returns :ok at exactly limit" do
      units =
        for i <- 1..3, into: %{} do
          u = create_unit(position: Coord.new(0, 0), id: "stacked_#{i}_#{:erlang.phash2(self())}")
          {u.id, u}
        end

      state = create_game_state(units: units)

      assert :ok = StandardRules.validate_stacking(state, Coord.new(0, 0), :german)
    end

    test "returns error when over limit" do
      units =
        for i <- 1..4, into: %{} do
          u = create_unit(position: Coord.new(0, 0), id: "stacked_#{i}_#{:erlang.phash2(self())}")
          {u.id, u}
        end

      state = create_game_state(units: units)

      assert {:error, :stacking_exceeded} =
               StandardRules.validate_stacking(state, Coord.new(0, 0), :german)
    end
  end

  describe "on_turn_start/2" do
    test "resets movement points for all units" do
      unit = create_unit(movement_points: 4, movement_remaining: 0)
      state = create_game_state(units: %{unit.id => unit})

      new_state = StandardRules.on_turn_start(state, 1)

      assert new_state.units[unit.id].movement_remaining == 4
    end

    test "resets has_attacked flag" do
      unit = create_unit(has_attacked: true)
      state = create_game_state(units: %{unit.id => unit})

      new_state = StandardRules.on_turn_start(state, 1)

      refute new_state.units[unit.id].has_attacked
    end
  end

  describe "check_victory/1" do
    test "returns ongoing when no conditions met" do
      state = create_game_state()

      assert {:ongoing, scores} = StandardRules.check_victory(state)
      assert is_map(scores)
    end

    test "returns victory on sudden death threshold" do
      state = create_game_state(victory_conditions: %{sudden_death_vp: 10})

      # Set controlled tile with 10 VP
      {:ok, map} =
        GameMap.update_tile(state.map, Coord.new(0, 0), fn tile ->
          %{tile | control: :german, victory_points: 10}
        end)

      state = %{state | map: map}

      assert {:victory, :german, _reason} = StandardRules.check_victory(state)
    end
  end
end
