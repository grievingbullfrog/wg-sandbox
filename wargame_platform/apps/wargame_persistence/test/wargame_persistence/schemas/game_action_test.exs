defmodule WargamePersistence.Schemas.GameActionTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.{GameAction, Game, Scenario, ActionProfile}
  alias WargamePersistence.Schemas.Map, as: MapSchema

  defp create_game! do
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

    scenario =
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

    %Game{}
    |> Game.changeset(%{
      scenario_id: scenario.id,
      players: %{"axis" => "human"},
      settings: %{}
    })
    |> Repo.insert!()
  end

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      game = create_game!()

      changeset =
        GameAction.changeset(%GameAction{}, %{
          game_id: game.id,
          turn: 1,
          phase: "movement",
          side: "axis",
          sequence: 0,
          action: %{"type" => "move", "unit_id" => "abc", "target" => %{"q" => 3, "r" => 4}}
        })

      assert changeset.valid?
    end

    test "requires all fields" do
      changeset = GameAction.changeset(%GameAction{}, %{})
      refute changeset.valid?

      errors = errors_on(changeset)
      assert errors[:game_id]
      assert errors[:turn]
      assert errors[:phase]
      assert errors[:side]
      assert errors[:sequence]
    end

    test "rejects nil action" do
      game = create_game!()

      changeset =
        GameAction.changeset(%GameAction{}, %{
          game_id: game.id,
          turn: 1,
          phase: "movement",
          side: "axis",
          sequence: 0,
          action: nil
        })

      refute changeset.valid?
    end

    test "can insert and retrieve actions" do
      game = create_game!()

      {:ok, action} =
        %GameAction{}
        |> GameAction.changeset(%{
          game_id: game.id,
          turn: 1,
          phase: "movement",
          side: "axis",
          sequence: 0,
          action: %{"type" => "move"}
        })
        |> Repo.insert()

      loaded = Repo.get!(GameAction, action.id)
      assert loaded.turn == 1
      assert loaded.phase == "movement"
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
