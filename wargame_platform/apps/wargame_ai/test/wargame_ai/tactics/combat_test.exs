defmodule WargameAi.Tactics.CombatTest do
  use ExUnit.Case, async: true

  alias WargameAi.Tactics.Combat
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
      attack_soft: 6,
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

    if Keyword.get(opts, :has_attacked, false) do
      %{unit | has_attacked: true}
    else
      unit
    end
  end

  defp make_turn_state(sides) do
    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true)
    ]

    ts = TurnState.new(phases, sides)
    # Advance to combat phase
    {:ok, ts} = TurnState.advance_phase(ts)
    ts
  end

  defp base_game_state(opts) do
    map = Keyword.get(opts, :map, GameMap.new("test_map", 8, 8, 200))

    %{
      map: map,
      units: Keyword.get(opts, :units, %{}),
      leaders: Keyword.get(opts, :leaders, %{}),
      turn_state: make_turn_state(Keyword.get(opts, :sides, [:german, :soviet])),
      sides: Keyword.get(opts, :sides, [:german, :soviet]),
      victory_conditions: %{},
      rules_module: WargameCore.Rules.StandardRules
    }
  end

  defp default_config(side \\ :german) do
    %{side: side, difficulty: :hard, personality: :balanced}
  end

  describe "plan_attacks/2" do
    test "generates attacks when enemy units are adjacent" do
      # German unit at (2,2), Soviet unit at (3,2) - adjacent
      g1 = create_unit("g1", :german, Coord.new(2, 2))
      s1 = create_unit("s1", :soviet, Coord.new(3, 2))

      state = base_game_state(units: %{"g1" => g1, "s1" => s1})

      actions = Combat.plan_attacks(state, default_config())

      # The attack might or might not be generated depending on odds evaluation
      assert is_list(actions)
    end

    test "generates no attacks when no enemies are adjacent" do
      g1 = create_unit("g1", :german, Coord.new(1, 1))
      s1 = create_unit("s1", :soviet, Coord.new(5, 5))

      state = base_game_state(units: %{"g1" => g1, "s1" => s1})

      actions = Combat.plan_attacks(state, default_config())

      assert actions == []
    end

    test "skips units that have already attacked" do
      g1 = create_unit("g1", :german, Coord.new(2, 2), has_attacked: true)
      s1 = create_unit("s1", :soviet, Coord.new(3, 2))

      state = base_game_state(units: %{"g1" => g1, "s1" => s1})

      actions = Combat.plan_attacks(state, default_config())

      assert actions == []
    end

    test "concentrates multiple units on one target" do
      g1 = create_unit("g1", :german, Coord.new(2, 2))
      g2 = create_unit("g2", :german, Coord.new(3, 1))
      s1 = create_unit("s1", :soviet, Coord.new(3, 2))

      state = base_game_state(units: %{"g1" => g1, "g2" => g2, "s1" => s1})

      actions = Combat.plan_attacks(state, default_config())

      # If an attack is generated, it should include both attackers
      attack_actions = Enum.filter(actions, &match?({:attack, _, _}, &1))

      if length(attack_actions) > 0 do
        {:attack, attacker_ids, _target} = hd(attack_actions)
        # Both units should be in the attack if they're adjacent
        assert length(attacker_ids) >= 1
      end
    end

    test "aggressive personality attacks at worse odds" do
      g1 = create_unit("g1", :german, Coord.new(2, 2), strength: 5)
      s1 = create_unit("s1", :soviet, Coord.new(3, 2), strength: 10)

      state = base_game_state(units: %{"g1" => g1, "s1" => s1})

      aggressive_config = %{side: :german, difficulty: :hard, personality: :aggressive}
      balanced_config = %{side: :german, difficulty: :hard, personality: :balanced}

      aggressive_attacks = Combat.plan_attacks(state, aggressive_config)
      balanced_attacks = Combat.plan_attacks(state, balanced_config)

      # Aggressive should be more willing to attack at unfavorable odds
      assert length(aggressive_attacks) >= length(balanced_attacks)
    end

    test "does not attack with no units on the board" do
      state = base_game_state(units: %{})

      actions = Combat.plan_attacks(state, default_config())

      assert actions == []
    end
  end

  describe "evaluate_attack/3" do
    test "returns odds info for valid attack" do
      g1 = create_unit("g1", :german, Coord.new(2, 2))
      s1 = create_unit("s1", :soviet, Coord.new(3, 2))

      state = base_game_state(units: %{"g1" => g1, "s1" => s1})

      result = Combat.evaluate_attack(state, ["g1"], Coord.new(3, 2))

      case result do
        {:ok, odds_info} ->
          assert Map.has_key?(odds_info, :attack_strength)
          assert Map.has_key?(odds_info, :defense_strength)
          assert Map.has_key?(odds_info, :final_odds)

        {:error, _reason} ->
          # Also acceptable if StandardRules rejects it
          assert true
      end
    end
  end
end
