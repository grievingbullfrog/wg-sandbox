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

  describe "action profile error paths" do
    test "create_action_profile/1 returns error for missing fields" do
      assert {:error, changeset} = Scenarios.create_action_profile(%{})
      refute changeset.valid?
    end
  end

  describe "action profile update and delete" do
    test "update_action_profile/2 updates" do
      {:ok, profile} =
        Scenarios.create_action_profile(%{
          name: "WW2 Standard",
          era: "ww2",
          actions: %{"options" => []},
          phase_sequence: %{"phases" => ["movement"]},
          rules_module: "Elixir.WargameCore.Rules.StandardRules"
        })

      assert {:ok, updated} = Scenarios.update_action_profile(profile, %{name: "WW2 Revised"})
      assert updated.name == "WW2 Revised"
    end

    test "delete_action_profile/1 deletes" do
      {:ok, profile} =
        Scenarios.create_action_profile(%{
          name: "To Delete",
          era: "ww2",
          actions: %{"options" => []},
          phase_sequence: %{"phases" => []},
          rules_module: "Elixir.WargameCore.Rules.StandardRules"
        })

      assert {:ok, _} = Scenarios.delete_action_profile(profile)
      assert_raise Ecto.NoResultsError, fn -> Scenarios.get_action_profile!(profile.id) end
    end
  end

  describe "scenario CRUD" do
    test "create_scenario/1 creates a scenario" do
      deps = create_dependencies!()
      assert {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))
      assert scenario.name == "Battle of Kursk"
    end

    test "create_scenario/1 returns error for missing fields" do
      assert {:error, changeset} = Scenarios.create_scenario(%{})
      refute changeset.valid?
    end

    test "update_scenario/2 updates" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))
      assert {:ok, updated} = Scenarios.update_scenario(scenario, %{name: "Kursk Revised"})
      assert updated.name == "Kursk Revised"
    end

    test "delete_scenario/1 deletes" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))
      assert {:ok, _} = Scenarios.delete_scenario(scenario)
      assert_raise Ecto.NoResultsError, fn -> Scenarios.get_scenario!(scenario.id) end
    end

    test "list_scenarios/1 filters by era" do
      deps = create_dependencies!()
      {:ok, _} = Scenarios.create_scenario(scenario_attrs(deps))
      assert length(Scenarios.list_scenarios(era: "ww2")) == 1
      assert length(Scenarios.list_scenarios(era: "napoleonic")) == 0
    end

    test "list_scenarios/1 filters by published" do
      deps = create_dependencies!()
      {:ok, _} = Scenarios.create_scenario(Map.put(scenario_attrs(deps), :published, true))
      {:ok, _} = Scenarios.create_scenario(Map.put(scenario_attrs(deps), :name, "Other") |> Map.put(:published, false))
      assert length(Scenarios.list_scenarios(published: true)) == 1
      assert length(Scenarios.list_scenarios(published: false)) == 1
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

    test "batch_create_scenario_units/1 rolls back on invalid entry" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      units_attrs = [
        %{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "Good Unit",
          strength: 10
        },
        # Missing required name field
        %{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "",
          strength: 10
        }
      ]

      assert {:error, _changeset} = Scenarios.batch_create_scenario_units(units_attrs)
      # Transaction rolled back, no units created
      assert Scenarios.list_scenario_units(scenario.id) == []
    end

    test "update_scenario_unit/2 updates" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      {:ok, unit} =
        Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "3rd Panzer",
          strength: 10
        })

      assert {:ok, updated} = Scenarios.update_scenario_unit(unit, %{strength: 8, experience: 3})
      assert updated.strength == 8
      assert updated.experience == 3
    end

    test "delete_scenario_unit/1 deletes" do
      deps = create_dependencies!()
      {:ok, scenario} = Scenarios.create_scenario(scenario_attrs(deps))

      {:ok, unit} =
        Scenarios.create_scenario_unit(%{
          scenario_id: scenario.id,
          unit_template_id: deps.template.id,
          side: "axis",
          force: "german",
          name: "3rd Panzer",
          strength: 10
        })

      assert {:ok, _} = Scenarios.delete_scenario_unit(unit)
      assert Scenarios.list_scenario_units(scenario.id) == []
    end

    test "create_scenario_unit/1 returns error for missing fields" do
      assert {:error, changeset} = Scenarios.create_scenario_unit(%{})
      refute changeset.valid?
    end
  end
end
