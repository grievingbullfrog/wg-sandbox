defmodule WargameCore.Game.AiIntegrationTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.GameServer
  alias WargameCore.Scenario.{Scenario, ActionProfile}
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.TurnState

  # Stub AI that holds all units and ends every phase
  defmodule StubAi do
    def play_turn(game_state, config) do
      side = config.side
      turn_state = game_state.turn_state

      # Only act if we're the active side
      if TurnState.is_active_side?(turn_state, side) do
        generate_phase_actions(game_state, config, turn_state, [])
      else
        []
      end
    end

    defp generate_phase_actions(game_state, config, turn_state, acc) do
      side = config.side
      phase = TurnState.current_phase(turn_state)

      actions =
        if phase.allows_movement do
          game_state.units
          |> Map.values()
          |> Enum.filter(&(&1.side == side and &1.position != nil))
          |> Enum.map(&{:hold, &1.id})
        else
          []
        end

      new_acc = acc ++ actions ++ [:end_phase]

      # Simulate phase advance to see if we should continue
      case TurnState.advance_phase(turn_state) do
        {:ok, next_ts} ->
          if TurnState.is_active_side?(next_ts, side) do
            generate_phase_actions(game_state, config, next_ts, new_acc)
          else
            new_acc
          end

        {:end_of_turn, _} ->
          new_acc

        {:end_of_game, _} ->
          new_acc
      end
    end
  end

  @infantry_template %UnitTemplate{
    id: "inf_template",
    name: "Infantry Platoon",
    nationality: "german",
    era: "ww2",
    category: :infantry,
    unit_size: :platoon,
    icon_type: "infantry",
    attack_soft: 6,
    attack_hard: 2,
    defense: 5,
    armor: 0,
    movement_points: 4,
    movement_type: :foot,
    range: 1,
    spotting: 3,
    initiative: 3,
    max_strength: 10,
    max_ammo: 10,
    max_fuel: 0,
    can_bridge: false,
    can_entrench: true,
    is_organic_transport: false
  }

  defp make_tiles(coords) do
    Enum.into(coords, %{}, fn {q, r} ->
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear)}
    end)
  end

  defp make_map(coords) do
    tiles = make_tiles(coords)
    %WargameCore.Map{
      id: "test-map",
      name: "Test Map",
      width: 5,
      height: 3,
      scale: "1km",
      tiles: tiles
    }
  end

  defp test_scenario do
    coords = for q <- 0..4, r <- 0..2, do: {q, r}
    game_map = make_map(coords)

    Scenario.new(%{
      id: "ai-test-scenario",
      name: "AI Test Game",
      era: "ww2",
      map: game_map,
      action_profile: ActionProfile.ww2_standard(),
      sides: [
        %{id: :axis, name: "Axis", forces: [:german]},
        %{id: :allied, name: "Allied", forces: [:soviet]}
      ],
      first_move: :axis,
      max_turns: 3,
      templates: %{"inf_template" => @infantry_template},
      scenario_units: [
        %{id: "ger1", name: "1st Infantry", template_id: "inf_template",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(0, 0)},
        %{id: "sov1", name: "1st Rifle", template_id: "inf_template",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(4, 0)}
      ],
      leaders: [],
      victory_conditions: %{
        type: :victory_points,
        sudden_death_vp: nil,
        vp_levels: %{decisive: 80, tactical: 60, marginal: 40},
        unit_kill_vp: %{armor: 3, infantry: 1, leader: 5}
      },
      weather_schedule: [%{turns: 1..3, weather: :clear, ground: :dry}],
      supply_sources: [
        %{side: :axis, hex: Coord.new(0, 0)},
        %{side: :allied, hex: Coord.new(4, 0)}
      ],
      reinforcement_mode: :fixed
    })
  end

  describe "AI integration with GameServer" do
    test "AI automatically plays its turn when human ends phase" do
      scenario = test_scenario()
      ai_players = %{allied: %{module: StubAi, difficulty: :hard, personality: :balanced}}

      {:ok, pid} = GameServer.start_link(
        scenario: scenario,
        game_id: "ai-test-1",
        ai_players: ai_players
      )

      # Game starts - axis (human) is active
      state = GameServer.get_state(pid)
      assert state.turn_state.active_side == :axis
      assert state.turn_state.turn_number == 1

      # Human (axis) plays through all 6 phases
      {:ok, _} = GameServer.end_phase(pid, :axis)  # command → movement
      {:ok, _} = GameServer.end_phase(pid, :axis)  # movement → combat
      {:ok, _} = GameServer.end_phase(pid, :axis)  # combat → exploitation
      {:ok, _} = GameServer.end_phase(pid, :axis)  # exploitation → supply
      {:ok, _} = GameServer.end_phase(pid, :axis)  # supply → end_phase

      # After the last axis phase, allied (AI) becomes active
      # GameServer should auto-execute the AI turn
      {:ok, state} = GameServer.end_phase(pid, :axis)  # end_phase → allied turn → AI plays → back to axis

      # After AI plays all its phases, it should be turn 2 with axis active
      assert state.turn_state.turn_number == 2
      assert state.turn_state.active_side == :axis
    end

    test "AI actions are logged" do
      scenario = test_scenario()
      ai_players = %{allied: %{module: StubAi, difficulty: :hard, personality: :balanced}}

      {:ok, pid} = GameServer.start_link(
        scenario: scenario,
        game_id: "ai-test-2",
        ai_players: ai_players
      )

      # Play through axis turn
      for _ <- 1..6 do
        {:ok, _} = GameServer.end_phase(pid, :axis)
      end

      state = GameServer.get_state(pid)

      # AI should have logged hold actions
      ai_actions = Enum.filter(state.action_log, &(&1.side == :allied))
      assert length(ai_actions) > 0
    end

    test "game works without AI players (default)" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "no-ai-test")

      state = GameServer.get_state(pid)
      assert state.turn_state.active_side == :axis

      # End axis phases - allied should become active (no AI)
      for _ <- 1..6 do
        {:ok, _} = GameServer.end_phase(pid, :axis)
      end

      state = GameServer.get_state(pid)
      assert state.turn_state.active_side == :allied
    end

    test "AI plays when game starts with AI side first" do
      # Create scenario where allied goes first, and allied is AI
      scenario = test_scenario()
      # Override first_move to be allied
      scenario = %{scenario | first_move: :allied}

      ai_players = %{allied: %{module: StubAi, difficulty: :hard, personality: :balanced}}

      {:ok, pid} = GameServer.start_link(
        scenario: scenario,
        game_id: "ai-first-test",
        ai_players: ai_players
      )

      # AI should have already played - axis (human) should be active
      state = GameServer.get_state(pid)
      # After AI plays all allied phases, axis should be active in turn 1
      assert state.turn_state.active_side == :axis
      assert state.turn_state.turn_number == 1
    end

    test "both sides as AI plays through turns" do
      scenario = test_scenario()
      ai_players = %{
        axis: %{module: StubAi, difficulty: :hard, personality: :balanced},
        allied: %{module: StubAi, difficulty: :easy, personality: :aggressive}
      }

      {:ok, pid} = GameServer.start_link(
        scenario: scenario,
        game_id: "full-ai-test",
        ai_players: ai_players
      )

      # Both sides are AI - game should have played through to max turns
      state = GameServer.get_state(pid)
      # With max_turns: 3, the game should have ended
      assert state.status == :finished || state.turn_state.turn_number > 1
    end
  end
end
