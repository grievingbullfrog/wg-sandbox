defmodule WargameCore.Game.Actions.PhaseManagementTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.Actions.PhaseManagement
  alias WargameCore.Units.{UnitTemplate, UnitInstance}
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.{Phase, TurnState}

  @infantry_template %UnitTemplate{
    id: "inf_template", name: "Infantry", nationality: "german", era: "ww2",
    category: :infantry, unit_size: :platoon, icon_type: "infantry",
    attack_soft: 6, attack_hard: 2, defense: 5, armor: 0,
    movement_points: 4, movement_type: :foot, range: 1,
    spotting: 3, initiative: 3, max_strength: 10,
    max_ammo: 10, max_fuel: 0,
    can_bridge: false, can_entrench: true, is_organic_transport: false
  }

  defp make_state(opts \\ []) do
    tiles = for q <- 0..4, r <- 0..2, into: %{} do
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear)}
    end

    game_map = %WargameCore.Map{
      id: "test", name: "Test", width: 5, height: 3, scale: "1km", tiles: tiles
    }

    phases = [
      Phase.new(:command, "Command", 0, allows_orders: true),
      Phase.new(:movement, "Movement", 1, allows_movement: true),
      Phase.new(:combat, "Combat", 2, allows_combat: true),
      Phase.new(:end_phase, "End", 3)
    ]

    max_turns = Keyword.get(opts, :max_turns, 5)
    turn_state = TurnState.new(phases, [:axis, :allied], max_turns: max_turns)

    units = %{
      "ger1" => UnitInstance.new(@infantry_template, %{
        id: "ger1", name: "1st Infantry", side: :axis, force: :german,
        position: Coord.new(0, 0)
      }),
      "sov1" => UnitInstance.new(@infantry_template, %{
        id: "sov1", name: "1st Rifle", side: :allied, force: :soviet,
        position: Coord.new(4, 0)
      })
    }

    %{
      map: game_map,
      tiles: tiles,
      units: units,
      turn_state: turn_state,
      rules_module: WargameCore.Rules.StandardRules,
      leaders: %{},
      sides: [:axis, :allied],
      weather: %{weather: :clear, ground: :dry},
      weather_schedule: [
        %{turns: 1..2, weather: :clear, ground: :dry},
        %{turns: 3..5, weather: :rain, ground: :mud}
      ],
      supply_sources: [
        %{side: :axis, hex: Coord.new(0, 0)},
        %{side: :allied, hex: Coord.new(4, 0)}
      ],
      supply_cache: %{},
      victory_conditions: %{
        type: :victory_points,
        sudden_death_vp: nil,
        vp_levels: %{},
        unit_kill_vp: %{}
      },
      reinforcement_mode: :fixed,
      pending_reinforcements: Keyword.get(opts, :pending_reinforcements, []),
      templates: %{"inf_template" => @infantry_template},
      status: :playing,
      result: nil
    }
  end

  describe "advance_phase/1" do
    test "advances from command to movement phase" do
      state = make_state()
      new_state = PhaseManagement.advance_phase(state)

      phase = TurnState.current_phase(new_state.turn_state)
      assert phase.id == :movement
    end

    test "advances through all phases for one side then switches" do
      state = make_state()

      # Command -> Movement -> Combat -> End -> next side's Command
      state = PhaseManagement.advance_phase(state)
      assert TurnState.current_phase(state.turn_state).id == :movement
      assert state.turn_state.active_side == :axis

      state = PhaseManagement.advance_phase(state)
      assert TurnState.current_phase(state.turn_state).id == :combat

      state = PhaseManagement.advance_phase(state)
      assert TurnState.current_phase(state.turn_state).id == :end_phase

      # End phase -> switches to allied side
      state = PhaseManagement.advance_phase(state)
      assert state.turn_state.active_side == :allied
      assert TurnState.current_phase(state.turn_state).id == :command
    end

    test "advances turn after both sides complete all phases" do
      state = make_state()

      # Go through all phases for both sides
      # Axis: 4 phases
      state = Enum.reduce(1..4, state, fn _, s -> PhaseManagement.advance_phase(s) end)
      assert state.turn_state.active_side == :allied

      # Allied: 4 phases -> new turn
      state = Enum.reduce(1..4, state, fn _, s -> PhaseManagement.advance_phase(s) end)
      assert state.turn_state.turn_number == 2
      assert state.turn_state.active_side == :axis
    end
  end

  describe "on_turn_start/1" do
    test "advances weather based on schedule" do
      state = make_state()
      # Simulate turn 3 where weather changes to rain
      state = %{state | turn_state: %{state.turn_state | turn_number: 3}}

      new_state = PhaseManagement.on_turn_start(state)
      assert new_state.weather == %{weather: :rain, ground: :mud}
    end

    test "resets unit turn state" do
      state = make_state()
      # Exhaust a unit's movement
      unit = %{state.units["ger1"] | movement_remaining: 0, has_attacked: true}
      state = %{state | units: Map.put(state.units, "ger1", unit)}

      new_state = PhaseManagement.on_turn_start(state)
      assert new_state.units["ger1"].movement_remaining == @infantry_template.movement_points
      assert new_state.units["ger1"].has_attacked == false
    end

    test "calculates supply for all sides" do
      state = make_state()
      new_state = PhaseManagement.on_turn_start(state)

      assert Map.has_key?(new_state.supply_cache, "ger1")
      assert Map.has_key?(new_state.supply_cache, "sov1")
    end

    test "deploys reinforcements" do
      reinf = [%{
        id: "reinf1", name: "Reinforcement", template_id: "inf_template",
        side: :axis, force: :german, arrives_turn: 2,
        deploy_hex: Coord.new(0, 1)
      }]

      state = make_state(pending_reinforcements: reinf)
      state = %{state | turn_state: %{state.turn_state | turn_number: 2}}

      new_state = PhaseManagement.on_turn_start(state)

      assert Map.has_key?(new_state.units, "reinf1")
      assert new_state.units["reinf1"].position == Coord.new(0, 1)
      assert new_state.pending_reinforcements == []
    end
  end

  describe "on_turn_end/1" do
    test "checks victory conditions" do
      state = make_state()
      # Game shouldn't end on normal turn
      new_state = PhaseManagement.on_turn_end(state)
      assert new_state.status == :playing
    end
  end

  describe "game over" do
    test "game ends when max turns reached" do
      state = make_state(max_turns: 1)

      # Go through all phases for both sides to trigger end of game
      state = Enum.reduce(1..4, state, fn _, s -> PhaseManagement.advance_phase(s) end)
      # Allied turn
      state = Enum.reduce(1..4, state, fn _, s -> PhaseManagement.advance_phase(s) end)

      assert state.status == :finished
      assert state.result != nil
    end
  end
end
