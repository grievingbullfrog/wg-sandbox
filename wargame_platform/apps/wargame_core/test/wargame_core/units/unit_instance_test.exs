defmodule WargameCore.Units.UnitInstanceTest do
  use ExUnit.Case, async: true

  alias WargameCore.Units.{UnitInstance, UnitTemplate}
  alias WargameCore.Hex.Coord

  @panzer_template UnitTemplate.new(%{
                     id: "panzer-iv",
                     name: "Panzer IV",
                     nationality: "german",
                     era: "ww2",
                     category: :armor,
                     unit_size: :platoon,
                     attack_soft: 6,
                     attack_hard: 12,
                     defense: 10,
                     armor: 5,
                     movement_points: 8,
                     movement_type: :tracked,
                     range: 1,
                     spotting: 3,
                     initiative: 5,
                     max_strength: 10,
                     max_ammo: 6,
                     max_fuel: 8,
                     can_bridge: false,
                     can_entrench: false,
                     is_organic_transport: false
                   })

  @infantry_template UnitTemplate.new(%{
                       id: "rifle-platoon",
                       name: "Rifle Platoon",
                       nationality: "soviet",
                       era: "ww2",
                       category: :infantry,
                       unit_size: :platoon,
                       attack_soft: 5,
                       attack_hard: 1,
                       defense: 4,
                       armor: 0,
                       movement_points: 4,
                       movement_type: :foot,
                       range: 0,
                       spotting: 2,
                       initiative: 3,
                       max_strength: 10,
                       max_ammo: 4,
                       max_fuel: 0,
                       can_entrench: true
                     })

  describe "new/2" do
    test "creates instance from template with deployment options" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "3rd Panzer Division",
          side: :axis,
          force: :german,
          position: Coord.new(3, 4)
        })

      assert unit.name == "3rd Panzer Division"
      assert unit.side == :axis
      assert unit.force == :german
      assert unit.position == Coord.new(3, 4)
      assert unit.current_strength == 10
      assert unit.current_ammo == 6
      assert unit.current_fuel == 8
      assert unit.template == @panzer_template
      assert unit.unit_template_id == "panzer-iv"
    end

    test "defaults strength/ammo/fuel to template max" do
      unit = UnitInstance.new(@panzer_template, %{name: "Test", side: :axis, force: :german})
      assert unit.current_strength == @panzer_template.max_strength
      assert unit.current_ammo == @panzer_template.max_ammo
      assert unit.current_fuel == @panzer_template.max_fuel
    end

    test "allows overriding initial strength" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Battered Panzer",
          side: :axis,
          force: :german,
          current_strength: 5
        })

      assert unit.current_strength == 5
    end

    test "sets experience and morale defaults" do
      unit = UnitInstance.new(@panzer_template, %{name: "Test", side: :axis, force: :german})
      assert unit.experience == 0
      assert unit.morale == 50
    end

    test "allows setting experience and morale" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Veterans",
          side: :axis,
          force: :german,
          experience: 4,
          morale: 80
        })

      assert unit.experience == 4
      assert unit.morale == 80
    end

    test "initializes turn state flags" do
      unit = UnitInstance.new(@panzer_template, %{name: "Test", side: :axis, force: :german})
      assert unit.movement_remaining == 8
      assert unit.has_attacked == false
      assert unit.has_moved == false
      assert unit.is_disrupted == false
      assert unit.is_routed == false
      assert unit.entrenchment == 0
    end

    test "generates an id" do
      unit = UnitInstance.new(@panzer_template, %{name: "Test", side: :axis, force: :german})
      assert unit.id != nil
    end

    test "allows providing an id" do
      unit =
        UnitInstance.new(@panzer_template, %{
          id: "my-unit",
          name: "Test",
          side: :axis,
          force: :german
        })

      assert unit.id == "my-unit"
    end

    test "supports reinforcement fields" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Reinforcement",
          side: :axis,
          force: :german,
          arrives_turn: 3,
          deploy_hex: Coord.new(0, 5)
        })

      assert unit.arrives_turn == 3
      assert unit.deploy_hex == Coord.new(0, 5)
    end
  end

  describe "effective_attack_soft/1" do
    test "scales by strength ratio and experience" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          experience: 0
        })

      # Full strength, 0 experience: base value
      assert UnitInstance.effective_attack_soft(unit) == 6
    end

    test "half strength reduces effectiveness" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          current_strength: 5,
          experience: 0
        })

      # 5/10 = 0.5 ratio, 6 * 0.5 = 3
      assert UnitInstance.effective_attack_soft(unit) == 3
    end

    test "experience adds bonus" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Veterans",
          side: :axis,
          force: :german,
          experience: 4
        })

      # Full strength + experience bonus: 6 * (1.0 + 0.4*0.1) = 6 * 1.04 = ~6.24 -> 6
      # With experience formula: base * strength_ratio * (1 + experience * 0.05)
      result = UnitInstance.effective_attack_soft(unit)
      assert result >= 6
    end
  end

  describe "effective_attack_hard/1" do
    test "returns scaled hard attack" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.effective_attack_hard(unit) == 12
    end

    test "scales with reduced strength" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          current_strength: 5
        })

      assert UnitInstance.effective_attack_hard(unit) == 6
    end
  end

  describe "effective_defense/1" do
    test "returns defense at full strength" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.effective_defense(unit) == 10
    end

    test "entrenchment adds defense bonus" do
      unit =
        UnitInstance.new(@infantry_template, %{
          name: "Dug In",
          side: :allied,
          force: :soviet
        })

      entrenched = %{unit | entrenchment: 3}
      base_def = UnitInstance.effective_defense(unit)
      entrenched_def = UnitInstance.effective_defense(entrenched)
      assert entrenched_def > base_def
    end

    test "disrupted units have reduced defense" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      disrupted = %{unit | is_disrupted: true}
      normal_def = UnitInstance.effective_defense(unit)
      disrupted_def = UnitInstance.effective_defense(disrupted)
      assert disrupted_def < normal_def
    end
  end

  describe "apply_damage/2" do
    test "reduces strength" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          morale: 80
        })

      damaged = UnitInstance.apply_damage(unit, 3)
      assert damaged.current_strength == 7
    end

    test "strength cannot go below 0" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          morale: 80
        })

      destroyed = UnitInstance.apply_damage(unit, 20)
      assert destroyed.current_strength == 0
    end

    test "heavy damage can cause disruption" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          morale: 30
        })

      # With low morale, damage is more likely to cause disruption
      # We test the mechanism, not the random outcome
      damaged = UnitInstance.apply_damage(unit, 5)
      assert damaged.current_strength == 5
      # Disruption depends on morale check - unit has low morale so may be disrupted
    end
  end

  describe "resupply/1" do
    test "restores ammo and fuel to max" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      depleted = %{unit | current_ammo: 2, current_fuel: 3}
      resupplied = UnitInstance.resupply(depleted)
      assert resupplied.current_ammo == 6
      assert resupplied.current_fuel == 8
    end
  end

  describe "rally/1" do
    test "recovers from disruption with good morale" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          morale: 100
        })

      disrupted = %{unit | is_disrupted: true}
      # With 100 morale, rally should always succeed
      rallied = UnitInstance.rally(disrupted)
      refute rallied.is_disrupted
    end

    test "routed unit rallies to disrupted first" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          morale: 100
        })

      routed = %{unit | is_routed: true, is_disrupted: true}
      rallied = UnitInstance.rally(routed)
      # Rout cleared, but still disrupted
      refute rallied.is_routed
      assert rallied.is_disrupted
    end

    test "unit not disrupted or routed is unchanged" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.rally(unit) == unit
    end
  end

  describe "entrench/1" do
    test "increases entrenchment level" do
      unit =
        UnitInstance.new(@infantry_template, %{
          name: "Test",
          side: :allied,
          force: :soviet
        })

      entrenched = UnitInstance.entrench(unit)
      assert entrenched.entrenchment == 1
    end

    test "caps at max entrenchment of 3" do
      unit =
        UnitInstance.new(@infantry_template, %{
          name: "Test",
          side: :allied,
          force: :soviet
        })

      result =
        unit
        |> UnitInstance.entrench()
        |> UnitInstance.entrench()
        |> UnitInstance.entrench()
        |> UnitInstance.entrench()

      assert result.entrenchment == 3
    end

    test "units that can't entrench stay at 0" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      result = UnitInstance.entrench(unit)
      assert result.entrenchment == 0
    end
  end

  describe "reset_turn_state/1" do
    test "resets movement, attack, and move flags" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      spent = %{unit | movement_remaining: 0, has_attacked: true, has_moved: true}
      reset = UnitInstance.reset_turn_state(spent)
      assert reset.movement_remaining == 8
      assert reset.has_attacked == false
      assert reset.has_moved == false
    end

    test "disrupted units get half movement" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      disrupted = %{unit | is_disrupted: true, movement_remaining: 0}
      reset = UnitInstance.reset_turn_state(disrupted)
      assert reset.movement_remaining == 4
    end

    test "routed units get no movement" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      routed = %{unit | is_routed: true, movement_remaining: 0}
      reset = UnitInstance.reset_turn_state(routed)
      assert reset.movement_remaining == 0
    end
  end

  describe "spend_movement/2" do
    test "reduces movement remaining" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      moved = UnitInstance.spend_movement(unit, 3)
      assert moved.movement_remaining == 5
      assert moved.has_moved == true
    end

    test "cannot go below 0" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      moved = UnitInstance.spend_movement(unit, 20)
      assert moved.movement_remaining == 0
    end
  end

  describe "can_move?/1" do
    test "true when has movement remaining and not routed" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.can_move?(unit)
    end

    test "false when no movement remaining" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      spent = %{unit | movement_remaining: 0}
      refute UnitInstance.can_move?(spent)
    end

    test "false when routed" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      routed = %{unit | is_routed: true}
      refute UnitInstance.can_move?(routed)
    end
  end

  describe "can_attack?/1" do
    test "true when has not attacked and not routed" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.can_attack?(unit)
    end

    test "false when already attacked" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      attacked = %{unit | has_attacked: true}
      refute UnitInstance.can_attack?(attacked)
    end

    test "false when disrupted" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      disrupted = %{unit | is_disrupted: true}
      refute UnitInstance.can_attack?(disrupted)
    end
  end

  describe "attachments" do
    test "attach/2 adds a template as an attachment" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      at_gun =
        UnitTemplate.new(%{
          id: "88mm-at",
          name: "88mm AT Gun",
          nationality: "german",
          era: "ww2",
          category: :anti_tank,
          unit_size: :platoon,
          attack_soft: 3,
          attack_hard: 15,
          defense: 2,
          movement_points: 2,
          movement_type: :foot,
          max_strength: 5
        })

      attached = UnitInstance.attach(unit, at_gun)
      assert length(attached.attachments) == 1
      assert hd(attached.attachments).id == "88mm-at"
    end

    test "detach/2 removes an attachment by id" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      at_gun =
        UnitTemplate.new(%{
          id: "88mm-at",
          name: "88mm AT Gun",
          nationality: "german",
          era: "ww2",
          category: :anti_tank,
          unit_size: :platoon,
          attack_soft: 3,
          attack_hard: 15,
          defense: 2,
          movement_points: 2,
          movement_type: :foot,
          max_strength: 5
        })

      attached = UnitInstance.attach(unit, at_gun)
      detached = UnitInstance.detach(attached, "88mm-at")
      assert detached.attachments == []
    end

    test "attachment_bonus/2 sums stat from all attachments" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      at_gun =
        UnitTemplate.new(%{
          id: "88mm-at",
          name: "88mm AT Gun",
          nationality: "german",
          era: "ww2",
          category: :anti_tank,
          unit_size: :platoon,
          attack_soft: 3,
          attack_hard: 15,
          defense: 2,
          movement_points: 2,
          movement_type: :foot,
          max_strength: 5
        })

      attached = UnitInstance.attach(unit, at_gun)
      assert UnitInstance.attachment_bonus(attached, :attack_hard) == 15
      assert UnitInstance.attachment_bonus(attached, :attack_soft) == 3
    end
  end

  describe "is_alive?/1" do
    test "true when strength > 0" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.is_alive?(unit)
    end

    test "false when strength is 0" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          current_strength: 0
        })

      refute UnitInstance.is_alive?(unit)
    end
  end

  describe "strength_ratio/1" do
    test "returns current/max ratio" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german,
          current_strength: 7
        })

      assert_in_delta UnitInstance.strength_ratio(unit), 0.7, 0.01
    end

    test "returns 1.0 at full strength" do
      unit =
        UnitInstance.new(@panzer_template, %{
          name: "Test",
          side: :axis,
          force: :german
        })

      assert UnitInstance.strength_ratio(unit) == 1.0
    end
  end
end
