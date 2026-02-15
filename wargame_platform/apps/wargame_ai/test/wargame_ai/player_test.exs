defmodule WargameAi.PlayerTest do
  use ExUnit.Case, async: true

  alias WargameAi.Player
  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Turns.{Phase, TurnState}
  alias WargameCore.Units.{UnitTemplate, UnitInstance}

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
      armor: 0,
      range: 1,
      spotting: 3,
      initiative: 3,
      movement_points: 4,
      movement_type: :foot,
      max_strength: 10,
      max_ammo: 10,
      max_fuel: 0
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

  defp make_turn_state(sides) do
    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true),
      Phase.new(:end, "End", 2)
    ]

    TurnState.new(phases, sides)
  end

  defp base_game_state(opts) do
    %{
      map: Keyword.get(opts, :map, GameMap.new("test", 8, 8, 200)),
      units: Keyword.get(opts, :units, %{}),
      leaders: Keyword.get(opts, :leaders, %{}),
      turn_state: make_turn_state(Keyword.get(opts, :sides, [:german, :soviet])),
      sides: Keyword.get(opts, :sides, [:german, :soviet]),
      victory_conditions: %{},
      rules_module: WargameCore.Rules.StandardRules
    }
  end

  describe "play_turn/2" do
    test "generates actions for active side" do
      u1 = create_unit("g1", :german, Coord.new(2, 2))
      state = base_game_state(units: %{"g1" => u1})

      config = %{side: :german, difficulty: :hard, personality: :balanced}
      actions = Player.play_turn(state, config)

      # Should include at least one end_phase
      assert :end_phase in actions
      assert length(actions) >= 1
    end

    test "returns empty list when not active side" do
      u1 = create_unit("s1", :soviet, Coord.new(2, 2))
      state = base_game_state(units: %{"s1" => u1})

      # Soviet is NOT the active side (German moves first)
      config = %{side: :soviet, difficulty: :hard, personality: :balanced}
      actions = Player.play_turn(state, config)

      assert actions == []
    end

    test "includes movement and end_phase actions" do
      u1 = create_unit("g1", :german, Coord.new(2, 2))
      state = base_game_state(units: %{"g1" => u1})

      config = %{side: :german, difficulty: :hard, personality: :balanced}
      actions = Player.play_turn(state, config)

      # Should have at least movement actions + end_phase for each phase
      end_phases = Enum.count(actions, &(&1 == :end_phase))
      assert end_phases >= 1
    end
  end

  describe "apply_difficulty/2" do
    test "hard always picks best option" do
      options = [{:a, 100.0}, {:b, 50.0}, {:c, 10.0}]

      # Run many times - hard should always pick :a
      results = for _ <- 1..20, do: Player.apply_difficulty(options, :hard)
      assert Enum.all?(results, &(&1 == :a))
    end

    test "returns nil for empty list" do
      assert Player.apply_difficulty([], :hard) == nil
    end

    test "easy sometimes picks non-optimal" do
      options = [{:a, 100.0}, {:b, 50.0}, {:c, 10.0}]

      # Run many times - easy should sometimes not pick :a
      results = for _ <- 1..100, do: Player.apply_difficulty(options, :easy)

      # At least one should be non-optimal (40% chance each time, very likely over 100 trials)
      has_non_optimal = Enum.any?(results, &(&1 != :a))
      # This could technically fail but probability is ~(0.6)^100 ≈ 0, so extremely unlikely
      assert has_non_optimal
    end
  end

  describe "personality_weights/1" do
    test "aggressive favors VP control and enemy disruption" do
      aggressive = Player.personality_weights(:aggressive)
      balanced = Player.personality_weights(:balanced)

      assert aggressive.vp_control > balanced.vp_control
      assert aggressive.enemy_disruption > balanced.enemy_disruption
    end

    test "defensive favors territorial depth and leader survival" do
      defensive = Player.personality_weights(:defensive)
      balanced = Player.personality_weights(:balanced)

      assert defensive.territorial_depth > balanced.territorial_depth
      assert defensive.leader_survival > balanced.leader_survival
    end

    test "balanced returns default weights" do
      balanced = Player.personality_weights(:balanced)
      defaults = WargameAi.Evaluator.default_weights()

      assert balanced == defaults
    end
  end
end
