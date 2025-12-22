defmodule WargameCore.Map.TileTest do
  use ExUnit.Case, async: true

  alias WargameCore.Hex.Coord
  alias WargameCore.Map.Tile

  describe "new/3" do
    test "creates tile with coordinate and terrain" do
      coord = Coord.new(3, 4)
      tile = Tile.new(coord, :clear)

      assert Coord.equal?(tile.coord, coord)
      assert tile.terrain == :clear
    end

    test "defaults to elevation 0" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.elevation == 0
    end

    test "defaults to empty edges" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.edges == %{}
    end

    test "defaults to empty overlays" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.overlays == []
    end

    test "defaults to nil control" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.control == nil
    end

    test "defaults to 0 victory points" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.victory_points == 0
    end

    test "accepts elevation option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :hill, elevation: 2)
      assert tile.elevation == 2
    end

    test "accepts control option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, control: :german)
      assert tile.control == :german
    end

    test "accepts victory_points option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :village, victory_points: 5)
      assert tile.victory_points == 5
    end

    test "accepts name option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :urban, name: "Berlin")
      assert tile.name == "Berlin"
    end
  end

  describe "terrain_type/1" do
    test "returns terrain type struct for known terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      terrain_type = Tile.terrain_type(tile)

      assert terrain_type != nil
      assert terrain_type.id == :clear
    end

    test "returns nil for unknown terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :nonexistent_terrain)

      assert Tile.terrain_type(tile) == nil
    end
  end

  describe "movement_cost/3" do
    test "returns base terrain cost for infantry on clear" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      assert Tile.movement_cost(tile, :infantry) == 1
    end

    test "returns higher cost for difficult terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :forest_pine)

      assert Tile.movement_cost(tile, :infantry) == 2
    end

    test "returns :impassable for impassable terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :lake)

      assert Tile.movement_cost(tile, :infantry) == :impassable
    end

    test "adds overlay costs" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:minefield])

      # Clear = 1, minefield = +2 for non-engineers
      assert Tile.movement_cost(tile, :infantry) == 3
    end

    test "engineers have lower minefield cost" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:minefield])

      # Clear = 1, minefield = +1 for engineers
      assert Tile.movement_cost(tile, :engineer) == 2
    end

    test "fortification blocks armor" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:fortification])

      assert Tile.movement_cost(tile, :armor) == :impassable
    end

    test "road edge reduces movement cost" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:road]})

      # Clear = 1, road = -0.5
      assert Tile.movement_cost(tile, :infantry, 0) == 0.5
    end

    test "river edge blocks non-engineers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:river]})

      assert Tile.movement_cost(tile, :infantry, 0) == :impassable
    end

    test "engineers can cross rivers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:river]})

      # Clear = 1, river = +2 for engineers
      assert Tile.movement_cost(tile, :engineer, 0) == 3
    end

    test "bridge allows river crossing" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:river, :bridge]})

      # Bridge negates river cost
      assert Tile.movement_cost(tile, :infantry, 0) == 1
    end
  end

  describe "defense_modifier/1" do
    test "returns 0 for clear terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      assert Tile.defense_modifier(tile) == 0
    end

    test "returns positive modifier for defensive terrain" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :urban)

      assert Tile.defense_modifier(tile) == 3
    end

    test "adds overlay defense modifiers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:fortification])

      # Clear = 0, fortification = +3
      assert Tile.defense_modifier(tile) == 3
    end

    test "stacks multiple overlay modifiers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:fortification, :trench])

      # Clear = 0, fortification = +3, trench = +2
      assert Tile.defense_modifier(tile) == 5
    end

    test "bunker provides strong defense" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:bunker])

      assert Tile.defense_modifier(tile) == 4
    end
  end

  describe "blocks_los?/1" do
    test "clear terrain does not block LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.blocks_los?(tile)
    end

    test "forest blocks LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :forest_pine)

      assert Tile.blocks_los?(tile)
    end

    test "urban blocks LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :urban)

      assert Tile.blocks_los?(tile)
    end

    test "village blocks LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :village)

      assert Tile.blocks_los?(tile)
    end
  end

  describe "concealment?/1" do
    test "clear terrain provides no concealment" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.concealment?(tile)
    end

    test "forest provides concealment" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :forest_pine)

      assert Tile.concealment?(tile)
    end

    test "trench overlay provides concealment" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:trench])

      assert Tile.concealment?(tile)
    end
  end

  describe "add_overlay/2" do
    test "adds overlay to tile" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      updated = Tile.add_overlay(tile, :minefield)

      assert :minefield in updated.overlays
    end

    test "does not add duplicate overlays" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:minefield])
      updated = Tile.add_overlay(tile, :minefield)

      assert length(updated.overlays) == 1
    end

    test "can add multiple different overlays" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      tile = Tile.add_overlay(tile, :minefield)
      tile = Tile.add_overlay(tile, :trench)

      assert :minefield in tile.overlays
      assert :trench in tile.overlays
    end
  end

  describe "remove_overlay/2" do
    test "removes overlay from tile" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, overlays: [:minefield, :trench])
      updated = Tile.remove_overlay(tile, :minefield)

      refute :minefield in updated.overlays
      assert :trench in updated.overlays
    end

    test "no effect when overlay not present" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      updated = Tile.remove_overlay(tile, :minefield)

      assert updated.overlays == []
    end
  end

  describe "set_control/2" do
    test "sets control to a side" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      updated = Tile.set_control(tile, :german)

      assert updated.control == :german
    end

    test "can change control" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, control: :german)
      updated = Tile.set_control(tile, :soviet)

      assert updated.control == :soviet
    end

    test "can clear control" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, control: :german)
      updated = Tile.set_control(tile, nil)

      assert updated.control == nil
    end
  end

  describe "add_edge_feature/3" do
    test "adds edge feature to direction" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      updated = Tile.add_edge_feature(tile, 0, :road)

      assert :road in Map.get(updated.edges, 0, [])
    end

    test "does not add duplicate edge features" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:road]})
      updated = Tile.add_edge_feature(tile, 0, :road)

      assert length(Map.get(updated.edges, 0, [])) == 1
    end

    test "can add multiple features to same edge" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      tile = Tile.add_edge_feature(tile, 0, :river)
      tile = Tile.add_edge_feature(tile, 0, :bridge)

      features = Map.get(tile.edges, 0, [])
      assert :river in features
      assert :bridge in features
    end
  end

  describe "has_edge_feature?/3" do
    test "returns true when feature present" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:road]})

      assert Tile.has_edge_feature?(tile, 0, :road)
    end

    test "returns false when feature not present" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.has_edge_feature?(tile, 0, :road)
    end

    test "returns false for different direction" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:road]})

      refute Tile.has_edge_feature?(tile, 1, :road)
    end
  end
end
