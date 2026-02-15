defmodule WargameCore.Game.Actions.MoveTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.Actions.Move
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.{Phase, TurnState}

  @infantry_template %UnitTemplate{
    id: "inf_template",
    name: "Infantry",
    nationality: "german",
    era: "ww2",
    category: :infantry,
    unit_size: :platoon,
    icon_type: "infantry",
    attack_soft: 6, attack_hard: 2, defense: 5, armor: 0,
    movement_points: 4, movement_type: :foot, range: 1,
    spotting: 3, initiative: 3, max_strength: 10,
    max_ammo: 10, max_fuel: 0,
    can_bridge: false, can_entrench: true, is_organic_transport: false
  }

  defp make_game_state do
    tiles = for q <- 0..4, r <- 0..2, into: %{} do
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear)}
    end

    game_map = %WargameCore.Map{
      id: "test", name: "Test", width: 5, height: 3, scale: "1km", tiles: tiles
    }

    # Movement phase, axis active
    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true),
      Phase.new(:end_phase, "End", 2)
    ]
    turn_state = TurnState.new(phases, [:axis, :allied])

    units = %{
      "ger1" => WargameCore.Units.UnitInstance.new(@infantry_template, %{
        id: "ger1", name: "1st Infantry", side: :axis, force: :german,
        position: Coord.new(0, 0)
      }),
      "ger2" => WargameCore.Units.UnitInstance.new(@infantry_template, %{
        id: "ger2", name: "2nd Infantry", side: :axis, force: :german,
        position: Coord.new(1, 0)
      }),
      "sov1" => WargameCore.Units.UnitInstance.new(@infantry_template, %{
        id: "sov1", name: "1st Rifle", side: :allied, force: :soviet,
        position: Coord.new(4, 0)
      })
    }

    %{
      map: game_map,
      tiles: tiles,
      units: units,
      turn_state: turn_state,
      rules_module: WargameCore.Rules.StandardRules,
      leaders: %{},
      sides: [:axis, :allied]
    }
  end

  describe "execute/3" do
    test "moves a unit to an adjacent hex" do
      state = make_game_state()
      path = [Coord.new(0, 0), Coord.new(0, 1)]

      assert {:ok, new_state} = Move.execute(state, "ger1", path)
      assert new_state.units["ger1"].position == Coord.new(0, 1)
    end

    test "deducts movement points" do
      state = make_game_state()
      path = [Coord.new(0, 0), Coord.new(0, 1)]

      {:ok, new_state} = Move.execute(state, "ger1", path)
      assert new_state.units["ger1"].movement_remaining < state.units["ger1"].movement_remaining
    end

    test "moves along multi-step path" do
      state = make_game_state()
      path = [Coord.new(0, 0), Coord.new(0, 1), Coord.new(1, 1)]

      {:ok, new_state} = Move.execute(state, "ger1", path)
      assert new_state.units["ger1"].position == Coord.new(1, 1)
    end

    test "rejects movement of non-existent unit" do
      state = make_game_state()
      path = [Coord.new(0, 0), Coord.new(0, 1)]

      assert {:error, :unit_not_found} = Move.execute(state, "nonexistent", path)
    end

    test "rejects movement when unit has no movement remaining" do
      state = make_game_state()
      unit = %{state.units["ger1"] | movement_remaining: 0}
      state = %{state | units: Map.put(state.units, "ger1", unit)}
      path = [Coord.new(0, 0), Coord.new(0, 1)]

      assert {:error, :no_movement_remaining} = Move.execute(state, "ger1", path)
    end

    test "rejects movement past stacking limit" do
      state = make_game_state()
      # Put 3 units at (0,1) already
      extra_units = for i <- 1..3, into: %{} do
        {"extra#{i}", WargameCore.Units.UnitInstance.new(@infantry_template, %{
          id: "extra#{i}", name: "Extra #{i}", side: :axis, force: :german,
          position: Coord.new(0, 1)
        })}
      end
      state = %{state | units: Map.merge(state.units, extra_units)}

      path = [Coord.new(0, 0), Coord.new(0, 1)]
      assert {:error, :destination_stacking_exceeded} = Move.execute(state, "ger1", path)
    end
  end

  describe "hold/2" do
    test "sets movement remaining to 0" do
      state = make_game_state()

      {:ok, new_state} = Move.hold(state, "ger1")
      assert new_state.units["ger1"].movement_remaining == 0
    end

    test "increases entrenchment for units that can entrench" do
      state = make_game_state()

      {:ok, new_state} = Move.hold(state, "ger1")
      assert new_state.units["ger1"].entrenchment == 1

      # Hold again
      {:ok, new_state2} = Move.hold(new_state, "ger1")
      assert new_state2.units["ger1"].entrenchment == 2
    end

    test "caps entrenchment at 3" do
      state = make_game_state()
      unit = %{state.units["ger1"] | entrenchment: 3}
      state = %{state | units: Map.put(state.units, "ger1", unit)}

      {:ok, new_state} = Move.hold(state, "ger1")
      assert new_state.units["ger1"].entrenchment == 3
    end

    test "returns error for non-existent unit" do
      state = make_game_state()
      assert {:error, :unit_not_found} = Move.hold(state, "nonexistent")
    end
  end
end
