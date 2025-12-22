defmodule WargameCore.MapTest do
  use ExUnit.Case, async: true

  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Map.Tile

  describe "new/5" do
    test "creates a map with correct dimensions" do
      map = GameMap.new("Test Map", 10, 8, 200)
      assert map.width == 10
      assert map.height == 8
    end

    test "creates a map with correct scale" do
      map = GameMap.new("Test Map", 10, 10, 500)
      assert map.scale == 500
    end

    test "creates a map with correct name" do
      map = GameMap.new("Battle of Kursk", 10, 10, 200)
      assert map.name == "Battle of Kursk"
    end

    test "creates tiles for all coordinates" do
      map = GameMap.new("Test", 5, 5, 200)
      assert map_size(map.tiles) == 25
    end

    test "uses default terrain" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)
      tile = GameMap.get_tile(map, coord)
      assert tile.terrain == :clear
    end

    test "uses custom default terrain" do
      map = GameMap.new("Test", 5, 5, 200, default_terrain: :forest_pine)
      coord = Coord.new(2, 2)
      tile = GameMap.get_tile(map, coord)
      assert tile.terrain == :forest_pine
    end

    test "accepts description option" do
      map = GameMap.new("Test", 5, 5, 200, description: "A test map")
      assert map.description == "A test map"
    end
  end

  describe "get_tile/2" do
    test "returns tile at valid coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 3)
      tile = GameMap.get_tile(map, coord)
      assert tile != nil
      assert Coord.equal?(tile.coord, coord)
    end

    test "returns nil for out of bounds coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(10, 10)
      assert GameMap.get_tile(map, coord) == nil
    end

    test "returns nil for negative coordinates" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(-1, 0)
      assert GameMap.get_tile(map, coord) == nil
    end
  end

  describe "put_tile/3" do
    test "updates tile at valid coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)
      new_tile = Tile.new(coord, :forest_pine)

      assert {:ok, updated_map} = GameMap.put_tile(map, coord, new_tile)
      assert GameMap.get_tile(updated_map, coord).terrain == :forest_pine
    end

    test "returns error for out of bounds coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(10, 10)
      tile = Tile.new(coord, :clear)

      assert {:error, :out_of_bounds} = GameMap.put_tile(map, coord, tile)
    end
  end

  describe "update_tile/3" do
    test "updates tile with function" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)

      assert {:ok, updated_map} =
               GameMap.update_tile(map, coord, fn tile -> %{tile | terrain: :urban} end)

      assert GameMap.get_tile(updated_map, coord).terrain == :urban
    end

    test "returns error for out of bounds coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(10, 10)

      assert {:error, :out_of_bounds} =
               GameMap.update_tile(map, coord, fn tile -> tile end)
    end
  end

  describe "set_terrain/3" do
    test "sets terrain at valid coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)

      assert {:ok, updated_map} = GameMap.set_terrain(map, coord, :hill)
      assert GameMap.get_tile(updated_map, coord).terrain == :hill
    end

    test "returns error for out of bounds" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(10, 10)

      assert {:error, :out_of_bounds} = GameMap.set_terrain(map, coord, :hill)
    end
  end

  describe "set_elevation/3" do
    test "sets elevation at valid coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)

      assert {:ok, updated_map} = GameMap.set_elevation(map, coord, 3)
      assert GameMap.get_tile(updated_map, coord).elevation == 3
    end
  end

  describe "in_bounds?/2" do
    test "returns true for valid coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      assert GameMap.in_bounds?(map, Coord.new(0, 0))
      assert GameMap.in_bounds?(map, Coord.new(4, 4))
      assert GameMap.in_bounds?(map, Coord.new(2, 2))
    end

    test "returns false for out of bounds coordinate" do
      map = GameMap.new("Test", 5, 5, 200)
      refute GameMap.in_bounds?(map, Coord.new(5, 5))
      refute GameMap.in_bounds?(map, Coord.new(-1, 0))
      refute GameMap.in_bounds?(map, Coord.new(0, -1))
    end
  end

  describe "all_coords/1" do
    test "returns all valid coordinates" do
      map = GameMap.new("Test", 3, 3, 200)
      coords = GameMap.all_coords(map)
      assert length(coords) == 9
    end

    test "all returned coordinates are in bounds" do
      map = GameMap.new("Test", 5, 5, 200)
      coords = GameMap.all_coords(map)

      Enum.each(coords, fn coord ->
        assert GameMap.in_bounds?(map, coord)
      end)
    end
  end

  describe "all_tiles/1" do
    test "returns all tiles" do
      map = GameMap.new("Test", 4, 4, 200)
      tiles = GameMap.all_tiles(map)
      assert length(tiles) == 16
    end
  end

  describe "neighbors/2" do
    test "returns neighbors within map bounds" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)
      neighbors = GameMap.neighbors(map, coord)

      # Interior hex should have all 6 neighbors
      assert length(neighbors) == 6
    end

    test "edge hex has fewer neighbors" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(0, 0)
      neighbors = GameMap.neighbors(map, coord)

      # Corner hex has fewer neighbors in bounds
      assert length(neighbors) < 6
    end

    test "all returned neighbors are valid tiles" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)
      neighbors = GameMap.neighbors(map, coord)

      Enum.each(neighbors, fn tile ->
        assert %Tile{} = tile
      end)
    end
  end

  describe "tiles_in_range/3" do
    test "returns tiles within range" do
      map = GameMap.new("Test", 10, 10, 200)
      center = Coord.new(5, 5)
      tiles = GameMap.tiles_in_range(map, center, 1)

      # Should include center + up to 6 neighbors
      assert length(tiles) == 7
    end

    test "excludes out of bounds tiles" do
      map = GameMap.new("Test", 5, 5, 200)
      center = Coord.new(0, 0)
      tiles = GameMap.tiles_in_range(map, center, 2)

      # Less than full range due to map boundaries
      assert length(tiles) < 19
    end
  end

  describe "find_path/5" do
    test "finds path between valid coordinates" do
      map = GameMap.new("Test", 10, 10, 200)
      from = Coord.new(0, 0)
      to = Coord.new(3, 0)

      assert {:ok, path} = GameMap.find_path(map, from, to, :infantry)
      assert length(path) >= 1
    end

    test "returns error for out of bounds" do
      map = GameMap.new("Test", 5, 5, 200)
      from = Coord.new(0, 0)
      to = Coord.new(10, 10)

      assert {:error, :out_of_bounds} = GameMap.find_path(map, from, to, :infantry)
    end

    test "path avoids impassable terrain" do
      map = GameMap.new("Test", 10, 10, 200)
      {:ok, map} = GameMap.set_terrain(map, Coord.new(1, 0), :lake)

      from = Coord.new(0, 0)
      to = Coord.new(2, 0)

      assert {:ok, path} = GameMap.find_path(map, from, to, :infantry)
      # Path should go around the lake
      refute Enum.any?(path, fn coord -> Coord.equal?(coord, Coord.new(1, 0)) end)
    end
  end

  describe "reachable_hexes/4" do
    test "returns reachable hexes with movement budget" do
      map = GameMap.new("Test", 10, 10, 200)
      start = Coord.new(5, 5)
      reachable = GameMap.reachable_hexes(map, start, 2, :infantry)

      assert map_size(reachable) > 0
    end

    test "respects terrain movement costs" do
      map = GameMap.new("Test", 10, 10, 200)
      # Set some difficult terrain
      {:ok, map} = GameMap.set_terrain(map, Coord.new(5, 4), :forest_pine)

      start = Coord.new(5, 5)
      reachable = GameMap.reachable_hexes(map, start, 2, :infantry)

      # Forest costs 2 for infantry, so less remaining movement
      forest_coord = Coord.new(5, 4)

      if Map.has_key?(reachable, Coord.to_key(forest_coord)) do
        assert reachable[Coord.to_key(forest_coord)] == 0
      end
    end
  end

  describe "has_line_of_sight?/3" do
    test "returns true when no blocking terrain" do
      map = GameMap.new("Test", 10, 10, 200)
      from = Coord.new(2, 2)
      to = Coord.new(5, 2)

      assert GameMap.has_line_of_sight?(map, from, to)
    end

    test "returns false when blocked by terrain" do
      map = GameMap.new("Test", 10, 10, 200)
      # Forest blocks LOS
      {:ok, map} = GameMap.set_terrain(map, Coord.new(3, 2), :forest_pine)

      from = Coord.new(2, 2)
      to = Coord.new(5, 2)

      refute GameMap.has_line_of_sight?(map, from, to)
    end

    test "returns false for out of bounds coordinates" do
      map = GameMap.new("Test", 5, 5, 200)
      from = Coord.new(0, 0)
      to = Coord.new(10, 10)

      refute GameMap.has_line_of_sight?(map, from, to)
    end
  end

  describe "tiles_controlled_by/2" do
    test "returns tiles controlled by a side" do
      map = GameMap.new("Test", 5, 5, 200)
      coord = Coord.new(2, 2)
      {:ok, map} = GameMap.update_tile(map, coord, &Tile.set_control(&1, :german))

      tiles = GameMap.tiles_controlled_by(map, :german)
      assert length(tiles) == 1
    end

    test "returns empty list when no tiles controlled" do
      map = GameMap.new("Test", 5, 5, 200)
      tiles = GameMap.tiles_controlled_by(map, :german)
      assert tiles == []
    end
  end

  describe "victory_points_for/2" do
    test "sums victory points for controlled tiles" do
      map = GameMap.new("Test", 5, 5, 200)
      coord1 = Coord.new(1, 1)
      coord2 = Coord.new(2, 2)

      {:ok, map} =
        GameMap.update_tile(map, coord1, fn tile ->
          %{tile | control: :german, victory_points: 5}
        end)

      {:ok, map} =
        GameMap.update_tile(map, coord2, fn tile ->
          %{tile | control: :german, victory_points: 3}
        end)

      assert GameMap.victory_points_for(map, :german) == 8
    end

    test "returns zero when no tiles controlled" do
      map = GameMap.new("Test", 5, 5, 200)
      assert GameMap.victory_points_for(map, :german) == 0
    end
  end

  describe "add_edge_feature/4" do
    test "adds edge feature between adjacent hexes" do
      map = GameMap.new("Test", 5, 5, 200)
      from = Coord.new(2, 2)
      to = Coord.new(3, 2)

      assert {:ok, updated_map} = GameMap.add_edge_feature(map, from, to, :road)

      # Check both tiles have the road
      from_tile = GameMap.get_tile(updated_map, from)
      to_tile = GameMap.get_tile(updated_map, to)

      assert Tile.has_edge_feature?(from_tile, 0, :road)
      assert Tile.has_edge_feature?(to_tile, 3, :road)
    end

    test "returns error for non-adjacent hexes" do
      map = GameMap.new("Test", 5, 5, 200)
      from = Coord.new(0, 0)
      to = Coord.new(2, 2)

      assert {:error, :not_adjacent} = GameMap.add_edge_feature(map, from, to, :road)
    end
  end

  describe "fill_terrain/4" do
    test "fills rectangular region with terrain" do
      map = GameMap.new("Test", 10, 10, 200)
      from = Coord.new(2, 2)
      to = Coord.new(4, 4)

      updated_map = GameMap.fill_terrain(map, from, to, :forest_pine)

      # Check all tiles in region have the terrain
      for q <- 2..4, r <- 2..4 do
        coord = Coord.new(q, r)
        tile = GameMap.get_tile(updated_map, coord)
        assert tile.terrain == :forest_pine
      end
    end

    test "ignores out of bounds coordinates" do
      map = GameMap.new("Test", 5, 5, 200)
      from = Coord.new(3, 3)
      to = Coord.new(10, 10)

      # Should not crash
      _updated_map = GameMap.fill_terrain(map, from, to, :urban)
    end
  end

  describe "dimensions/1" do
    test "returns width and height" do
      map = GameMap.new("Test", 15, 20, 200)
      assert GameMap.dimensions(map) == {15, 20}
    end
  end

  describe "real_world_size/1" do
    test "calculates map size in meters" do
      map = GameMap.new("Test", 10, 10, 1000)
      {width, height} = GameMap.real_world_size(map)

      assert is_float(width)
      assert is_float(height)
      assert width > 0
      assert height > 0
    end
  end
end
