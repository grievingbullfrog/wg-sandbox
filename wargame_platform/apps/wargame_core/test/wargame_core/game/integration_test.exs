defmodule WargameCore.Game.IntegrationTest do
  @moduledoc """
  Full game loop integration test.

  Plays a mini-game from setup through multiple turns to completion,
  validating the entire pipeline works end-to-end.
  """
  use ExUnit.Case, async: true

  alias WargameCore.Game.GameServer
  alias WargameCore.Scenario.{Scenario, ActionProfile}
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.TurnState

  @infantry_template %UnitTemplate{
    id: "inf", name: "Infantry", nationality: "german", era: "ww2",
    category: :infantry, unit_size: :platoon, icon_type: "infantry",
    attack_soft: 6, attack_hard: 2, defense: 5, armor: 0,
    movement_points: 4, movement_type: :foot, range: 1,
    spotting: 3, initiative: 3, max_strength: 10,
    max_ammo: 10, max_fuel: 0,
    can_bridge: false, can_entrench: true, is_organic_transport: false
  }

  @armor_template %UnitTemplate{
    id: "pz", name: "Panzer IV", nationality: "german", era: "ww2",
    category: :armor, unit_size: :company, icon_type: "armor",
    attack_soft: 4, attack_hard: 12, defense: 8, armor: 6,
    movement_points: 8, movement_type: :tracked, range: 2,
    spotting: 4, initiative: 5, max_strength: 10,
    max_ammo: 8, max_fuel: 12,
    can_bridge: false, can_entrench: false, is_organic_transport: false
  }

  defp make_mini_scenario do
    # 5x5 map with clear terrain
    tiles = for q <- 0..4, r <- 0..4, into: %{} do
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear, victory_points: if(q == 2 && r == 2, do: 10, else: 0))}
    end

    game_map = %WargameCore.Map{
      id: "mini", name: "Mini Map", width: 5, height: 5, scale: "1km", tiles: tiles
    }

    Scenario.new(%{
      id: "mini-game",
      name: "Mini Engagement",
      era: "ww2",
      map: game_map,
      action_profile: ActionProfile.ww2_standard(),
      sides: [
        %{id: :axis, name: "Axis", forces: [:german]},
        %{id: :allied, name: "Allied", forces: [:soviet]}
      ],
      first_move: :axis,
      max_turns: 3,
      templates: %{"inf" => @infantry_template, "pz" => @armor_template},
      scenario_units: [
        # German forces on west side
        %{id: "ger_inf1", name: "1st Ger Infantry", template_id: "inf",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(0, 1)},
        %{id: "ger_inf2", name: "2nd Ger Infantry", template_id: "inf",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(0, 2)},
        %{id: "ger_pz1", name: "1st Panzer", template_id: "pz",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(0, 3)},
        # Soviet forces on east side
        %{id: "sov_inf1", name: "1st Sov Rifle", template_id: "inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(4, 1)},
        %{id: "sov_inf2", name: "2nd Sov Rifle", template_id: "inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(4, 2)},
        %{id: "sov_inf3", name: "3rd Sov Rifle", template_id: "inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(4, 3)}
      ],
      leaders: [
        %{id: "ger_leader", name: "German CO", nationality: "german", era: "ww2",
          rank: :colonel, command_radius: 2, attack_modifier: 1, defense_modifier: 1,
          morale_modifier: 10, initiative_modifier: 1, abilities: [],
          position: Coord.new(0, 2), side: :axis, force: :german}
      ],
      victory_conditions: %{
        type: :victory_points,
        sudden_death_vp: nil,
        vp_levels: %{decisive: 80, tactical: 60, marginal: 40},
        unit_kill_vp: %{armor: 3, infantry: 1, leader: 5}
      },
      weather_schedule: [
        %{turns: 1..2, weather: :clear, ground: :dry},
        %{turns: 3..3, weather: :rain, ground: :mud}
      ],
      supply_sources: [
        %{side: :axis, hex: Coord.new(0, 0)},
        %{side: :allied, hex: Coord.new(4, 4)}
      ],
      reinforcement_mode: :fixed
    })
  end

  # Helper: advance through N phases
  defp advance_phases(pid, side, count) do
    Enum.reduce(1..count, nil, fn _, _ ->
      {:ok, state} = GameServer.end_phase(pid, side)
      state
    end)
  end

  # Helper: skip all remaining phases for a side
  defp skip_remaining_phases(pid, side) do
    state = GameServer.get_state(pid)
    current_index = state.turn_state.current_phase_index
    total_phases = length(state.turn_state.phases)
    remaining = total_phases - current_index
    advance_phases(pid, side, remaining)
  end

  test "full mini-game plays from start to finish" do
    scenario = make_mini_scenario()
    {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "integration-test")

    # --- Verify initial state ---
    state = GameServer.get_state(pid)
    assert state.turn_state.turn_number == 1
    assert state.turn_state.active_side == :axis
    assert map_size(state.units) == 6
    assert map_size(state.leaders) == 1
    assert state.weather == %{weather: :clear, ground: :dry}

    # --- Turn 1: Axis moves ---

    # Skip command phase -> now in movement phase
    {:ok, _} = GameServer.end_phase(pid, :axis)

    state = GameServer.get_state(pid)
    assert TurnState.current_phase(state.turn_state).id == :movement

    # Move infantry forward
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf1", [Coord.new(0, 1), Coord.new(1, 1)]})
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf2", [Coord.new(0, 2), Coord.new(1, 2)]})
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_pz1", [Coord.new(0, 3), Coord.new(1, 3), Coord.new(2, 3)]})

    state = GameServer.get_state(pid)
    assert state.units["ger_inf1"].position == Coord.new(1, 1)
    assert state.units["ger_pz1"].position == Coord.new(2, 3)

    # Skip remaining Axis phases for turn 1
    skip_remaining_phases(pid, :axis)

    # Now should be Allied turn
    state = GameServer.get_state(pid)
    assert state.turn_state.active_side == :allied

    # --- Turn 1: Allied moves ---
    {:ok, _} = GameServer.end_phase(pid, :allied)  # command -> movement

    # Move Soviet forces forward
    {:ok, _} = GameServer.perform_action(pid, :allied, {:move, "sov_inf1", [Coord.new(4, 1), Coord.new(3, 1)]})
    {:ok, _} = GameServer.perform_action(pid, :allied, {:move, "sov_inf2", [Coord.new(4, 2), Coord.new(3, 2)]})
    {:ok, _} = GameServer.perform_action(pid, :allied, {:move, "sov_inf3", [Coord.new(4, 3), Coord.new(3, 3)]})

    state = GameServer.get_state(pid)
    assert state.units["sov_inf1"].position == Coord.new(3, 1)

    # Skip remaining Allied phases
    skip_remaining_phases(pid, :allied)

    # --- Turn 2 starts ---
    state = GameServer.get_state(pid)
    assert state.turn_state.turn_number == 2
    assert state.turn_state.active_side == :axis

    # Movement points should have been reset
    assert state.units["ger_inf1"].movement_remaining == @infantry_template.movement_points

    # --- Turn 2: Axis moves closer and attacks ---
    {:ok, _} = GameServer.end_phase(pid, :axis)  # command -> movement

    # Move units adjacent to enemy
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf1", [Coord.new(1, 1), Coord.new(2, 1)]})
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf2", [Coord.new(1, 2), Coord.new(2, 2)]})

    # Move to combat phase
    {:ok, _} = GameServer.end_phase(pid, :axis)

    state = GameServer.get_state(pid)
    assert TurnState.current_phase(state.turn_state).id == :combat

    # Attack: ger_inf1 (at 2,1) attacks sov_inf1 (at 3,1)
    {:ok, state} = GameServer.perform_action(pid, :axis, {:attack, ["ger_inf1"], Coord.new(3, 1)})

    # Verify combat happened - attacker should be marked
    ger1 = Map.get(state.units, "ger_inf1")
    if ger1, do: assert(ger1.has_attacked == true)

    # Skip remaining Axis phases
    skip_remaining_phases(pid, :axis)

    # Skip Allied turn
    skip_remaining_phases(pid, :allied)

    # --- Turn 3: Final turn ---
    state = GameServer.get_state(pid)
    assert state.turn_state.turn_number == 3

    # Weather should change to rain on turn 3
    assert state.weather == %{weather: :rain, ground: :mud}

    # Skip all remaining phases to end the game
    skip_remaining_phases(pid, :axis)
    skip_remaining_phases(pid, :allied)

    # Game should be finished (max_turns = 3)
    state = GameServer.get_state(pid)
    assert state.status == :finished
    assert state.result != nil
  end

  test "action log tracks all player actions" do
    scenario = make_mini_scenario()
    {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "log-test")

    # Perform some actions
    {:ok, _} = GameServer.end_phase(pid, :axis)  # command -> movement
    {:ok, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf1", [Coord.new(0, 1), Coord.new(1, 1)]})
    {:ok, _} = GameServer.perform_action(pid, :axis, {:hold, "ger_inf2"})

    state = GameServer.get_state(pid)
    assert length(state.action_log) == 2

    # Log entries should have turn, phase, side, action
    entry = hd(state.action_log)
    assert entry.turn == 1
    assert entry.side == :axis
  end

  test "invalid actions don't change state" do
    scenario = make_mini_scenario()
    {:ok, pid} = GameServer.start_link(scenario: scenario, game_id: "invalid-test")

    state_before = GameServer.get_state(pid)

    # Try to move in command phase
    {:error, _} = GameServer.perform_action(pid, :axis, {:move, "ger_inf1", [Coord.new(0, 1), Coord.new(1, 1)]})

    state_after = GameServer.get_state(pid)
    assert state_before.units == state_after.units
    assert state_before.turn_state == state_after.turn_state
  end
end
