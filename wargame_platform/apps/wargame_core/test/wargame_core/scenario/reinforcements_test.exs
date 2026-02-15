defmodule WargameCore.Scenario.ReinforcementsTest do
  use ExUnit.Case, async: true

  alias WargameCore.Scenario.Reinforcements
  alias WargameCore.Hex.Coord

  @infantry_template %WargameCore.Units.UnitTemplate{
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

  defp make_unit(id, arrives_turn, deploy_hex, opts \\ %{}) do
    Map.merge(%{
      id: id,
      name: "Unit #{id}",
      arrives_turn: arrives_turn,
      deploy_hex: deploy_hex,
      side: :axis,
      force: :german,
      template_id: "inf_template"
    }, opts)
  end

  describe "deploy_reinforcements/4 with :fixed mode" do
    test "deploys units arriving on current turn" do
      units = [
        make_unit("u1", 1, Coord.new(0, 0)),
        make_unit("u2", 2, Coord.new(1, 0)),
        make_unit("u3", 3, Coord.new(2, 0))
      ]

      result = Reinforcements.deploy_reinforcements(2, units, :fixed)
      assert length(result) == 1
      assert hd(result).id == "u2"
    end

    test "returns empty list when no units arrive" do
      units = [
        make_unit("u1", 5, Coord.new(0, 0))
      ]

      result = Reinforcements.deploy_reinforcements(1, units, :fixed)
      assert result == []
    end

    test "deploys multiple units on same turn" do
      units = [
        make_unit("u1", 3, Coord.new(0, 0)),
        make_unit("u2", 3, Coord.new(1, 0)),
        make_unit("u3", 5, Coord.new(2, 0))
      ]

      result = Reinforcements.deploy_reinforcements(3, units, :fixed)
      assert length(result) == 2
      ids = Enum.map(result, & &1.id)
      assert "u1" in ids
      assert "u2" in ids
    end
  end

  describe "deploy_reinforcements/4 with :variable mode" do
    test "always deploys when random roll is very low" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]

      # Roll of 0.01 should always succeed (below no_show + base_prob)
      result = Reinforcements.deploy_reinforcements(3, units, :variable,
        rand_fn: fn -> 0.01 end)
      assert length(result) == 1
    end

    test "no-show when roll is in no_show_chance range" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]

      # Roll of 0.95 is >= (1.0 - 0.1) = 0.9, so it's a no-show
      result = Reinforcements.deploy_reinforcements(3, units, :variable,
        rand_fn: fn -> 0.95 end)
      assert result == []
    end

    test "does not deploy before earliest arrival" do
      units = [make_unit("u1", 5, Coord.new(0, 0))]

      # earliest = 5 - 1 = 4, so turn 3 is too early
      result = Reinforcements.deploy_reinforcements(3, units, :variable,
        rand_fn: fn -> 0.01 end)
      assert result == []
    end

    test "does not deploy after latest arrival" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]

      # latest = 3 + 3 = 6, so turn 7 is too late
      result = Reinforcements.deploy_reinforcements(7, units, :variable,
        rand_fn: fn -> 0.01 end)
      assert result == []
    end

    test "can deploy early with reduced probability" do
      units = [make_unit("u1", 5, Coord.new(0, 0))]

      # earliest = 4, roll needs to be < base_prob * 0.3 = 0.24
      result = Reinforcements.deploy_reinforcements(4, units, :variable,
        rand_fn: fn -> 0.1 end)
      assert length(result) == 1
    end

    test "probability increases for late arrivals" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]

      # Turn 5 = 2 turns late. Prob = 0.8 + 2*0.1 = 1.0 capped to 0.9
      # Roll of 0.85 should succeed
      result = Reinforcements.deploy_reinforcements(5, units, :variable,
        rand_fn: fn -> 0.85 end)
      assert length(result) == 1
    end
  end

  describe "deploy_reinforcements/4 with :conditional mode" do
    test "deploys when condition function returns true" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]
      condition = fn _unit, _state -> true end

      result = Reinforcements.deploy_reinforcements(3, units, :conditional,
        condition_fn: condition)
      assert length(result) == 1
    end

    test "does not deploy when condition returns false" do
      units = [make_unit("u1", 3, Coord.new(0, 0))]
      condition = fn _unit, _state -> false end

      result = Reinforcements.deploy_reinforcements(3, units, :conditional,
        condition_fn: condition)
      assert result == []
    end

    test "does not deploy before scheduled turn even if condition is true" do
      units = [make_unit("u1", 5, Coord.new(0, 0))]
      condition = fn _unit, _state -> true end

      result = Reinforcements.deploy_reinforcements(3, units, :conditional,
        condition_fn: condition)
      assert result == []
    end

    test "condition receives unit and game state" do
      units = [make_unit("u1", 1, Coord.new(0, 0), %{trigger: :hex_captured})]
      game_state = %{captured_hexes: [:target_hex]}

      condition = fn unit, state ->
        unit.trigger == :hex_captured &&
          :target_hex in Map.get(state, :captured_hexes, [])
      end

      result = Reinforcements.deploy_reinforcements(1, units, :conditional,
        condition_fn: condition, game_state: game_state)
      assert length(result) == 1
    end
  end

  describe "instantiate_reinforcement/2" do
    test "creates a UnitInstance from definition and template" do
      unit_def = %{
        id: "reinf-1",
        name: "2nd Infantry Platoon",
        side: :axis,
        force: :german,
        deploy_hex: Coord.new(0, 5),
        experience: 2,
        morale: 90
      }

      instance = Reinforcements.instantiate_reinforcement(unit_def, @infantry_template)
      assert instance.id == "reinf-1"
      assert instance.name == "2nd Infantry Platoon"
      assert instance.side == :axis
      assert instance.position == Coord.new(0, 5)
      assert instance.experience == 2
      assert instance.morale == 90
      assert instance.template == @infantry_template
    end

    test "defaults name to template name" do
      unit_def = %{
        id: "reinf-2",
        side: :axis,
        force: :german,
        deploy_hex: Coord.new(0, 0)
      }

      instance = Reinforcements.instantiate_reinforcement(unit_def, @infantry_template)
      assert instance.name == "Infantry Platoon"
    end
  end

  describe "pending_reinforcements/2" do
    test "returns units that haven't arrived yet" do
      units = [
        make_unit("u1", 1, Coord.new(0, 0)),
        make_unit("u2", 3, Coord.new(1, 0)),
        make_unit("u3", 5, Coord.new(2, 0))
      ]

      pending = Reinforcements.pending_reinforcements(2, units)
      assert length(pending) == 2
      ids = Enum.map(pending, & &1.id)
      assert "u2" in ids
      assert "u3" in ids
    end
  end

  describe "check_no_shows/2" do
    test "identifies units past their latest arrival window" do
      units = [
        make_unit("u1", 3, Coord.new(0, 0)),  # latest = 3 + 3 = 6
        make_unit("u2", 1, Coord.new(1, 0))   # latest = 1 + 3 = 4
      ]

      no_shows = Reinforcements.check_no_shows(units, 7)
      assert length(no_shows) == 2

      no_shows = Reinforcements.check_no_shows(units, 5)
      assert length(no_shows) == 1
      assert hd(no_shows).id == "u2"
    end
  end
end
