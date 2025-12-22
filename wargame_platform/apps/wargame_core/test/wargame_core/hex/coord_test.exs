defmodule WargameCore.Hex.CoordTest do
  use ExUnit.Case, async: true

  alias WargameCore.Hex.Coord

  describe "new/2" do
    test "creates a coordinate with given q and r values" do
      coord = Coord.new(3, 4)
      assert coord.q == 3
      assert coord.r == 4
    end

    test "creates origin coordinate" do
      coord = Coord.new(0, 0)
      assert coord.q == 0
      assert coord.r == 0
    end

    test "creates coordinate with negative values" do
      coord = Coord.new(-2, -5)
      assert coord.q == -2
      assert coord.r == -5
    end
  end

  describe "from_cube/3" do
    test "creates coordinate from valid cube coordinates" do
      assert {:ok, coord} = Coord.from_cube(1, -2, 1)
      assert coord.q == 1
      assert coord.r == -2
    end

    test "returns error for invalid cube coordinates" do
      assert {:error, :invalid_cube_coordinates} = Coord.from_cube(1, 1, 1)
    end

    test "accepts origin cube coordinates" do
      assert {:ok, coord} = Coord.from_cube(0, 0, 0)
      assert coord.q == 0
      assert coord.r == 0
    end
  end

  describe "s/1" do
    test "computes cube s coordinate" do
      coord = Coord.new(3, -1)
      assert Coord.s(coord) == -2
    end

    test "origin has s = 0" do
      coord = Coord.new(0, 0)
      assert Coord.s(coord) == 0
    end

    test "s satisfies q + r + s = 0" do
      coord = Coord.new(5, -3)
      assert coord.q + coord.r + Coord.s(coord) == 0
    end
  end

  describe "distance/2" do
    test "distance from a hex to itself is 0" do
      a = Coord.new(3, 4)
      assert Coord.distance(a, a) == 0
    end

    test "distance to adjacent hex is 1" do
      a = Coord.new(0, 0)
      b = Coord.new(1, 0)
      assert Coord.distance(a, b) == 1
    end

    test "calculates distance correctly for non-adjacent hexes" do
      a = Coord.new(0, 0)
      b = Coord.new(3, -1)
      assert Coord.distance(a, b) == 3
    end

    test "distance is symmetric" do
      a = Coord.new(2, 3)
      b = Coord.new(5, -1)
      assert Coord.distance(a, b) == Coord.distance(b, a)
    end
  end

  describe "add/2" do
    test "adds two coordinates" do
      a = Coord.new(1, 2)
      b = Coord.new(3, -1)
      result = Coord.add(a, b)
      assert result.q == 4
      assert result.r == 1
    end

    test "adding origin has no effect" do
      a = Coord.new(5, -3)
      origin = Coord.new(0, 0)
      result = Coord.add(a, origin)
      assert result.q == 5
      assert result.r == -3
    end
  end

  describe "subtract/2" do
    test "subtracts second coordinate from first" do
      a = Coord.new(4, 1)
      b = Coord.new(1, 2)
      result = Coord.subtract(a, b)
      assert result.q == 3
      assert result.r == -1
    end

    test "subtracting coordinate from itself gives origin" do
      a = Coord.new(5, -3)
      result = Coord.subtract(a, a)
      assert result.q == 0
      assert result.r == 0
    end
  end

  describe "scale/2" do
    test "scales coordinate by positive factor" do
      coord = Coord.new(2, 3)
      result = Coord.scale(coord, 2)
      assert result.q == 4
      assert result.r == 6
    end

    test "scaling by 1 has no effect" do
      coord = Coord.new(5, -3)
      result = Coord.scale(coord, 1)
      assert result.q == 5
      assert result.r == -3
    end

    test "scaling by 0 gives origin" do
      coord = Coord.new(5, -3)
      result = Coord.scale(coord, 0)
      assert result.q == 0
      assert result.r == 0
    end

    test "scaling by negative factor" do
      coord = Coord.new(2, -1)
      result = Coord.scale(coord, -2)
      assert result.q == -4
      assert result.r == 2
    end
  end

  describe "neighbor/2" do
    test "gets east neighbor (direction 0)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 0)
      assert result.q == 1
      assert result.r == 0
    end

    test "gets northeast neighbor (direction 1)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 1)
      assert result.q == 1
      assert result.r == -1
    end

    test "gets northwest neighbor (direction 2)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 2)
      assert result.q == 0
      assert result.r == -1
    end

    test "gets west neighbor (direction 3)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 3)
      assert result.q == -1
      assert result.r == 0
    end

    test "gets southwest neighbor (direction 4)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 4)
      assert result.q == -1
      assert result.r == 1
    end

    test "gets southeast neighbor (direction 5)" do
      coord = Coord.new(0, 0)
      result = Coord.neighbor(coord, 5)
      assert result.q == 0
      assert result.r == 1
    end
  end

  describe "neighbors/1" do
    test "returns all six neighbors" do
      coord = Coord.new(0, 0)
      neighbors = Coord.neighbors(coord)
      assert length(neighbors) == 6
    end

    test "all neighbors are at distance 1" do
      coord = Coord.new(3, 2)
      neighbors = Coord.neighbors(coord)

      Enum.each(neighbors, fn neighbor ->
        assert Coord.distance(coord, neighbor) == 1
      end)
    end

    test "neighbors are unique" do
      coord = Coord.new(0, 0)
      neighbors = Coord.neighbors(coord)
      keys = Enum.map(neighbors, &Coord.to_key/1)
      assert length(keys) == length(Enum.uniq(keys))
    end
  end

  describe "direction_vector/1" do
    test "returns correct vector for east" do
      assert Coord.direction_vector(0) == {1, 0}
    end

    test "returns correct vector for west" do
      assert Coord.direction_vector(3) == {-1, 0}
    end
  end

  describe "to_key/1 and from_key/1" do
    test "converts coordinate to string key" do
      coord = Coord.new(3, -2)
      assert Coord.to_key(coord) == "3,-2"
    end

    test "parses valid key back to coordinate" do
      assert {:ok, coord} = Coord.from_key("3,-2")
      assert coord.q == 3
      assert coord.r == -2
    end

    test "returns error for invalid key" do
      assert {:error, :invalid_key} = Coord.from_key("invalid")
    end

    test "returns error for key with non-integer values" do
      assert {:error, :invalid_key} = Coord.from_key("1.5,2")
    end

    test "roundtrips correctly" do
      original = Coord.new(-5, 10)
      key = Coord.to_key(original)
      {:ok, parsed} = Coord.from_key(key)
      assert Coord.equal?(original, parsed)
    end
  end

  describe "to_pixel/2 and from_pixel/3" do
    test "converts coordinate to pixel position" do
      coord = Coord.new(1, 1)
      {x, y} = Coord.to_pixel(coord, 40)
      assert is_float(x)
      assert is_float(y)
    end

    test "origin maps to (0, 0)" do
      coord = Coord.new(0, 0)
      {x, y} = Coord.to_pixel(coord, 40)
      assert_in_delta x, 0.0, 0.0001
      assert_in_delta y, 0.0, 0.0001
    end

    test "from_pixel is inverse of to_pixel" do
      original = Coord.new(3, 2)
      {x, y} = Coord.to_pixel(original, 40)
      result = Coord.from_pixel(x, y, 40)
      assert Coord.equal?(original, result)
    end
  end

  describe "hex_round/2" do
    test "rounds fractional coordinates to nearest hex" do
      # Near origin
      result = Coord.hex_round(0.1, 0.1)
      assert result.q == 0
      assert result.r == 0
    end

    test "rounds correctly at boundaries" do
      result = Coord.hex_round(0.4, 0.4)
      # Should round to some valid hex
      assert is_integer(result.q)
      assert is_integer(result.r)
    end
  end

  describe "equal?/2" do
    test "returns true for equal coordinates" do
      a = Coord.new(1, 2)
      b = Coord.new(1, 2)
      assert Coord.equal?(a, b)
    end

    test "returns false for different coordinates" do
      a = Coord.new(1, 2)
      b = Coord.new(2, 1)
      refute Coord.equal?(a, b)
    end
  end

  describe "opposite_direction/1" do
    test "opposite of east is west" do
      assert Coord.opposite_direction(0) == 3
    end

    test "opposite of northeast is southwest" do
      assert Coord.opposite_direction(1) == 4
    end

    test "opposite of opposite is original" do
      direction = 2
      assert Coord.opposite_direction(Coord.opposite_direction(direction)) == direction
    end
  end

  describe "rotate_direction/2" do
    test "rotates direction by positive steps" do
      assert Coord.rotate_direction(0, 1) == 1
    end

    test "rotates direction wrapping around" do
      assert Coord.rotate_direction(5, 2) == 1
    end

    test "rotates by negative steps" do
      assert Coord.rotate_direction(1, -1) == 0
    end

    test "rotation by 6 returns to original" do
      assert Coord.rotate_direction(3, 6) == 3
    end
  end

  describe "direction_to/2" do
    test "returns direction to adjacent coordinate" do
      from = Coord.new(0, 0)
      to = Coord.new(1, 0)
      assert Coord.direction_to(from, to) == 0
    end

    test "returns nil for non-adjacent coordinates" do
      from = Coord.new(0, 0)
      to = Coord.new(2, 0)
      assert Coord.direction_to(from, to) == nil
    end

    test "returns correct direction for each neighbor" do
      center = Coord.new(0, 0)

      for direction <- 0..5 do
        neighbor = Coord.neighbor(center, direction)
        assert Coord.direction_to(center, neighbor) == direction
      end
    end
  end
end
