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
      tile = Tile.new(coord, :tundra, elevation: 2)
      assert tile.elevation == 2
    end

    test "accepts control option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, control: :german)
      assert tile.control == :german
    end

    test "accepts victory_points option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :light_urban, victory_points: 5)
      assert tile.victory_points == 5
    end

    test "accepts name option" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :heavy_urban, name: "Berlin")
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
      tile = Tile.new(coord, :freshwater_lake)

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

    test "small stream edge adds small movement cost" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_stream]})

      # Clear = 1, small_stream = 0.5
      assert Tile.movement_cost(tile, :infantry, 0) == 1.5
    end

    test "large stream edge adds movement cost" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:large_stream]})

      # Clear = 1, large_stream = 1
      assert Tile.movement_cost(tile, :infantry, 0) == 2
    end

    test "small river adds moderate movement cost" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_river]})

      # Clear = 1, small_river = 2 for non-engineers
      assert Tile.movement_cost(tile, :infantry, 0) == 3
    end

    test "engineers cross small rivers more easily" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_river]})

      # Clear = 1, small_river = 1 for engineers
      assert Tile.movement_cost(tile, :engineer, 0) == 2
    end

    test "large river blocks non-engineers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:large_river]})

      assert Tile.movement_cost(tile, :infantry, 0) == :impassable
    end

    test "engineers can cross large rivers" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:large_river]})

      # Clear = 1, large_river = 2 for engineers
      assert Tile.movement_cost(tile, :engineer, 0) == 3
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
      tile = Tile.new(coord, :heavy_urban)

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

    test "heavy_urban blocks LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :heavy_urban)

      assert Tile.blocks_los?(tile)
    end

    test "light_urban blocks LOS" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :light_urban)

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
      updated = Tile.add_edge_feature(tile, 0, :small_stream)

      assert :small_stream in Map.get(updated.edges, 0, [])
    end

    test "does not add duplicate edge features" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_stream]})
      updated = Tile.add_edge_feature(tile, 0, :small_stream)

      assert length(Map.get(updated.edges, 0, [])) == 1
    end

    test "can add multiple features to same edge" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      tile = Tile.add_edge_feature(tile, 0, :large_stream)
      tile = Tile.add_edge_feature(tile, 0, :bridge)

      features = Map.get(tile.edges, 0, [])
      assert :large_stream in features
      assert :bridge in features
    end
  end

  describe "clear_edge/2" do
    test "clears all features from a specific edge" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_river], 1 => [:large_stream]})

      updated = Tile.clear_edge(tile, 0)

      refute Map.has_key?(updated.edges, 0)
      assert Map.get(updated.edges, 1) == [:large_stream]
    end

    test "does nothing when edge has no features" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      updated = Tile.clear_edge(tile, 0)

      assert updated.edges == %{}
    end
  end

  describe "has_edge_feature?/3" do
    test "returns true when feature present" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_stream]})

      assert Tile.has_edge_feature?(tile, 0, :small_stream)
    end

    test "returns false when feature not present" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.has_edge_feature?(tile, 0, :small_stream)
    end

    test "returns false for different direction" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear, edges: %{0 => [:small_stream]})

      refute Tile.has_edge_feature?(tile, 1, :small_stream)
    end
  end

  # Tests for transport segments

  describe "transport_segments in new/3" do
    test "defaults to empty transport_segments" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      assert tile.transport_segments == []
    end

    test "accepts transport_segments option" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      assert length(tile.transport_segments) == 1
      assert hd(tile.transport_segments).type == :small_paved_road
    end
  end

  describe "add_transport_segment/2" do
    test "adds transport segment to tile" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      updated = Tile.add_transport_segment(tile, segment)

      assert length(updated.transport_segments) == 1
      assert hd(updated.transport_segments).type == :small_paved_road
    end

    test "can add multiple segments" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      tile = Tile.add_transport_segment(tile, TransportSegment.new(:small_paved_road, [0], [3]))
      tile = Tile.add_transport_segment(tile, TransportSegment.new(:railroad, [1], [4]))

      assert length(tile.transport_segments) == 2
    end
  end

  describe "remove_transport_segment/2" do
    test "removes matching transport segment" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment1 = TransportSegment.new(:small_paved_road, [0], [3])
      segment2 = TransportSegment.new(:railroad, [1], [4])
      tile = Tile.new(coord, :clear, transport_segments: [segment1, segment2])

      updated = Tile.remove_transport_segment(tile, segment1)

      assert length(updated.transport_segments) == 1
      assert hd(updated.transport_segments).type == :railroad
    end

    test "no effect when segment not present" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      other = TransportSegment.new(:railroad, [1], [4])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      updated = Tile.remove_transport_segment(tile, other)

      assert length(updated.transport_segments) == 1
    end
  end

  describe "clear_transport_segments/1" do
    test "removes all transport segments" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment1 = TransportSegment.new(:small_paved_road, [0], [3])
      segment2 = TransportSegment.new(:railroad, [1], [4])
      tile = Tile.new(coord, :clear, transport_segments: [segment1, segment2])

      updated = Tile.clear_transport_segments(tile)

      assert updated.transport_segments == []
    end
  end

  describe "get_segments_by_type/2" do
    test "returns segments of matching type" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      road1 = TransportSegment.new(:small_paved_road, [0], [3])
      road2 = TransportSegment.new(:small_paved_road, [1], [4])
      rail = TransportSegment.new(:railroad, [2], [5])
      tile = Tile.new(coord, :clear, transport_segments: [road1, road2, rail])

      roads = Tile.get_segments_by_type(tile, :small_paved_road)

      assert length(roads) == 2
      assert Enum.all?(roads, fn s -> s.type == :small_paved_road end)
    end

    test "returns empty list when no matching segments" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      result = Tile.get_segments_by_type(tile, :railroad)

      assert result == []
    end
  end

  describe "has_transport_segments?/1" do
    test "returns false when no segments" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.has_transport_segments?(tile)
    end

    test "returns true when segments present" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      assert Tile.has_transport_segments?(tile)
    end
  end

  describe "has_transport_at_edge?/2" do
    test "returns true when segment connects to edge" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      assert Tile.has_transport_at_edge?(tile, 0)
      assert Tile.has_transport_at_edge?(tile, 3)
    end

    test "returns false when no segment at edge" do
      alias WargameCore.Map.TransportSegment
      coord = Coord.new(0, 0)
      segment = TransportSegment.new(:small_paved_road, [0], [3])
      tile = Tile.new(coord, :clear, transport_segments: [segment])

      refute Tile.has_transport_at_edge?(tile, 1)
      refute Tile.has_transport_at_edge?(tile, 2)
    end

    test "returns false when no segments" do
      coord = Coord.new(0, 0)
      tile = Tile.new(coord, :clear)

      refute Tile.has_transport_at_edge?(tile, 0)
    end
  end

  describe "set_objective/3" do
    test "sets objective with name and force" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      updated = Tile.set_objective(tile, "Hill 223", :allied)

      assert updated.objective == %{name: "Hill 223", force: :allied}
    end

    test "sets objective with nil force" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      updated = Tile.set_objective(tile, "Crossroads", nil)

      assert updated.objective == %{name: "Crossroads", force: nil}
    end

    test "sets objective with nil name" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      updated = Tile.set_objective(tile, nil, :axis)

      assert updated.objective == %{name: nil, force: :axis}
    end

    test "can update existing objective" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, objective: %{name: "Old Name", force: :allied})

      updated = Tile.set_objective(tile, "New Name", :axis)

      assert updated.objective == %{name: "New Name", force: :axis}
    end
  end

  describe "clear_objective/1" do
    test "removes objective from tile" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, objective: %{name: "Hill 223", force: :allied})

      updated = Tile.clear_objective(tile)

      assert updated.objective == nil
    end

    test "no effect when no objective present" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      updated = Tile.clear_objective(tile)

      assert updated.objective == nil
    end
  end

  describe "has_objective?/1" do
    test "returns true when objective present" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, objective: %{name: "Hill 223", force: :allied})

      assert Tile.has_objective?(tile)
    end

    test "returns false when no objective" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      refute Tile.has_objective?(tile)
    end
  end

  describe "set_victory_points/2" do
    test "sets victory points" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      updated = Tile.set_victory_points(tile, 10)

      assert updated.victory_points == 10
    end

    test "can set to zero" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, victory_points: 5)

      updated = Tile.set_victory_points(tile, 0)

      assert updated.victory_points == 0
    end

    test "can update existing victory points" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, victory_points: 5)

      updated = Tile.set_victory_points(tile, 15)

      assert updated.victory_points == 15
    end
  end

  describe "objective in new/3" do
    test "can create tile with objective" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear, objective: %{name: "Factory", force: :soviet})

      assert tile.objective == %{name: "Factory", force: :soviet}
    end

    test "tile defaults to no objective" do
      coord = Coord.new(5, 5)
      tile = Tile.new(coord, :clear)

      assert tile.objective == nil
    end
  end
end
