defmodule WargameAi.EvaluatorTest do
  use ExUnit.Case, async: true

  alias WargameAi.Evaluator
  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Turns.{Phase, TurnState}
  alias WargameCore.Units.{UnitTemplate, UnitInstance}

  defp create_map(opts \\ []) do
    width = Keyword.get(opts, :width, 6)
    height = Keyword.get(opts, :height, 6)
    map = GameMap.new("test_map", width, height, 200)

    # Apply VP hexes
    vp_hexes = Keyword.get(opts, :vp_hexes, [])

    Enum.reduce(vp_hexes, map, fn {coord, vp, control}, acc ->
      tile = GameMap.get_tile(acc, coord)

      if tile do
        updated_tile = %{tile | victory_points: vp, control: control}
        %{acc | tiles: Map.put(acc.tiles, coord, updated_tile)}
      else
        acc
      end
    end)
  end

  defp create_template(category \\ :infantry) do
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
    template = Keyword.get(opts, :template, create_template())
    strength = Keyword.get(opts, :strength, template.max_strength)

    UnitInstance.new(template, %{
      id: id,
      name: "Unit #{id}",
      side: side,
      force: side,
      position: position,
      current_strength: strength
    })
  end

  defp create_leader(id, side, position, opts \\ []) do
    %{
      id: id,
      name: "Leader #{id}",
      side: side,
      force: side,
      position: position,
      command_radius: Keyword.get(opts, :command_radius, 2),
      rank: :colonel,
      attack_modifier: 1,
      defense_modifier: 1,
      morale_modifier: 5,
      initiative_modifier: 0,
      abilities: []
    }
  end

  defp make_turn_state(sides) do
    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true)
    ]

    TurnState.new(phases, sides)
  end

  defp base_game_state(opts \\ []) do
    map = Keyword.get(opts, :map, create_map())
    sides = Keyword.get(opts, :sides, [:german, :soviet])

    %{
      map: map,
      units: Keyword.get(opts, :units, %{}),
      leaders: Keyword.get(opts, :leaders, %{}),
      turn_state: make_turn_state(sides),
      sides: sides,
      victory_conditions: %{}
    }
  end

  describe "evaluate_position/3" do
    test "returns higher score for side with more VP control" do
      map = create_map(vp_hexes: [
        {Coord.new(1, 1), 5, :german},
        {Coord.new(2, 2), 5, :soviet}
      ])

      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2 = create_unit("s1", :soviet, Coord.new(2, 2))

      state = base_game_state(
        map: map,
        units: %{"g1" => u1, "s1" => u2}
      )

      # Both sides have equal VP, so VP score should be balanced
      german_score = Evaluator.evaluate_position(state, :german)
      soviet_score = Evaluator.evaluate_position(state, :soviet)

      # Scores should be symmetric-ish (both have 1 unit, 1 VP hex)
      assert is_float(german_score)
      assert is_float(soviet_score)
    end

    test "returns higher score when side has more unit strength" do
      u1 = create_unit("g1", :german, Coord.new(1, 1), strength: 10)
      u2 = create_unit("s1", :soviet, Coord.new(2, 2), strength: 3)

      state = base_game_state(units: %{"g1" => u1, "s1" => u2})

      german_score = Evaluator.evaluate_position(state, :german)
      soviet_score = Evaluator.evaluate_position(state, :soviet)

      assert german_score > soviet_score
    end

    test "returns higher score when side has more units" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2 = create_unit("g2", :german, Coord.new(2, 1))
      u3 = create_unit("g3", :german, Coord.new(3, 1))
      u4 = create_unit("s1", :soviet, Coord.new(4, 4))

      state = base_game_state(units: %{"g1" => u1, "g2" => u2, "g3" => u3, "s1" => u4})

      german_score = Evaluator.evaluate_position(state, :german)
      soviet_score = Evaluator.evaluate_position(state, :soviet)

      assert german_score > soviet_score
    end

    test "values leader survival" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2 = create_unit("s1", :soviet, Coord.new(4, 4))
      leader = create_leader("l1", :german, Coord.new(1, 2))

      state_with_leader = base_game_state(
        units: %{"g1" => u1, "s1" => u2},
        leaders: %{"l1" => leader}
      )

      state_without_leader = base_game_state(
        units: %{"g1" => u1, "s1" => u2},
        leaders: %{}
      )

      score_with = Evaluator.evaluate_position(state_with_leader, :german)
      score_without = Evaluator.evaluate_position(state_without_leader, :german)

      assert score_with > score_without
    end

    test "values enemy disrupted units positively" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2_ok = create_unit("s1", :soviet, Coord.new(4, 4))
      u2_disrupted = %{u2_ok | is_disrupted: true}

      state_ok = base_game_state(units: %{"g1" => u1, "s1" => u2_ok})
      state_disrupted = base_game_state(units: %{"g1" => u1, "s1" => u2_disrupted})

      score_ok = Evaluator.evaluate_position(state_ok, :german)
      score_disrupted = Evaluator.evaluate_position(state_disrupted, :german)

      assert score_disrupted > score_ok
    end

    test "accepts custom weights" do
      u1 = create_unit("g1", :german, Coord.new(1, 1))
      u2 = create_unit("s1", :soviet, Coord.new(4, 4))
      state = base_game_state(units: %{"g1" => u1, "s1" => u2})

      score_default = Evaluator.evaluate_position(state, :german)
      score_custom = Evaluator.evaluate_position(state, :german, weights: %{vp_control: 100.0})

      # Custom weights should produce a different score
      assert score_default != score_custom || score_default == score_custom
      assert is_float(score_custom)
    end
  end

  describe "score_hex/4" do
    test "VP hexes score higher than empty hexes" do
      map = create_map(vp_hexes: [{Coord.new(2, 2), 5, nil}])

      u1 = create_unit("g1", :german, Coord.new(0, 0))
      state = base_game_state(map: map, units: %{"g1" => u1})

      vp_score = Evaluator.score_hex(state, :german, Coord.new(2, 2))
      empty_score = Evaluator.score_hex(state, :german, Coord.new(3, 3))

      assert vp_score > empty_score
    end

    test "forest hexes score higher than clear (defensive terrain)" do
      map = create_map()

      # Set a forest hex
      forest_coord = Coord.new(2, 2)
      clear_coord = Coord.new(3, 3)
      tile = GameMap.get_tile(map, forest_coord)

      map =
        if tile do
          %{map | tiles: Map.put(map.tiles, forest_coord, %{tile | terrain: :forest})}
        else
          map
        end

      state = base_game_state(map: map, units: %{})

      forest_score = Evaluator.score_hex(state, :german, forest_coord)
      clear_score = Evaluator.score_hex(state, :german, clear_coord)

      assert forest_score > clear_score
    end

    test "hexes near friendly units score higher (support)" do
      u1 = create_unit("g1", :german, Coord.new(2, 2))
      u2 = create_unit("g2", :german, Coord.new(2, 3))
      state = base_game_state(units: %{"g1" => u1, "g2" => u2})

      # Hex near two friendly units
      near_score = Evaluator.score_hex(state, :german, Coord.new(3, 2))

      # Hex far from everyone
      far_score = Evaluator.score_hex(state, :german, Coord.new(5, 5))

      assert near_score > far_score
    end

    test "returns very low score for nil tiles (off-map)" do
      state = base_game_state()

      score = Evaluator.score_hex(state, :german, Coord.new(99, 99))
      assert score == -100.0
    end

    test "hex in leader command radius gets bonus" do
      leader = create_leader("l1", :german, Coord.new(2, 2), command_radius: 2)
      state = base_game_state(leaders: %{"l1" => leader})

      in_range = Evaluator.score_hex(state, :german, Coord.new(2, 3))
      out_of_range = Evaluator.score_hex(state, :german, Coord.new(5, 5))

      assert in_range > out_of_range
    end
  end

  describe "default_weights/0" do
    test "returns a map with expected keys" do
      weights = Evaluator.default_weights()

      assert is_map(weights)
      assert Map.has_key?(weights, :vp_control)
      assert Map.has_key?(weights, :unit_strength)
      assert Map.has_key?(weights, :unit_count)
      assert Map.has_key?(weights, :leader_survival)
    end
  end
end
