defmodule WargamePersistence.Schemas.GameTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.{Game, Scenario, ActionProfile}
  alias WargamePersistence.Schemas.Map, as: MapSchema

  defp create_scenario! do
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
        phase_sequence: %{"phases" => ["movement", "combat"]},
        rules_module: "Elixir.WargameCore.Rules.StandardRules"
      })
      |> Repo.insert!()

    %Scenario{}
    |> Scenario.changeset(%{
      name: "Test Scenario",
      era: "ww2",
      max_turns: 10,
      first_move: "axis",
      map_id: map.id,
      action_profile_id: profile.id,
      sides: %{"sides" => []},
      victory_conditions: %{"type" => "victory_points"}
    })
    |> Repo.insert!()
  end

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      scenario = create_scenario!()

      changeset =
        Game.changeset(%Game{}, %{
          scenario_id: scenario.id,
          players: %{"axis" => "human", "allied" => "ai"},
          settings: %{"fog_of_war" => "full", "ai_difficulty" => "veteran"}
        })

      assert changeset.valid?
    end

    test "requires scenario_id" do
      changeset =
        Game.changeset(%Game{}, %{
          players: %{"axis" => "human"},
          settings: %{}
        })

      refute changeset.valid?
    end

    test "validates status inclusion" do
      scenario = create_scenario!()

      changeset =
        Game.changeset(%Game{}, %{
          scenario_id: scenario.id,
          players: %{},
          settings: %{},
          status: "invalid"
        })

      refute changeset.valid?
    end

    test "accepts all valid statuses" do
      scenario = create_scenario!()

      for status <- ~w(setup playing paused finished) do
        changeset =
          Game.changeset(%Game{}, %{
            scenario_id: scenario.id,
            players: %{},
            settings: %{},
            status: status
          })

        assert changeset.valid?, "expected status #{status} to be valid"
      end
    end
  end

  describe "serialize/deserialize game_state" do
    test "round-trips game state" do
      state = %{
        units: %{"unit1" => %{position: {3, 4}, strength: 10}},
        turn: 5
      }

      binary = Game.serialize_game_state(state)
      assert is_binary(binary)

      result = Game.deserialize_game_state(binary)
      assert result == state
    end

    test "deserialize nil returns nil" do
      assert Game.deserialize_game_state(nil) == nil
    end
  end
end
