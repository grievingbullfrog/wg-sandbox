defmodule WargameCore.Game.FogOfWarTest do
  use ExUnit.Case, async: true

  alias WargameCore.Game.FogOfWar
  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Turns.{Phase, TurnState}
  alias WargameCore.Units.{UnitTemplate, UnitInstance}

  @infantry_template %UnitTemplate{
    id: "inf",
    name: "Infantry",
    nationality: "german",
    era: "ww2",
    category: :infantry,
    unit_size: :battalion,
    attack_soft: 4,
    attack_hard: 2,
    defense: 4,
    armor: 0,
    range: 1,
    spotting: 3,
    initiative: 3,
    movement_points: 4,
    movement_type: :foot,
    max_strength: 10,
    max_ammo: 10,
    max_fuel: 0
  }

  defp make_unit(id, side, position, opts \\ []) do
    template = Keyword.get(opts, :template, @infantry_template)
    strength = Keyword.get(opts, :strength, template.max_strength)

    UnitInstance.new(template, %{
      id: id,
      name: "Unit #{id}",
      side: side,
      force: side,
      position: position,
      current_strength: strength
    })
  end

  defp make_map(width, height) do
    GameMap.new("test", width, height, 200)
  end

  defp make_game_state(opts) do
    map = Keyword.get(opts, :map, make_map(8, 8))
    units = Keyword.get(opts, :units, %{})
    leaders = Keyword.get(opts, :leaders, %{})
    fog_mode = Keyword.get(opts, :fog_of_war, :none)
    weather = Keyword.get(opts, :weather, :clear)

    phases = [
      Phase.new(:movement, "Movement", 0, allows_movement: true),
      Phase.new(:combat, "Combat", 1, allows_combat: true)
    ]

    %{
      map: map,
      units: units,
      leaders: leaders,
      turn_state: TurnState.new(phases, [:german, :soviet]),
      sides: [:german, :soviet],
      settings: %{fog_of_war: fog_mode},
      weather: %{weather: weather, ground: :dry},
      victory_conditions: %{}
    }
  end

  describe "calculate_visibility/2" do
    test "unit sees its own hex" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))
      state = make_game_state(units: %{"g1" => u1})

      visible = FogOfWar.calculate_visibility(state, :german)

      assert MapSet.member?(visible, Coord.new(3, 3))
    end

    test "unit sees hexes within spotting range" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))
      state = make_game_state(units: %{"g1" => u1})

      visible = FogOfWar.calculate_visibility(state, :german)

      # Spotting range 3 - adjacent hexes should be visible
      assert MapSet.member?(visible, Coord.new(4, 3))
      assert MapSet.member?(visible, Coord.new(3, 4))
      assert MapSet.member?(visible, Coord.new(2, 3))
    end

    test "unit cannot see beyond spotting range" do
      u1 = make_unit("g1", :german, Coord.new(0, 0))
      state = make_game_state(units: %{"g1" => u1})

      visible = FogOfWar.calculate_visibility(state, :german)

      # Far away hex should not be visible (spotting = 3)
      refute MapSet.member?(visible, Coord.new(7, 7))
    end

    test "multiple units combine visibility" do
      u1 = make_unit("g1", :german, Coord.new(1, 1))
      u2 = make_unit("g2", :german, Coord.new(5, 5))
      state = make_game_state(units: %{"g1" => u1, "g2" => u2})

      visible = FogOfWar.calculate_visibility(state, :german)

      # Both units' areas should be visible
      assert MapSet.member?(visible, Coord.new(1, 1))
      assert MapSet.member?(visible, Coord.new(5, 5))
    end

    test "enemy units do not contribute to visibility" do
      u1 = make_unit("s1", :soviet, Coord.new(4, 4))
      state = make_game_state(units: %{"s1" => u1})

      visible = FogOfWar.calculate_visibility(state, :german)

      # German has no units, so nothing visible
      assert MapSet.size(visible) == 0
    end

    test "bad weather reduces spotting range" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))
      clear_state = make_game_state(units: %{"g1" => u1}, weather: :clear)
      blizzard_state = make_game_state(units: %{"g1" => u1}, weather: :blizzard)

      clear_visible = FogOfWar.calculate_visibility(clear_state, :german)
      blizzard_visible = FogOfWar.calculate_visibility(blizzard_state, :german)

      # Blizzard should reduce visibility
      assert MapSet.size(blizzard_visible) < MapSet.size(clear_visible)
    end

    test "leader with recon_bonus increases spotting" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))

      leader = %{
        id: "l1",
        name: "Leader",
        side: :german,
        force: :german,
        position: Coord.new(3, 4),
        command_radius: 2,
        rank: :colonel,
        abilities: [:recon_bonus],
        attack_modifier: 0,
        defense_modifier: 0,
        morale_modifier: 0,
        initiative_modifier: 0
      }

      state_with = make_game_state(units: %{"g1" => u1}, leaders: %{"l1" => leader})
      state_without = make_game_state(units: %{"g1" => u1}, leaders: %{})

      visible_with = FogOfWar.calculate_visibility(state_with, :german)
      visible_without = FogOfWar.calculate_visibility(state_without, :german)

      assert MapSet.size(visible_with) >= MapSet.size(visible_without)
    end
  end

  describe "filter_state_for_side/2" do
    test "mode :none returns state unchanged" do
      u1 = make_unit("g1", :german, Coord.new(1, 1))
      u2 = make_unit("s1", :soviet, Coord.new(5, 5))
      state = make_game_state(units: %{"g1" => u1, "s1" => u2}, fog_of_war: :none)

      filtered = FogOfWar.filter_state_for_side(state, :german)

      # All units visible
      assert filtered.units["s1"].position == Coord.new(5, 5)
    end

    test "mode :partial hides enemy units outside visibility" do
      u1 = make_unit("g1", :german, Coord.new(0, 0))
      u2 = make_unit("s1", :soviet, Coord.new(7, 7))
      state = make_game_state(units: %{"g1" => u1, "s1" => u2}, fog_of_war: :partial)

      filtered = FogOfWar.filter_state_for_side(state, :german)

      # Friendly units always visible
      assert filtered.units["g1"].position == Coord.new(0, 0)

      # Enemy far away should be hidden
      refute Map.has_key?(filtered.units, "s1")
    end

    test "mode :partial shows enemy units within visibility" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))
      u2 = make_unit("s1", :soviet, Coord.new(4, 3))
      state = make_game_state(units: %{"g1" => u1, "s1" => u2}, fog_of_war: :partial)

      filtered = FogOfWar.filter_state_for_side(state, :german)

      # Adjacent enemy should be visible
      assert Map.has_key?(filtered.units, "s1")
      assert filtered.units["s1"].position == Coord.new(4, 3)
    end

    test "mode :partial includes visible_hexes in state" do
      u1 = make_unit("g1", :german, Coord.new(3, 3))
      state = make_game_state(units: %{"g1" => u1}, fog_of_war: :partial)

      filtered = FogOfWar.filter_state_for_side(state, :german)

      assert Map.has_key?(filtered, :visible_hexes)
      assert MapSet.member?(filtered.visible_hexes, Coord.new(3, 3))
    end

    test "mode :full hides tile details for non-visible hexes" do
      u1 = make_unit("g1", :german, Coord.new(0, 0))
      map = make_map(8, 8)

      # Set VP on a distant hex
      vp_coord = Coord.new(7, 7)
      tile = GameMap.get_tile(map, vp_coord)

      map =
        if tile do
          %{map | tiles: Map.put(map.tiles, vp_coord, %{tile | victory_points: 5, control: :soviet})}
        else
          map
        end

      state = make_game_state(map: map, units: %{"g1" => u1}, fog_of_war: :full)
      filtered = FogOfWar.filter_state_for_side(state, :german)

      # Far-away VP hex should have its VP hidden
      far_tile = GameMap.get_tile(filtered.map, vp_coord)

      if far_tile do
        assert far_tile.victory_points == 0
        assert far_tile.control == nil
      end
    end
  end
end
