defmodule WargameCore.Units.UnitTemplateTest do
  use ExUnit.Case, async: true

  alias WargameCore.Units.UnitTemplate

  @valid_attrs %{
    id: "test-panzer-iv",
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: :armor,
    unit_size: :platoon,
    icon_type: "armor_medium",
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
  }

  describe "new/1" do
    test "creates a template from a map" do
      template = UnitTemplate.new(@valid_attrs)
      assert template.name == "Panzer IV"
      assert template.category == :armor
      assert template.attack_hard == 12
      assert template.movement_type == :tracked
    end

    test "creates a template from a keyword list" do
      attrs = Enum.into(@valid_attrs, [])
      template = UnitTemplate.new(attrs)
      assert template.name == "Panzer IV"
      assert template.category == :armor
    end

    test "sets defaults for optional fields" do
      minimal = %{
        name: "Basic Unit",
        nationality: "german",
        era: "ww2",
        category: :infantry,
        unit_size: :platoon,
        attack_soft: 5,
        attack_hard: 1,
        defense: 4,
        movement_points: 4,
        movement_type: :foot,
        max_strength: 10
      }

      template = UnitTemplate.new(minimal)
      assert template.armor == 0
      assert template.range == 0
      assert template.spotting == 1
      assert template.initiative == 0
      assert template.max_ammo == 0
      assert template.max_fuel == 0
      assert template.can_bridge == false
      assert template.can_entrench == true
      assert template.is_organic_transport == false
      assert template.icon_type == nil
    end

    test "generates an id if not provided" do
      template = UnitTemplate.new(%{@valid_attrs | id: nil})
      assert template.id != nil
    end
  end

  describe "combat_effectiveness/2" do
    test "returns full attack at full strength" do
      template = UnitTemplate.new(@valid_attrs)
      # Full strength ratio = 1.0
      assert UnitTemplate.combat_effectiveness(template, :attack_soft, 1.0) == 6
      assert UnitTemplate.combat_effectiveness(template, :attack_hard, 1.0) == 12
    end

    test "scales attack by strength ratio" do
      template = UnitTemplate.new(@valid_attrs)
      # Half strength: 50% effectiveness
      assert UnitTemplate.combat_effectiveness(template, :attack_soft, 0.5) == 3
      assert UnitTemplate.combat_effectiveness(template, :attack_hard, 0.5) == 6
    end

    test "returns defense scaled by strength ratio" do
      template = UnitTemplate.new(@valid_attrs)
      assert UnitTemplate.combat_effectiveness(template, :defense, 1.0) == 10
      assert UnitTemplate.combat_effectiveness(template, :defense, 0.5) == 5
    end

    test "returns at least 1 for non-zero base stat" do
      template = UnitTemplate.new(%{@valid_attrs | attack_soft: 2})
      # 10% strength = 0.2, rounds to 1 minimum
      assert UnitTemplate.combat_effectiveness(template, :attack_soft, 0.1) == 1
    end

    test "returns 0 for zero base stat" do
      template = UnitTemplate.new(%{@valid_attrs | attack_soft: 0})
      assert UnitTemplate.combat_effectiveness(template, :attack_soft, 1.0) == 0
    end
  end

  describe "valid_categories/0" do
    test "returns all valid category atoms" do
      categories = UnitTemplate.valid_categories()
      assert :infantry in categories
      assert :armor in categories
      assert :motorized in categories
      assert :artillery in categories
      assert :recon in categories
      assert :engineer in categories
      assert :anti_tank in categories
      assert :anti_air in categories
      assert :cavalry in categories
      assert :naval in categories
      assert :air in categories
    end
  end

  describe "valid_movement_types/0" do
    test "returns all valid movement type atoms" do
      types = UnitTemplate.valid_movement_types()
      assert :foot in types
      assert :wheeled in types
      assert :tracked in types
      assert :horse in types
      assert :rail_only in types
      assert :air in types
    end
  end

  describe "valid_unit_sizes/0" do
    test "returns all valid unit size atoms" do
      sizes = UnitTemplate.valid_unit_sizes()
      assert :squad in sizes
      assert :platoon in sizes
      assert :company in sizes
      assert :battalion in sizes
      assert :regiment in sizes
      assert :brigade in sizes
      assert :division in sizes
      assert :corps in sizes
    end
  end

  describe "terrain_category/1" do
    test "maps unit category to terrain movement category" do
      # Armor uses :armor terrain costs
      template = UnitTemplate.new(%{@valid_attrs | category: :armor})
      assert UnitTemplate.terrain_category(template) == :armor

      # Anti-tank uses :infantry terrain costs
      template = UnitTemplate.new(%{@valid_attrs | category: :anti_tank})
      assert UnitTemplate.terrain_category(template) == :infantry

      # Motorized uses :motorized terrain costs
      template = UnitTemplate.new(%{@valid_attrs | category: :motorized})
      assert UnitTemplate.terrain_category(template) == :motorized

      # Cavalry uses :infantry terrain costs
      template = UnitTemplate.new(%{@valid_attrs | category: :cavalry})
      assert UnitTemplate.terrain_category(template) == :infantry
    end
  end

  describe "is_hard_target?/1" do
    test "armor is a hard target" do
      template = UnitTemplate.new(%{@valid_attrs | armor: 5})
      assert UnitTemplate.is_hard_target?(template)
    end

    test "infantry is a soft target" do
      template = UnitTemplate.new(%{@valid_attrs | armor: 0})
      refute UnitTemplate.is_hard_target?(template)
    end
  end
end
