defmodule WargamePersistence.Schemas.ScenarioTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.{Scenario, ActionProfile}
  alias WargamePersistence.Schemas.Map, as: MapSchema

  defp create_map! do
    %MapSchema{}
    |> MapSchema.changeset(%{name: "Test Map", width: 10, height: 10})
    |> Repo.insert!()
  end

  defp create_action_profile! do
    %ActionProfile{}
    |> ActionProfile.changeset(%{
      name: "WW2 Standard",
      era: "ww2",
      actions: %{"options" => []},
      phase_sequence: %{"phases" => ["movement", "combat"]},
      rules_module: "Elixir.WargameCore.Rules.StandardRules"
    })
    |> Repo.insert!()
  end

  defp valid_attrs(map, profile) do
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
      victory_conditions: %{"type" => "victory_points", "vp_levels" => %{"decisive" => 80}}
    }
  end

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      map = create_map!()
      profile = create_action_profile!()
      changeset = Scenario.changeset(%Scenario{}, valid_attrs(map, profile))
      assert changeset.valid?
    end

    test "requires name" do
      map = create_map!()
      profile = create_action_profile!()
      changeset = Scenario.changeset(%Scenario{}, Map.delete(valid_attrs(map, profile), :name))
      refute changeset.valid?
    end

    test "requires max_turns" do
      map = create_map!()
      profile = create_action_profile!()
      changeset = Scenario.changeset(%Scenario{}, Map.delete(valid_attrs(map, profile), :max_turns))
      refute changeset.valid?
    end

    test "validates max_turns > 0" do
      map = create_map!()
      profile = create_action_profile!()
      changeset = Scenario.changeset(%Scenario{}, %{valid_attrs(map, profile) | max_turns: 0})
      refute changeset.valid?
    end

    test "validates reinforcement_mode inclusion" do
      map = create_map!()
      profile = create_action_profile!()

      changeset =
        Scenario.changeset(
          %Scenario{},
          Map.put(valid_attrs(map, profile), :reinforcement_mode, "invalid")
        )

      refute changeset.valid?
    end

    test "accepts valid reinforcement modes" do
      map = create_map!()
      profile = create_action_profile!()

      for mode <- ~w(fixed variable conditional) do
        changeset =
          Scenario.changeset(
            %Scenario{},
            Map.put(valid_attrs(map, profile), :reinforcement_mode, mode)
          )

        assert changeset.valid?, "expected reinforcement_mode #{mode} to be valid"
      end
    end

    test "can insert and retrieve a scenario" do
      map = create_map!()
      profile = create_action_profile!()

      {:ok, scenario} =
        %Scenario{}
        |> Scenario.changeset(valid_attrs(map, profile))
        |> Repo.insert()

      loaded = Repo.get!(Scenario, scenario.id)
      assert loaded.name == "Battle of Kursk"
      assert loaded.map_id == map.id
    end
  end
end
