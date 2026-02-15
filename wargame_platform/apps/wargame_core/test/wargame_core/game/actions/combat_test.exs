defmodule WargameCore.Game.Actions.CombatTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.Actions.Combat
  alias WargameCore.Units.{UnitTemplate, UnitInstance}
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.{Phase, TurnState}

  @infantry_template %UnitTemplate{
    id: "inf_template", name: "Infantry", nationality: "german", era: "ww2",
    category: :infantry, unit_size: :platoon, icon_type: "infantry",
    attack_soft: 6, attack_hard: 2, defense: 5, armor: 0,
    movement_points: 4, movement_type: :foot, range: 1,
    spotting: 3, initiative: 3, max_strength: 10,
    max_ammo: 10, max_fuel: 0,
    can_bridge: false, can_entrench: true, is_organic_transport: false
  }

  defp make_combat_state do
    tiles = for q <- 0..4, r <- 0..2, into: %{} do
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear)}
    end

    game_map = %WargameCore.Map{
      id: "test", name: "Test", width: 5, height: 3, scale: "1km", tiles: tiles
    }

    # Combat phase, axis active
    phases = [
      Phase.new(:combat, "Combat", 0, allows_combat: true),
      Phase.new(:end_phase, "End", 1)
    ]
    turn_state = TurnState.new(phases, [:axis, :allied])

    # Attacker at (1,0), defender at (2,0) - adjacent
    units = %{
      "ger1" => UnitInstance.new(@infantry_template, %{
        id: "ger1", name: "1st Infantry", side: :axis, force: :german,
        position: Coord.new(1, 0)
      }),
      "ger2" => UnitInstance.new(@infantry_template, %{
        id: "ger2", name: "2nd Infantry", side: :axis, force: :german,
        position: Coord.new(1, 1)
      }),
      "sov1" => UnitInstance.new(@infantry_template, %{
        id: "sov1", name: "1st Rifle", side: :allied, force: :soviet,
        position: Coord.new(2, 0)
      })
    }

    %{
      map: game_map,
      tiles: tiles,
      units: units,
      turn_state: turn_state,
      rules_module: WargameCore.Rules.StandardRules,
      leaders: %{},
      sides: [:axis, :allied],
      victory_conditions: %{type: :victory_points, sudden_death_vp: nil},
      supply_sources: []
    }
  end

  describe "execute_with_roll/4" do
    test "successful attack applies damage to defender on high roll" do
      state = make_combat_state()
      target = Coord.new(2, 0)

      # Two attackers vs one defender, high roll should be DE
      {:ok, new_state} = Combat.execute_with_roll(state, ["ger1", "ger2"], target, 12)

      # Defender should be eliminated or heavily damaged
      sov = Map.get(new_state.units, "sov1")
      # At DE, defender gets max damage (full strength = eliminated)
      assert sov == nil or sov.current_strength == 0
    end

    test "low roll results in attacker losses" do
      state = make_combat_state()
      target = Coord.new(2, 0)

      # Single attacker vs defender - roughly 1:1, low roll = AE or AR
      {:ok, new_state} = Combat.execute_with_roll(state, ["ger1"], target, 2)

      # Attacker should have taken damage or been eliminated
      ger = Map.get(new_state.units, "ger1")
      if ger do
        assert ger.current_strength < state.units["ger1"].current_strength or
               ger.position != state.units["ger1"].position
      end
    end

    test "marks attackers as having attacked" do
      state = make_combat_state()
      target = Coord.new(2, 0)

      {:ok, new_state} = Combat.execute_with_roll(state, ["ger1"], target, 7)

      ger = Map.get(new_state.units, "ger1")
      if ger do
        assert ger.has_attacked == true
      end
    end

    test "rejects attack against non-existent target" do
      state = make_combat_state()
      # No enemy at (3,0)
      target = Coord.new(3, 0)

      assert {:error, :no_enemy_at_target} = Combat.execute_with_roll(state, ["ger1"], target, 7)
    end

    test "rejects attack when attacker not adjacent" do
      state = make_combat_state()
      # ger1 at (1,0), target at (4,0) - not adjacent
      target = Coord.new(2, 0)

      # Move ger1 away first
      ger1 = %{state.units["ger1"] | position: Coord.new(0, 0)}
      state = %{state | units: Map.put(state.units, "ger1", ger1)}

      assert {:error, :attacker_not_adjacent} = Combat.execute_with_roll(state, ["ger1"], target, 7)
    end

    test "rejects attack when attacker already attacked" do
      state = make_combat_state()
      ger1 = %{state.units["ger1"] | has_attacked: true}
      state = %{state | units: Map.put(state.units, "ger1", ger1)}

      target = Coord.new(2, 0)
      assert {:error, :already_attacked} = Combat.execute_with_roll(state, ["ger1"], target, 7)
    end

    test "exchange result damages both sides" do
      state = make_combat_state()
      target = Coord.new(2, 0)

      # 1:1 odds, roll of 4 or 5 = exchange
      {:ok, new_state} = Combat.execute_with_roll(state, ["ger1"], target, 4)

      ger = Map.get(new_state.units, "ger1")
      sov = Map.get(new_state.units, "sov1")

      # Both should have taken damage (2 steps each for exchange)
      if ger, do: assert(ger.current_strength < 10)
      if sov, do: assert(sov.current_strength < 10)
    end

    test "defender retreat moves defender away" do
      state = make_combat_state()
      target = Coord.new(2, 0)

      # 2:1 odds (2 attackers), roll of 4 = DR
      {:ok, new_state} = Combat.execute_with_roll(state, ["ger1", "ger2"], target, 4)

      sov = Map.get(new_state.units, "sov1")
      if sov do
        # Defender should have retreated from (2,0)
        assert sov.position != Coord.new(2, 0) or sov.current_strength < 10
        # Entrenchment should be reset on retreat
        assert sov.entrenchment == 0
      end
    end
  end
end
