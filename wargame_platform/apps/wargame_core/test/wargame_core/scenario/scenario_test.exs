defmodule WargameCore.Scenario.ScenarioTest do
  use ExUnit.Case, async: true

  alias WargameCore.Scenario.Scenario
  alias WargameCore.Scenario.ActionProfile
  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile
  alias WargameCore.Units.UnitTemplate
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

  @panzer_template %UnitTemplate{
    id: "pz_template",
    name: "Panzer IV",
    nationality: "german",
    era: "ww2",
    category: :armor,
    unit_size: :company,
    icon_type: "armor",
    attack_soft: 4,
    attack_hard: 12,
    defense: 8,
    armor: 6,
    movement_points: 8,
    movement_type: :tracked,
    range: 2,
    spotting: 4,
    initiative: 5,
    max_strength: 10,
    max_ammo: 8,
    max_fuel: 12,
    can_bridge: false,
    can_entrench: false,
    is_organic_transport: false
  }

  defp make_tiles(coords) do
    Enum.into(coords, %{}, fn {q, r} ->
      coord = Coord.new(q, r)
      {coord, Tile.new(coord, :clear)}
    end)
  end

  defp test_scenario(overrides \\ %{}) do
    tiles = make_tiles([{0, 0}, {1, 0}, {2, 0}, {3, 0}, {4, 0},
                        {0, 1}, {1, 1}, {2, 1}, {3, 1}, {4, 1}])

    defaults = %{
      id: "test-scenario-1",
      name: "Test Engagement",
      description: "A test scenario",
      era: "ww2",
      map: %{tiles: tiles},
      action_profile: ActionProfile.ww2_standard(),
      sides: [
        %{id: :axis, name: "Axis", forces: [:german]},
        %{id: :allied, name: "Allied", forces: [:soviet]}
      ],
      first_move: :axis,
      max_turns: 5,
      date_start: "1943-07-05",
      date_per_turn: :day,
      templates: %{
        "inf_template" => @infantry_template,
        "pz_template" => @panzer_template
      },
      scenario_units: [
        %{id: "ger_inf_1", name: "1st Infantry", template_id: "inf_template",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(0, 0)},
        %{id: "ger_pz_1", name: "1st Panzer", template_id: "pz_template",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 0)},
        %{id: "sov_inf_1", name: "1st Rifle", template_id: "inf_template",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(4, 0)},
        %{id: "ger_reinf", name: "2nd Infantry", template_id: "inf_template",
          side: :axis, force: :german, arrives_turn: 3, deploy_hex: Coord.new(0, 1)}
      ],
      leaders: [
        %{id: "guderian", name: "Guderian", nationality: "german", era: "ww2",
          rank: :general, command_radius: 4, attack_modifier: 2, defense_modifier: 1,
          morale_modifier: 15, initiative_modifier: 2, abilities: [:blitz],
          position: Coord.new(1, 0), side: :axis, force: :german}
      ],
      victory_conditions: %{
        type: :victory_points,
        sudden_death_vp: nil,
        vp_levels: %{decisive: 80, tactical: 60, marginal: 40},
        unit_kill_vp: %{armor: 3, infantry: 1, leader: 5}
      },
      weather_schedule: [
        %{turns: 1..3, weather: :clear, ground: :dry},
        %{turns: 4..5, weather: :rain, ground: :mud}
      ],
      supply_sources: [
        %{side: :axis, hex: Coord.new(0, 0)},
        %{side: :allied, hex: Coord.new(4, 1)}
      ],
      reinforcement_mode: :fixed
    }

    Scenario.new(Map.merge(defaults, overrides))
  end

  describe "new/1" do
    test "creates a scenario from attributes" do
      scenario = test_scenario()
      assert scenario.name == "Test Engagement"
      assert scenario.era == "ww2"
      assert scenario.max_turns == 5
      assert length(scenario.sides) == 2
      assert length(scenario.scenario_units) == 4
    end
  end

  describe "get_side/2" do
    test "returns side config by id" do
      scenario = test_scenario()
      side = Scenario.get_side(scenario, :axis)
      assert side.id == :axis
      assert side.name == "Axis"
      assert :german in side.forces
    end

    test "returns nil for unknown side" do
      scenario = test_scenario()
      assert Scenario.get_side(scenario, :neutral) == nil
    end
  end

  describe "forces_for_side/2" do
    test "returns forces for a valid side" do
      scenario = test_scenario()
      forces = Scenario.forces_for_side(scenario, :axis)
      assert forces == [:german]
    end

    test "returns empty list for unknown side" do
      scenario = test_scenario()
      assert Scenario.forces_for_side(scenario, :neutral) == []
    end
  end

  describe "initial_game_state/1" do
    test "creates a complete game state map" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert state.scenario_id == "test-scenario-1"
      assert state.scenario_name == "Test Engagement"
      assert state.status == :playing
      assert state.result == nil
    end

    test "deploys turn-1 units as UnitInstance structs" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      # 3 turn-1 units deployed (the reinforcement at turn 3 is not)
      assert map_size(state.units) == 3
      assert Map.has_key?(state.units, "ger_inf_1")
      assert Map.has_key?(state.units, "ger_pz_1")
      assert Map.has_key?(state.units, "sov_inf_1")

      # Verify they're UnitInstance structs
      unit = state.units["ger_inf_1"]
      assert %WargameCore.Units.UnitInstance{} = unit
      assert unit.side == :axis
      assert unit.position == Coord.new(0, 0)
      assert unit.template == @infantry_template
    end

    test "does not deploy reinforcements scheduled for later turns" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      refute Map.has_key?(state.units, "ger_reinf")
      # Reinforcement should be in pending list
      assert length(state.pending_reinforcements) == 1
      assert hd(state.pending_reinforcements).id == "ger_reinf"
    end

    test "places leaders" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert map_size(state.leaders) == 1
      leader = state.leaders["guderian"]
      assert leader.name == "Guderian"
      assert leader.rank == :general
      assert leader.position == Coord.new(1, 0)
    end

    test "creates turn state from action profile" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert %TurnState{} = state.turn_state
      assert state.turn_state.turn_number == 1
      assert state.turn_state.max_turns == 5
      assert state.turn_state.active_side == :axis
      assert length(state.turn_state.phases) == 6
    end

    test "sets initial weather from schedule" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert state.weather == %{weather: :clear, ground: :dry}
    end

    test "calculates initial supply" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      # All units should have a supply status
      assert Map.has_key?(state.supply_cache, "ger_inf_1")
      assert Map.has_key?(state.supply_cache, "sov_inf_1")
    end

    test "resolves rules module from action profile" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert state.rules_module == WargameCore.Rules.StandardRules
    end

    test "includes victory conditions" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert state.victory_conditions.type == :victory_points
    end

    test "includes weather schedule for future turns" do
      scenario = test_scenario()
      state = Scenario.initial_game_state(scenario)

      assert length(state.weather_schedule) == 2
    end

    test "works with empty scenario units" do
      scenario = test_scenario(%{scenario_units: [], leaders: []})
      state = Scenario.initial_game_state(scenario)

      assert state.units == %{}
      assert state.leaders == %{}
    end

    test "works without action profile (uses standard phases)" do
      scenario = test_scenario(%{action_profile: nil})
      state = Scenario.initial_game_state(scenario)

      assert %TurnState{} = state.turn_state
      assert length(state.turn_state.phases) == 6
    end
  end
end
