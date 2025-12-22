defmodule WargameCore.Hex.GridTest do
  use ExUnit.Case, async: true

  alias WargameCore.Hex.Coord
  alias WargameCore.Hex.Grid

  describe "hexes_in_range/2" do
    test "range 0 returns only the center hex" do
      center = Coord.new(0, 0)
      hexes = Grid.hexes_in_range(center, 0)
      assert length(hexes) == 1
      assert Coord.equal?(hd(hexes), center)
    end

    test "range 1 returns 7 hexes (center + 6 neighbors)" do
      center = Coord.new(0, 0)
      hexes = Grid.hexes_in_range(center, 1)
      assert length(hexes) == 7
    end

    test "range 2 returns 19 hexes" do
      center = Coord.new(0, 0)
      hexes = Grid.hexes_in_range(center, 2)
      # Formula: 3n^2 + 3n + 1 for range n
      # For n=2: 3*4 + 3*2 + 1 = 19
      assert length(hexes) == 19
    end

    test "all returned hexes are within the specified range" do
      center = Coord.new(5, 3)
      range = 3
      hexes = Grid.hexes_in_range(center, range)

      Enum.each(hexes, fn hex ->
        assert Coord.distance(center, hex) <= range
      end)
    end

    test "hexes are unique" do
      center = Coord.new(0, 0)
      hexes = Grid.hexes_in_range(center, 3)
      keys = Enum.map(hexes, &Coord.to_key/1)
      assert length(keys) == length(Enum.uniq(keys))
    end
  end

  describe "hex_ring/2" do
    test "ring of radius 0 returns only the center" do
      center = Coord.new(0, 0)
      ring = Grid.hex_ring(center, 0)
      assert length(ring) == 1
      assert Coord.equal?(hd(ring), center)
    end

    test "ring of radius 1 returns 6 hexes" do
      center = Coord.new(0, 0)
      ring = Grid.hex_ring(center, 1)
      assert length(ring) == 6
    end

    test "ring of radius 2 returns 12 hexes" do
      center = Coord.new(0, 0)
      ring = Grid.hex_ring(center, 2)
      # Formula: 6n for radius n > 0
      assert length(ring) == 12
    end

    test "all hexes in ring are at exact distance from center" do
      center = Coord.new(3, -2)
      radius = 3
      ring = Grid.hex_ring(center, radius)

      Enum.each(ring, fn hex ->
        assert Coord.distance(center, hex) == radius
      end)
    end

    test "ring hexes are unique" do
      center = Coord.new(0, 0)
      ring = Grid.hex_ring(center, 4)
      keys = Enum.map(ring, &Coord.to_key/1)
      assert length(keys) == length(Enum.uniq(keys))
    end
  end

  describe "line_draw/2" do
    test "line from hex to itself returns single hex" do
      a = Coord.new(0, 0)
      line = Grid.line_draw(a, a)
      assert length(line) == 1
      assert Coord.equal?(hd(line), a)
    end

    test "line to adjacent hex returns 2 hexes" do
      a = Coord.new(0, 0)
      b = Coord.new(1, 0)
      line = Grid.line_draw(a, b)
      assert length(line) == 2
    end

    test "line includes start and end hexes" do
      a = Coord.new(0, 0)
      b = Coord.new(3, 0)
      line = Grid.line_draw(a, b)

      assert Enum.any?(line, &Coord.equal?(&1, a))
      assert Enum.any?(line, &Coord.equal?(&1, b))
    end

    test "line length equals distance + 1" do
      a = Coord.new(0, 0)
      b = Coord.new(3, 0)
      line = Grid.line_draw(a, b)
      assert length(line) == Coord.distance(a, b) + 1
    end

    test "consecutive hexes in line are adjacent" do
      a = Coord.new(0, 0)
      b = Coord.new(3, -2)
      line = Grid.line_draw(a, b)

      line
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [from, to] ->
        assert Coord.distance(from, to) == 1
      end)
    end
  end

  describe "has_line_of_sight?/3" do
    test "returns true when nothing blocks" do
      a = Coord.new(0, 0)
      b = Coord.new(3, 0)
      blocks_fn = fn _ -> false end
      assert Grid.has_line_of_sight?(a, b, blocks_fn)
    end

    test "returns false when intermediate hex blocks" do
      a = Coord.new(0, 0)
      b = Coord.new(3, 0)
      blocking_coord = Coord.new(1, 0)

      blocks_fn = fn coord ->
        Coord.equal?(coord, blocking_coord)
      end

      refute Grid.has_line_of_sight?(a, b, blocks_fn)
    end

    test "start and end hexes do not block LOS" do
      a = Coord.new(0, 0)
      b = Coord.new(2, 0)

      # Block start and end, but they shouldn't affect LOS
      blocks_fn = fn coord ->
        Coord.equal?(coord, a) or Coord.equal?(coord, b)
      end

      assert Grid.has_line_of_sight?(a, b, blocks_fn)
    end

    test "adjacent hexes always have LOS" do
      a = Coord.new(0, 0)
      b = Coord.new(1, 0)
      # Block everything - but adjacent hexes have no intermediate hexes
      blocks_fn = fn _ -> true end
      assert Grid.has_line_of_sight?(a, b, blocks_fn)
    end
  end

  describe "reachable_hexes/3" do
    test "returns starting hex with full movement" do
      start = Coord.new(0, 0)
      cost_fn = fn _ -> 1 end
      reachable = Grid.reachable_hexes(start, 2, cost_fn)

      assert Map.has_key?(reachable, Coord.to_key(start))
      assert reachable[Coord.to_key(start)] == 2
    end

    test "with zero movement only includes starting hex" do
      start = Coord.new(0, 0)
      cost_fn = fn _ -> 1 end
      reachable = Grid.reachable_hexes(start, 0, cost_fn)

      assert map_size(reachable) == 1
      assert Map.has_key?(reachable, Coord.to_key(start))
    end

    test "includes neighbors with movement cost 1" do
      start = Coord.new(0, 0)
      cost_fn = fn _ -> 1 end
      reachable = Grid.reachable_hexes(start, 1, cost_fn)

      # Should include start + 6 neighbors
      assert map_size(reachable) == 7
    end

    test "respects impassable terrain" do
      start = Coord.new(0, 0)
      blocked = Coord.new(1, 0)

      cost_fn = fn coord ->
        if Coord.equal?(coord, blocked), do: :impassable, else: 1
      end

      reachable = Grid.reachable_hexes(start, 2, cost_fn)

      refute Map.has_key?(reachable, Coord.to_key(blocked))
    end

    test "remaining movement decreases with cost" do
      start = Coord.new(0, 0)
      expensive = Coord.new(1, 0)

      cost_fn = fn coord ->
        if Coord.equal?(coord, expensive), do: 2, else: 1
      end

      reachable = Grid.reachable_hexes(start, 3, cost_fn)

      # Expensive hex should have 3 - 2 = 1 remaining
      assert reachable[Coord.to_key(expensive)] == 1
    end
  end

  describe "find_path/3" do
    test "path from hex to itself is just that hex" do
      start = Coord.new(0, 0)
      goal = Coord.new(0, 0)
      cost_fn = fn _ -> 1 end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      assert length(path) == 1
      assert Coord.equal?(hd(path), start)
    end

    test "finds path to adjacent hex" do
      start = Coord.new(0, 0)
      goal = Coord.new(1, 0)
      cost_fn = fn _ -> 1 end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      assert length(path) == 2
    end

    test "finds path to distant hex" do
      start = Coord.new(0, 0)
      goal = Coord.new(2, 0)
      cost_fn = fn _ -> 1 end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      assert length(path) == 3
    end

    test "path starts at start and ends at goal" do
      start = Coord.new(0, 0)
      goal = Coord.new(3, -1)
      cost_fn = fn _ -> 1 end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      assert Coord.equal?(hd(path), start)
      assert Coord.equal?(List.last(path), goal)
    end

    test "path hexes are all adjacent" do
      start = Coord.new(0, 0)
      goal = Coord.new(4, -2)
      cost_fn = fn _ -> 1 end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)

      path
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [from, to] ->
        assert Coord.distance(from, to) == 1
      end)
    end

    test "returns error when path is blocked" do
      start = Coord.new(0, 0)
      goal = Coord.new(3, 0)

      # Block all hexes except start
      cost_fn = fn coord ->
        if Coord.equal?(coord, start), do: 1, else: :impassable
      end

      assert {:error, :no_path} = Grid.find_path(start, goal, cost_fn)
    end

    test "finds path around obstacles" do
      start = Coord.new(0, 0)
      goal = Coord.new(2, 0)
      blocked = Coord.new(1, 0)

      cost_fn = fn coord ->
        if Coord.equal?(coord, blocked), do: :impassable, else: 1
      end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      # Path should go around the blocked hex
      refute Enum.any?(path, &Coord.equal?(&1, blocked))
    end

    test "prefers lower cost paths" do
      start = Coord.new(0, 0)
      goal = Coord.new(2, 0)
      expensive = Coord.new(1, 0)

      # Direct path is more expensive
      cost_fn = fn coord ->
        if Coord.equal?(coord, expensive), do: 10, else: 1
      end

      assert {:ok, path} = Grid.find_path(start, goal, cost_fn)
      # Should avoid the expensive hex
      refute Enum.any?(path, &Coord.equal?(&1, expensive))
    end
  end

  describe "direction_to/2" do
    test "returns direction to adjacent hex" do
      a = Coord.new(0, 0)
      b = Coord.new(1, 0)
      assert Grid.direction_to(a, b) == 0
    end

    test "returns nil for non-adjacent hexes" do
      a = Coord.new(0, 0)
      b = Coord.new(2, 0)
      assert Grid.direction_to(a, b) == nil
    end

    test "returns correct direction for all neighbors" do
      center = Coord.new(0, 0)

      for direction <- 0..5 do
        neighbor = Coord.neighbor(center, direction)
        assert Grid.direction_to(center, neighbor) == direction
      end
    end
  end

  describe "cone/4" do
    test "cone with width 0 returns hexes in a line" do
      origin = Coord.new(0, 0)
      cone = Grid.cone(origin, 0, 3, 0)

      # Should be 3 hexes in direction 0
      assert length(cone) == 3

      Enum.each(cone, fn hex ->
        assert hex.r == 0
        assert hex.q > 0
      end)
    end

    test "cone with width 1 spreads to adjacent directions" do
      origin = Coord.new(0, 0)
      cone = Grid.cone(origin, 0, 2, 1)

      # 3 directions * 2 range = 6 hexes max (may overlap)
      assert length(cone) > 0
      assert length(cone) <= 6
    end

    test "cone does not include origin" do
      origin = Coord.new(0, 0)
      cone = Grid.cone(origin, 0, 3, 2)

      refute Enum.any?(cone, &Coord.equal?(&1, origin))
    end

    test "cone with range 0 returns empty list" do
      origin = Coord.new(0, 0)
      cone = Grid.cone(origin, 0, 0, 2)
      assert cone == []
    end

    test "cone hexes are unique" do
      origin = Coord.new(0, 0)
      cone = Grid.cone(origin, 0, 3, 2)
      keys = Enum.map(cone, &Coord.to_key/1)
      assert length(keys) == length(Enum.uniq(keys))
    end
  end
end
