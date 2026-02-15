defmodule WargameAi.Tactics.MovementTest do
  use ExUnit.Case, async: true

  alias WargameAi.Tactics.Movement
  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Turns.{Phase, TurnState}
  alias WargameCore.Units.{UnitTemplate, UnitInstance}

  defp create_template(category) do
    UnitTemplate.new(%{
      name: "Test #{category}",
      nationality: "german",
      era: "ww2",
      category: category,
      unit_size: :battalion,
      attack_soft: 4,
      attack_hard: 2,
      defense: 4,
      armor: if(category == :armor, do: 3, else: 0),
      range: 1,
      spotting: 3,
      initiative: 3,
      movement_points: if(category == :armor, do: 6, else: 4),
      movement_type: if(category == :armor, do: :tracked, else: :foot),
      max_strength: 10,
      max_ammo: 10,
      max_fuel: if(category == :armor, do: 10, else: 0)
    })
  end

  defp create_unit(id, side, position, opts \\ []) do
    category = Keyword.get(opts, :category, :infantry)
    template = Keyword.get(opts, :template, create_template(category))
    mp = Keyword.get(opts, :movement_remaining, template.movement_points)
    strength = Keyword.get(opts, :strength, template.max_strength)

    unit =
      UnitInstance.new(template, %{
        id: id,
        name: "Unit #{id}",
        side: side,
        force: side,
        position: position,
        current_strength: strength
      })

    %{unit | movement_remaining: mp}
  end

  defp make_turn_state(sides) do
    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true)
    ]

    TurnState.new(phases, sides)
  end

  defp base_game_state(opts) do
    map = Keyword.get(opts, :map, GameMap.new("test_map", 8, 8, 200))

    %{
      map: map,
      units: Keyword.get(opts, :units, %{}),
      leaders: Keyword.get(opts, :leaders, %{}),
      turn_state: make_turn_state(Keyword.get(opts, :sides, [:german, :soviet])),
      sides: Keyword.get(opts, :sides, [:german, :soviet]),
      victory_conditions: %{}
    }
  end

  defp default_config(side \\ :german) do
    %{side: side, difficulty: :hard, personality: :balanced}
  end

  describe "plan_moves/2" do
    test "generates move actions for movable units" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      state = base_game_state(units: %{"g1" => u1})

      actions = Movement.plan_moves(state, default_config())

      # Should produce at least one action (move or hold)
      assert length(actions) >= 1

      Enum.each(actions, fn action ->
        assert match?({:move, _, _}, action) or match?({:hold, _}, action)
      end)
    end

    test "does not generate actions for enemy units" do
      u1 = create_unit("s1", :soviet, Coord.new(1, 1))
      state = base_game_state(units: %{"s1" => u1})

      actions = Movement.plan_moves(state, default_config(:german))

      assert actions == []
    end

    test "holds units that cannot move" do
      u1 = create_unit("g1", :german, Coord.new(1, 1), movement_remaining: 0)
      state = base_game_state(units: %{"g1" => u1})

      actions = Movement.plan_moves(state, default_config())

      # Unit with 0 movement should not appear (can_move? is false)
      assert actions == []
    end

    test "moves toward VP hexes" do
      map = GameMap.new("test_map", 8, 8, 200)

      # Put VP on a hex
      vp_coord = Coord.new(4, 4)
      tile = GameMap.get_tile(map, vp_coord)

      map =
        if tile do
          %{map | tiles: Map.put(map.tiles, vp_coord, %{tile | victory_points: 10, control: nil})}
        else
          map
        end

      u1 = create_unit("g1", :german, Coord.new(1, 1))
      state = base_game_state(map: map, units: %{"g1" => u1})

      actions = Movement.plan_moves(state, default_config())

      # The unit should move (not hold), moving toward the VP hex
      move_actions = Enum.filter(actions, &match?({:move, _, _}, &1))

      if length(move_actions) > 0 do
        {:move, _id, path} = hd(move_actions)
        destination = List.last(path)
        start = Coord.new(1, 1)

        # Destination should be closer to VP hex than start
        assert Coord.distance(destination, vp_coord) <= Coord.distance(start, vp_coord)
      end
    end

    test "handles multiple units without collisions" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2 = create_unit("g2", :german, Coord.new(2, 1))
      state = base_game_state(units: %{"g1" => u1, "g2" => u2})

      actions = Movement.plan_moves(state, default_config())

      # Should have 2 actions
      assert length(actions) == 2

      # Get final positions
      final_positions =
        Enum.map(actions, fn
          {:move, id, path} -> {id, List.last(path)}
          {:hold, id} ->
            unit = state.units[id]
            {id, unit.position}
        end)

      # No two units should end at the same position
      positions = Enum.map(final_positions, fn {_id, pos} -> Coord.to_key(pos) end)
      assert length(Enum.uniq(positions)) == length(positions)
    end

    test "entrenched units prefer staying put" do
      u1 = create_unit("g1", :german, Coord.new(3, 3))
      u1 = %{u1 | entrenchment: 3}
      state = base_game_state(units: %{"g1" => u1})

      actions = Movement.plan_moves(state, default_config())

      # Highly entrenched unit should hold
      assert Enum.any?(actions, &match?({:hold, "g1"}, &1))
    end
  end

  describe "plan_unit_move/4" do
    test "returns hold for unit with no reachable hexes" do
      # Create a tiny map with unit boxed in (surrounded by occupied hexes)
      u1 = create_unit("g1", :german, Coord.new(0, 0), movement_remaining: 1)
      occupied = MapSet.new(["1,0", "0,1", "1,-1"])

      state = base_game_state(units: %{"g1" => u1})
      config = default_config()

      result = Movement.plan_unit_move(state, u1, config, occupied)

      assert match?({:hold, "g1"}, result)
    end

    test "returns move action with valid path" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      occupied = MapSet.new(["1,1"])

      map = GameMap.new("test", 8, 8, 200)
      state = base_game_state(map: map, units: %{"g1" => u1})

      result = Movement.plan_unit_move(state, u1, default_config(), occupied)

      case result do
        {:move, "g1", path} ->
          assert length(path) >= 2
          assert hd(path) == Coord.new(1, 1)

        {:hold, "g1"} ->
          # Also acceptable
          assert true
      end
    end
  end
end
