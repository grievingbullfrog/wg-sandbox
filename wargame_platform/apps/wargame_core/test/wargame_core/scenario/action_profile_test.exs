defmodule WargameCore.Scenario.ActionProfileTest do
  use ExUnit.Case, async: true

  alias WargameCore.Scenario.ActionProfile
  alias WargameCore.Turns.Phase

  @ww2_attrs %{
    id: "ww2-standard",
    name: "WW2 Standard",
    era: "ww2",
    action_options: [
      %{id: :move_and_fire, move: true, fire: true, melee: false, move_penalty: 0.5},
      %{id: :fire_only, move: false, fire: true, melee: false},
      %{id: :move_only, move: true, fire: false, melee: false},
      %{id: :hold, move: false, fire: false, melee: false, entrench: true},
      %{id: :assault, move: true, fire: true, melee: true, move_penalty: 0.5}
    ],
    phase_sequence: Phase.standard_phases(),
    rules_module: WargameCore.Rules.StandardRules
  }

  describe "new/1" do
    test "creates an action profile from attributes" do
      profile = ActionProfile.new(@ww2_attrs)
      assert profile.name == "WW2 Standard"
      assert profile.era == "ww2"
      assert profile.rules_module == WargameCore.Rules.StandardRules
      assert length(profile.action_options) == 5
      assert length(profile.phase_sequence) == 6
    end

    test "normalizes string-keyed action options from DB data" do
      db_attrs = %{
        name: "WW2 Standard",
        era: "ww2",
        action_options: [
          %{"id" => "move_and_fire", "move" => true, "fire" => true, "melee" => false, "move_penalty" => 0.5},
          %{"id" => "fire_only", "move" => false, "fire" => true, "melee" => false}
        ],
        phase_sequence: [
          %{"id" => "movement", "name" => "Movement", "allows_movement" => true},
          %{"id" => "combat", "name" => "Combat", "allows_combat" => true}
        ],
        rules_module: "Elixir.WargameCore.Rules.StandardRules"
      }

      profile = ActionProfile.new(db_attrs)
      assert length(profile.action_options) == 2
      first_action = hd(profile.action_options)
      assert first_action.id == :move_and_fire
      assert first_action.move == true
      assert first_action.fire == true
      assert first_action.move_penalty == 0.5

      assert length(profile.phase_sequence) == 2
      first_phase = hd(profile.phase_sequence)
      assert first_phase.id == :movement
      assert first_phase.allows_movement == true
    end

    test "defaults to empty lists when options not provided" do
      profile = ActionProfile.new(%{name: "Minimal", era: "test", rules_module: "Test"})
      assert profile.action_options == []
      assert profile.phase_sequence == []
    end
  end

  describe "ww2_standard/0" do
    test "creates the default WW2 profile" do
      profile = ActionProfile.ww2_standard()
      assert profile.name == "WW2 Standard"
      assert profile.era == "ww2"
      assert profile.rules_module == WargameCore.Rules.StandardRules
      assert length(profile.action_options) == 5

      ids = Enum.map(profile.action_options, & &1.id)
      assert :move_and_fire in ids
      assert :fire_only in ids
      assert :move_only in ids
      assert :hold in ids
      assert :assault in ids
    end

    test "has standard 6-phase sequence" do
      profile = ActionProfile.ww2_standard()
      phase_ids = Enum.map(profile.phase_sequence, & &1.id)

      assert phase_ids == [:command, :movement, :combat, :exploitation, :supply, :end_phase]
    end
  end

  describe "available_actions/2" do
    setup do
      %{profile: ActionProfile.new(@ww2_attrs)}
    end

    test "returns movement-related actions during movement phase", %{profile: profile} do
      movement_phase = Phase.new(:movement, "Movement", 1, allows_movement: true)
      actions = ActionProfile.available_actions(profile, movement_phase)

      ids = Enum.map(actions, & &1.id)
      assert :move_and_fire in ids
      assert :move_only in ids
      assert :assault in ids
      # hold is not move/fire/melee so it's available too (non-action)
      assert :hold in ids
      # fire_only has no move, no melee, but has fire - excluded from movement-only phase
      refute :fire_only in ids
    end

    test "returns combat-related actions during combat phase", %{profile: profile} do
      combat_phase = Phase.new(:combat, "Combat", 2, allows_combat: true)
      actions = ActionProfile.available_actions(profile, combat_phase)

      ids = Enum.map(actions, & &1.id)
      assert :fire_only in ids
      assert :move_and_fire in ids
      assert :assault in ids
      # hold has no fire/melee but is a non-action, so it's available
      assert :hold in ids
    end

    test "returns all actions during command phase", %{profile: profile} do
      command_phase = Phase.new(:command, "Command", 0, allows_orders: true)
      actions = ActionProfile.available_actions(profile, command_phase)

      assert length(actions) == 5
    end

    test "returns actions for exploitation phase (movement + combat)", %{profile: profile} do
      exploit_phase = Phase.new(:exploitation, "Exploitation", 3,
        allows_movement: true, allows_combat: true, is_optional: true)
      actions = ActionProfile.available_actions(profile, exploit_phase)

      ids = Enum.map(actions, & &1.id)
      # Should include anything with move or fire
      assert :move_and_fire in ids
      assert :fire_only in ids
      assert :move_only in ids
      assert :assault in ids
    end

    test "returns no actions during supply/end phases", %{profile: profile} do
      supply_phase = Phase.new(:supply, "Supply", 4)
      actions = ActionProfile.available_actions(profile, supply_phase)
      assert actions == []

      end_phase = Phase.new(:end_phase, "End", 5)
      actions = ActionProfile.available_actions(profile, end_phase)
      assert actions == []
    end
  end

  describe "action_allows_movement?/1" do
    test "returns true for actions with move: true" do
      assert ActionProfile.action_allows_movement?(%{move: true, fire: false, melee: false})
      assert ActionProfile.action_allows_movement?(%{move: true, fire: true, melee: false})
    end

    test "returns false for actions with move: false" do
      refute ActionProfile.action_allows_movement?(%{move: false, fire: true, melee: false})
      refute ActionProfile.action_allows_movement?(%{move: false, fire: false, melee: false})
    end

    test "returns false for maps without move key" do
      refute ActionProfile.action_allows_movement?(%{fire: true})
    end
  end

  describe "action_allows_fire?/1" do
    test "returns true for actions with fire: true" do
      assert ActionProfile.action_allows_fire?(%{fire: true})
    end

    test "returns false for actions with fire: false" do
      refute ActionProfile.action_allows_fire?(%{fire: false})
    end
  end

  describe "action_allows_melee?/1" do
    test "returns true for actions with melee: true" do
      assert ActionProfile.action_allows_melee?(%{melee: true})
    end

    test "returns false for actions with melee: false" do
      refute ActionProfile.action_allows_melee?(%{melee: false})
    end
  end

  describe "movement_penalty_for/1" do
    test "returns the penalty when set" do
      assert ActionProfile.movement_penalty_for(%{move_penalty: 0.5}) == 0.5
      assert ActionProfile.movement_penalty_for(%{move_penalty: 0.75}) == 0.75
    end

    test "returns 1.0 when no penalty" do
      assert ActionProfile.movement_penalty_for(%{move: true}) == 1.0
      assert ActionProfile.movement_penalty_for(%{move_penalty: nil}) == 1.0
    end
  end

  describe "action_allows_entrench?/1" do
    test "returns true for hold action with entrench flag" do
      assert ActionProfile.action_allows_entrench?(%{entrench: true})
    end

    test "returns false for other actions" do
      refute ActionProfile.action_allows_entrench?(%{entrench: false})
      refute ActionProfile.action_allows_entrench?(%{move: true})
    end
  end

  describe "get_action/2" do
    test "finds an action by id" do
      profile = ActionProfile.new(@ww2_attrs)
      action = ActionProfile.get_action(profile, :fire_only)
      assert action.id == :fire_only
      assert action.fire == true
      assert action.move == false
    end

    test "returns nil for unknown action" do
      profile = ActionProfile.new(@ww2_attrs)
      assert ActionProfile.get_action(profile, :nonexistent) == nil
    end
  end

  describe "phases/1" do
    test "returns the phase sequence" do
      profile = ActionProfile.new(@ww2_attrs)
      phases = ActionProfile.phases(profile)
      assert length(phases) == 6
      assert hd(phases).id == :command
    end
  end
end
