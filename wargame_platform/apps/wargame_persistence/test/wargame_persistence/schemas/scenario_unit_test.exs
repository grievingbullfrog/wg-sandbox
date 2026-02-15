defmodule WargamePersistence.Schemas.ScenarioUnitTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.{ScenarioUnit, Scenario, ActionProfile, UnitTemplate, Leader}
  alias WargamePersistence.Schemas.Map, as: MapSchema

  defp create_dependencies! do
    map =
      %MapSchema{}
      |> MapSchema.changeset(%{name: "Test Map", width: 10, height: 10})
      |> Repo.insert!()

    profile =
      %ActionProfile{}
      |> ActionProfile.changeset(%{
        name: "WW2 Standard",
        era: "ww2",
        actions: %{"options" => []},
        phase_sequence: %{"phases" => ["movement"]},
        rules_module: "Elixir.WargameCore.Rules.StandardRules"
      })
      |> Repo.insert!()

    scenario =
      %Scenario{}
      |> Scenario.changeset(%{
        name: "Test",
        era: "ww2",
        max_turns: 10,
        first_move: "axis",
        map_id: map.id,
        action_profile_id: profile.id,
        sides: %{"sides" => []},
        victory_conditions: %{"type" => "victory_points"}
      })
      |> Repo.insert!()

    template =
      %UnitTemplate{}
      |> UnitTemplate.changeset(%{
        name: "Panzer IV",
        nationality: "german",
        era: "ww2",
        category: "armor",
        unit_size: "platoon",
        stats: %{"attack_soft" => 8}
      })
      |> Repo.insert!()

    leader =
      %Leader{}
      |> Leader.changeset(%{
        name: "Guderian",
        nationality: "german",
        era: "ww2",
        rank: "general",
        command_radius: 4,
        modifiers: %{"attack_modifier" => 2}
      })
      |> Repo.insert!()

    %{scenario: scenario, template: template, leader: leader}
  end

  defp valid_attrs(%{scenario: scenario, template: template}) do
    %{
      scenario_id: scenario.id,
      unit_template_id: template.id,
      side: "axis",
      force: "german",
      name: "3rd Panzer Division",
      strength: 10
    }
  end

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, valid_attrs(deps))
      assert changeset.valid?
    end

    test "requires scenario_id" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :scenario_id))
      refute changeset.valid?
    end

    test "requires unit_template_id" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :unit_template_id))
      refute changeset.valid?
    end

    test "requires side" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :side))
      refute changeset.valid?
    end

    test "requires force" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :force))
      refute changeset.valid?
    end

    test "requires name" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :name))
      refute changeset.valid?
    end

    test "requires strength" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.delete(valid_attrs(deps), :strength))
      refute changeset.valid?
    end

    test "validates strength > 0" do
      deps = create_dependencies!()
      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, %{valid_attrs(deps) | strength: 0})
      refute changeset.valid?
    end

    test "validates experience 0..5" do
      deps = create_dependencies!()

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :experience, -1))
      refute changeset.valid?

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :experience, 6))
      refute changeset.valid?

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :experience, 3))
      assert changeset.valid?
    end

    test "validates morale 0..100" do
      deps = create_dependencies!()

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :morale, -1))
      refute changeset.valid?

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :morale, 101))
      refute changeset.valid?

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :morale, 75))
      assert changeset.valid?
    end

    test "validates arrives_turn >= 1" do
      deps = create_dependencies!()

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :arrives_turn, 0))
      refute changeset.valid?

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, Map.put(valid_attrs(deps), :arrives_turn, 3))
      assert changeset.valid?
    end

    test "accepts optional fields" do
      deps = create_dependencies!()

      attrs =
        valid_attrs(deps)
        |> Map.merge(%{
          leader_id: deps.leader.id,
          position_q: 5,
          position_r: 3,
          arrives_turn: 2,
          deploy_zone: "map_edge_west",
          experience: 4,
          morale: 80,
          attachment_ids: %{"ids" => ["some-uuid"]},
          reinforcement_config: %{"probability" => 80, "earliest" => 2, "latest" => 5}
        })

      changeset = ScenarioUnit.changeset(%ScenarioUnit{}, attrs)
      assert changeset.valid?
    end

    test "can insert and retrieve" do
      deps = create_dependencies!()

      {:ok, unit} =
        %ScenarioUnit{}
        |> ScenarioUnit.changeset(valid_attrs(deps))
        |> Repo.insert()

      loaded = Repo.get!(ScenarioUnit, unit.id)
      assert loaded.name == "3rd Panzer Division"
      assert loaded.strength == 10
      assert loaded.scenario_id == deps.scenario.id
    end
  end
end
