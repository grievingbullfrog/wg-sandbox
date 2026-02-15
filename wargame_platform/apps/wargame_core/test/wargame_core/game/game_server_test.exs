defmodule WargameCore.Game.GameServerTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.GameServer
  alias WargameCore.Scenario.{Scenario, ActionProfile}
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.TurnState

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
      id: "test-scenario",
      name: "Test Game",
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
        %{id: "ger2", name: "2nd Infantry", template_id: "inf_template",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 0)},
        %{id: "sov1", name: "1st Rifle", template_id: "inf_template",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(3, 0)},
        %{id: "sov2", name: "2nd Rifle", template_id: "inf_template",
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

  describe "start_link and get_state" do
    test "starts a game from a scenario" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "test-1")

      state = GameServer.get_state(pid)
      assert state.game_id == "test-1"
      assert state.status == :playing
      assert map_size(state.units) == 4
    end

    test "game starts on turn 1 with first side active" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      state = GameServer.get_state(pid)
      assert state.turn_state.turn_number == 1
      assert state.turn_state.active_side == :axis
    end
  end

  describe "perform_action - movement" do
    test "moves a unit to an adjacent hex" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      # Advance past command phase to movement phase
      {:ok, _} = GameServer.end_phase(pid, :axis)

      # Now in movement phase - move ger1 from (0,0) to (1,0)... wait, ger2 is there
      # Move ger1 from (0,0) to (0,1)
      path = [Coord.new(0, 0), Coord.new(0, 1)]
      {:ok, state} = GameServer.perform_action(pid, :axis, {:move, "ger1", path})

      assert state.units["ger1"].position == Coord.new(0, 1)
    end

    test "rejects movement from wrong side" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      # Axis turn - soviet can't move
      {:error, :not_your_turn} = GameServer.perform_action(pid, :allied, {:move, "sov1", [Coord.new(3, 0), Coord.new(3, 1)]})
    end

    test "rejects movement in wrong phase" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      # In command phase, movement should fail
      path = [Coord.new(0, 0), Coord.new(0, 1)]
      {:error, :movement_not_allowed} = GameServer.perform_action(pid, :axis, {:move, "ger1", path})
    end
  end

  describe "perform_action - hold" do
    test "unit can hold position" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      {:ok, state} = GameServer.perform_action(pid, :axis, {:hold, "ger1"})
      assert state.units["ger1"].movement_remaining == 0
    end
  end

  describe "end_phase" do
    test "advances through phases" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      # Start in command phase
      state = GameServer.get_state(pid)
      phase = TurnState.current_phase(state.turn_state)
      assert phase.id == :command

      # Advance to movement
      {:ok, state} = GameServer.end_phase(pid, :axis)
      phase = TurnState.current_phase(state.turn_state)
      assert phase.id == :movement

      # Advance to combat
      {:ok, state} = GameServer.end_phase(pid, :axis)
      phase = TurnState.current_phase(state.turn_state)
      assert phase.id == :combat
    end

    test "rejects end_phase from wrong side" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario)

      {:error, :not_your_turn} = GameServer.end_phase(pid, :allied)
    end
  end

  describe "game_id" do
    test "returns the game id" do
      scenario = test_scenario()
      {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "my-game")

      assert GameServer.game_id(pid) == "my-game"
    end
  end
end
