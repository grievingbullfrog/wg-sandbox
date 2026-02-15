defmodule WargamePersistence.ScenariosTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.{Scenarios, Maps, Units}

  defp create_dependencies! do
    {:ok, map} = Maps.create_map(%{name: "Test Map", width: 10, height: 10})

    {:ok, profile} =
      Scenarios.create_action_profile(%{
        name: "WW2 Standard",
        era: "ww2",
        actions: %{"options" => []},
        phase_sequence: %{"phases" => ["movement", "combat"]},
        rules_module: "Elixir.WargameCore.Rules.StandardRules"
      })

    {:ok, template} =
      Units.create_unit_template(%{
        name: "Panzer IV",
        nationality: "german",
        era: "ww2",
        category: "armor",
        unit_size: "platoon",
        stats: %{"attack_soft" => 8}
      })

    %{map: map, profile: profile, template: template}
  end

  defp scenario_attrs(%{map: map, profile: profile}) do
    %{
      name: "Battle of Kursk",
      era: "ww2",
      max_turns: 12,
      first_move: "axis",
      map_id: map.id,
      action_profile_id: profile.id,
      sides: %{
        "sides" => [
          %{"id" => "axis", "name" => "Axis", "forces" => ["german"]},
          %{"id" => "allied", "name" => "Allied", "forces" => ["soviet"]}
        ]
      },
      victory_conditions: %{"type" => "victory_points"}
    }
  end

  describe "action profile CRUD" do
    test "create and list action profiles" do
      {:ok, _} =
        Scenarios.create_action_profile(%{
          name: "WW2 Standard",
          era: "ww2",
          actions: %{"options" => []},
          phase_sequence: %{"phases" => ["movement"]},
          rules_module: "Elixir.WargameCore.Rules.StandardRules"
        })

      assert length(Scenarios.list_action_profiles()) == 1
      assert length(Scenarios.list_action_profiles(era: "ww2")) == 1
      assert length(Scenarios.list_action_profiles(era: "napoleonic")) == 0
    end
  end

  describe "scenario CRUD" do
    test "create_scenario/1 creates a scenario" do
      deps = create_dependencies!()
      assert {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))
      assert scenario.name == "Battle of Kursk"
    end

    test "list_scenarios/0 returns all scenarios" do
      deps = create_dependencies!()
      {:ok, _} = Scenarios.create_scenario(scenario_attrs(deps))
      assert length(Scenarios.list_scenarios()) == 1
    end

    test "load_full_scenario/1 preloads associations" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      {:ok, _unit} =
        Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "3rd Panzer",
          strength: 10
        })

      loaded = Scenarios.load_full_scenario(scenario.id)
      assert loaded != nil
      assert loaded.map.name == "Test Map"
      assert loaded.action_profile.name == "WW2 Standard"
      assert length(loaded.scenario_units) == 1
      assert hd(loaded.scenario_units).unit_template.name == "Panzer IV"
    end

    test "load_full_scenario/1 returns nil for missing" do
      assert Scenarios.load_full_scenario(Ecto.UUID.generate()) == nil
    end
  end

  describe "scenario units" do
    test "create and list scenario units" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      {:ok, unit} =
        Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "3rd Panzer",
          strength: 10,
          experience: 3,
          morale: 70
        })

      assert unit.name == "3rd Panzer"

      units = Scenarios.list_scenario_units(scenario.id)
      assert length(units) == 1
    end

    test "batch_create_scenario_units/1 creates multiple" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      units_attrs =
        Enum.map(1..3, fn i ->
          %{
            scenario_id: scenario.id,
            unit_template_id: deps.template.id,
            side: "axis",
            force: "german",
            name: "Unit #{i}",
            strength: 10
          }
        end)

      assert {:ok, units} = Scenarios.batch_create_scenario_units(units_attrs)
      assert length(units) == 3
    end
  end
end
