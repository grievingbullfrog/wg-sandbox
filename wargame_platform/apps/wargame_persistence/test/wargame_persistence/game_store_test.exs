defmodule WargamePersistence.GameStoreTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.{GameStore, Scenarios, Maps}

  defp create_game! do
    {:ok, map} = Maps.create_map(%{name: "Test Map", width: 10, height: 10})

    {:ok, profile} =
      Scenarios.create_action_profile(%{
        name: "WW2 Standard",
        era: "ww2",
        actions: %{"options" => []},
        phase_sequence: %{"phases" => ["movement"]},
        rules_module: "Elixir.WargameCore.Rules.StandardRules"
      })

    {:ok, scenario} =
      Scenarios.create_scenario(%{
        name: "Test Scenario",
        era: "ww2",
        max_turns: 10,
        first_move: "axis",
        map_id: map.id,
        action_profile_id: profile.id,
        sides: %{"sides" => []},
        victory_conditions: %{"type" => "victory_points"}
      })

    {:ok, game} =
      GameStore.create_game(%{
        scenario_id: scenario.id,
        players: %{"axis" => "human", "allied" => "ai"},
        settings: %{"fog_of_war" => "full"}
      })

    game
  end

  describe "game CRUD" do
    test "create_game/1 creates a game" do
      game = create_game!()
      assert game.status == "setup"
      assert game.players["axis"] == "human"
    end

    test "list_games/0 returns all games" do
      _game = create_game!()
      assert length(GameStore.list_games()) == 1
    end

    test "list_games/1 filters by status" do
      _game = create_game!()
      assert length(GameStore.list_games(status: "setup")) == 1
      assert length(GameStore.list_games(status: "playing")) == 0
    end
  end

  describe "game state persistence" do
    test "save_game_state/2 and load_game_state/1 round-trip" do
      game = create_game!()

      state = %{
        units: %{"unit1" => %{position: {3, 4}, strength: 10}},
        turn: 5,
        weather: :clear
      }

      assert {:ok, _updated} = GameStore.save_game_state(game, state)
      loaded = GameStore.load_game_state(game.id)
      assert loaded == state
    end

    test "load_game_state/1 returns nil for missing" do
      assert GameStore.load_game_state(Ecto.UUID.generate()) == nil
    end
  end

  describe "finish_game/2" do
    test "sets result and finished_at" do
      game = create_game!()
      result = %{"winner" => "axis", "reason" => "victory_points", "score" => 85}

      assert {:ok, finished} = GameStore.finish_game(game, result)
      assert finished.status == "finished"
      assert finished.result == result
      assert finished.finished_at != nil
    end
  end

  describe "action log" do
    test "log_action/2 and get_action_log/1" do
      game = create_game!()

      {:ok, _} =
        GameStore.log_action(game.id, %{
          turn: 1,
          phase: "movement",
          side: "axis",
          sequence: 0,
          action: %{"type" => "move", "unit_id" => "abc"}
        })

      {:ok, _} =
        GameStore.log_action(game.id, %{
          turn: 1,
          phase: "movement",
          side: "axis",
          sequence: 1,
          action: %{"type" => "move", "unit_id" => "def"}
        })

      log = GameStore.get_action_log(game.id)
      assert length(log) == 2
      assert hd(log).sequence == 0
    end
  end
end
