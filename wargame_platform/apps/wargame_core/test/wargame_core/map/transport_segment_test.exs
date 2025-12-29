defmodule WargameCore.Map.TransportSegmentTest do
  use ExUnit.Case, async: true

  alias WargameCore.Map.TransportSegment

  describe "new/3" do
    test "creates a transport segment with type and edges" do
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      assert segment.type == :small_paved_road
      assert segment.entry_edges == [0]
      assert segment.exit_edges == [3]
    end

    test "creates a segment with multiple entry edges" do
      segment = TransportSegment.new(:railroad, [1, 4], [])

      assert segment.type == :railroad
      assert segment.entry_edges == [1, 4]
      assert segment.exit_edges == []
    end

    test "creates a segment with empty edges" do
      segment = TransportSegment.new(:trail)

      assert segment.type == :trail
      assert segment.entry_edges == []
      assert segment.exit_edges == []
    end

    test "filters out invalid edge numbers" do
      segment = TransportSegment.new(:small_paved_road, [0, 7, -1], [3, 10])

      assert segment.entry_edges == [0]
      assert segment.exit_edges == [3]
    end
  end

  describe "all_types/0" do
    test "returns all valid segment types" do
      types = TransportSegment.all_types()

      assert :trail in types
      assert :small_unpaved_road in types
      assert :large_unpaved_road in types
      assert :small_paved_road in types
      assert :large_paved_road in types
      assert :railroad in types
      assert :double_track_railroad in types
      assert :triple_track_railroad in types
      assert :runway in types
      assert length(types) == 9
    end
  end

  describe "type_name/1" do
    test "returns readable name for trail" do
      assert TransportSegment.type_name(:trail) == "Trail"
    end

    test "returns readable name for small_paved_road" do
      assert TransportSegment.type_name(:small_paved_road) == "Small Paved Road"
    end

    test "returns readable name for railroad" do
      assert TransportSegment.type_name(:railroad) == "Railroad"
    end

    test "returns readable name for runway" do
      assert TransportSegment.type_name(:runway) == "Runway"
    end
  end

  describe "all_edges/1" do
    test "returns combined entry and exit edges" do
      segment = TransportSegment.new(:small_paved_road, [0, 1], [3, 4])
      edges = TransportSegment.all_edges(segment)

      assert 0 in edges
      assert 1 in edges
      assert 3 in edges
      assert 4 in edges
    end

    test "returns unique edges when overlap" do
      segment = TransportSegment.new(:small_paved_road, [0, 3], [3, 4])
      edges = TransportSegment.all_edges(segment)

      assert length(edges) == 3
      assert Enum.sort(edges) == [0, 3, 4]
    end
  end

  describe "connects_to?/2" do
    test "returns true for entry edge" do
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      assert TransportSegment.connects_to?(segment, 0)
    end

    test "returns true for exit edge" do
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      assert TransportSegment.connects_to?(segment, 3)
    end

    test "returns false for non-connected edge" do
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      refute TransportSegment.connects_to?(segment, 1)
      refute TransportSegment.connects_to?(segment, 2)
    end
  end

  describe "dead_end?/1" do
    test "returns true when no exit edges" do
      segment = TransportSegment.new(:trail, [0], [])

      assert TransportSegment.dead_end?(segment)
    end

    test "returns false when exit edges present" do
      segment = TransportSegment.new(:trail, [0], [3])

      refute TransportSegment.dead_end?(segment)
    end
  end

  describe "through_segment?/1" do
    test "returns true when both entry and exit edges" do
      segment = TransportSegment.new(:small_paved_road, [0], [3])

      assert TransportSegment.through_segment?(segment)
    end

    test "returns false when no exit edges" do
      segment = TransportSegment.new(:trail, [0], [])

      refute TransportSegment.through_segment?(segment)
    end

    test "returns false when no entry edges" do
      segment = TransportSegment.new(:trail, [], [3])

      refute TransportSegment.through_segment?(segment)
    end

    test "returns false when no edges at all" do
      segment = TransportSegment.new(:trail)

      refute TransportSegment.through_segment?(segment)
    end
  end
end
