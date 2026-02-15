defmodule WargamePersistence.UnitsTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Units

  @template_attrs %{
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: "armor",
    unit_size: "platoon",
    stats: %{"attack_soft" => 8, "attack_hard" => 12, "defense" => 10}
  }

  @leader_attrs %{
    name: "Heinz Guderian",
    nationality: "german",
    era: "ww2",
    rank: "general",
    command_radius: 4,
    is_historical: true,
    modifiers: %{"attack_modifier" => 2, "defense_modifier" => 1}
  }

  describe "unit template CRUD" do
    test "create_unit_template/1 creates a template" do
      assert {:ok, template} = Units.create_unit_template(@template_attrs)
      assert template.name == "Panzer IV"
      assert template.category == "armor"
    end

    test "get_unit_template!/1 returns the template" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert Units.get_unit_template!(template.id).name == "Panzer IV"
    end

    test "update_unit_template/2 updates" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert {:ok, updated} = Units.update_unit_template(template, %{name: "Panzer IV Ausf. H"})
      assert updated.name == "Panzer IV Ausf. H"
    end

    test "delete_unit_template/1 deletes" do
      {:ok, template} = Units.create_unit_template(@template_attrs)
      assert {:ok, _} = Units.delete_unit_template(template)
      assert Units.get_unit_template(template.id) == nil
    end

    test "list_unit_templates/1 with filters" do
      {:ok, _} = Units.create_unit_template(@template_attrs)

      {:ok, _} =
        Units.create_unit_template(%{
          @template_attrs
          | name: "Rifle Platoon",
            nationality: "soviet",
            category: "infantry"
        })

      assert length(Units.list_unit_templates()) == 2
      assert length(Units.list_unit_templates(nationality: "german")) == 1
      assert length(Units.list_unit_templates(category: "infantry")) == 1
      assert length(Units.list_unit_templates(era: "ww2")) == 2
    end
  end

  describe "unit template error paths" do
    test "create_unit_template/1 returns error for missing fields" do
      assert {:error, changeset} = Units.create_unit_template(%{})
      refute changeset.valid?
    end

    test "create_unit_template/1 returns error for invalid category" do
      assert {:error, changeset} =
               Units.create_unit_template(%{@template_attrs | category: "invalid"})

      refute changeset.valid?
    end
  end

  describe "list_unit_templates_for_scenario/1" do
    test "returns templates used by a scenario" do
      {:ok, template1} = Units.create_unit_template(@template_attrs)

      {:ok, template2} =
        Units.create_unit_template(%{
          @template_attrs
          | name: "Rifle Platoon",
            nationality: "soviet",
            category: "infantry"
        })

      {:ok, _unused} =
        Units.create_unit_template(%{@template_attrs | name: "Tiger I"})

      {:ok, map} =
        WargamePersistence.Maps.create_map(%{name: "Test Map", width: 10, height: 10})

      {:ok, profile} =
        WargamePersistence.Scenarios.create_action_profile(%{
          name: "WW2",
          era: "ww2",
          actions: %{"options" => []},
          phase_sequence: %{"phases" => ["movement"]},
          rules_module: "Elixir.WargameCore.Rules.StandardRules"
        })

      {:ok, scenario} =
        WargamePersistence.Scenarios.create_scenario(%{
          name: "Test",
          era: "ww2",
          max_turns: 10,
          first_move: "axis",
          map_id: map.id,
          action_profile_id: profile.id,
          sides: %{"sides" => []},
          victory_conditions: %{"type" => "victory_points"}
        })

      {:ok, _} =
        WargamePersistence.Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: template1.id,
          side: "axis",
          force: "german",
          name: "Unit A",
          strength: 10
        })

      {:ok, _} =
        WargamePersistence.Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: template2.id,
          side: "allied",
          force: "soviet",
          name: "Unit B",
          strength: 10
        })

      templates = Units.list_unit_templates_for_scenario(scenario.id)
      assert length(templates) == 2
      names = Enum.map(templates, & &1.name) |> Enum.sort()
      assert names == ["Panzer IV", "Rifle Platoon"]
    end

    test "returns empty list for scenario with no units" do
      assert Units.list_unit_templates_for_scenario(Ecto.UUID.generate()) == []
    end
  end

  describe "leader error paths" do
    test "create_leader/1 returns error for missing fields" do
      assert {:error, changeset} = Units.create_leader(%{})
      refute changeset.valid?
    end

    test "create_leader/1 returns error for invalid rank" do
      assert {:error, changeset} =
               Units.create_leader(%{@leader_attrs | rank: "invalid"})

      refute changeset.valid?
    end
  end

  describe "leader CRUD" do
    test "create_leader/1 creates a leader" do
      assert {:ok, leader} = Units.create_leader(@leader_attrs)
      assert leader.name == "Heinz Guderian"
      assert leader.rank == "general"
    end

    test "get_leader!/1 returns the leader" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert Units.get_leader!(leader.id).name == "Heinz Guderian"
    end

    test "update_leader/2 updates" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert {:ok, updated} = Units.update_leader(leader, %{command_radius: 5})
      assert updated.command_radius == 5
    end

    test "delete_leader/1 deletes" do
      {:ok, leader} = Units.create_leader(@leader_attrs)
      assert {:ok, _} = Units.delete_leader(leader)
      assert Units.get_leader(leader.id) == nil
    end

    test "list_leaders/1 with filters" do
      {:ok, _} = Units.create_leader(@leader_attrs)

      {:ok, _} =
        Units.create_leader(%{
          @leader_attrs
          | name: "Zhukov",
            nationality: "soviet",
            rank: "field_marshal",
            command_radius: 6
        })

      assert length(Units.list_leaders()) == 2
      assert length(Units.list_leaders(nationality: "german")) == 1
      assert length(Units.list_leaders(rank: "general")) == 1
      assert length(Units.list_leaders(is_historical: true)) == 2
    end
  end
end
