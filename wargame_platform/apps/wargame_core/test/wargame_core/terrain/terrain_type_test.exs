defmodule WargameCore.Terrain.TerrainTypeTest do
  use ExUnit.Case, async: true

  alias WargameCore.Terrain.TerrainType

  describe "all/0" do
    test "returns list of all terrain types" do
      all = TerrainType.all()
      assert is_list(all)
      assert length(all) == 20
    end

    test "all terrain types have required fields" do
      Enum.each(TerrainType.all(), fn terrain ->
        assert is_atom(terrain.id)
        assert is_binary(terrain.name)
        assert is_map(terrain.movement_costs)
        assert is_integer(terrain.defense_modifier)
        assert is_boolean(terrain.blocks_los)
        assert is_boolean(terrain.concealment)
        assert is_boolean(terrain.fortifiable)
        assert is_integer(terrain.color)
      end)
    end

    test "all terrain types have unique ids" do
      ids = TerrainType.all() |> Enum.map(& &1.id)
      assert length(ids) == length(Enum.uniq(ids))
    end
  end

  describe "get/1" do
    test "returns terrain type by id" do
      terrain = TerrainType.get(:clear)
      assert terrain.id == :clear
      assert terrain.name == "Clear"
    end

    test "returns nil for unknown terrain" do
      assert TerrainType.get(:nonexistent) == nil
    end

    test "can get all predefined terrains" do
      terrain_ids = [
        :clear,
        :forest_pine,
        :forest_deciduous,
        :hill,
        :mountain,
        :desert,
        :farmland,
        :pasture,
        :swamp,
        :marsh,
        :lake,
        :river,
        :ocean,
        :urban,
        :village,
        :ruins,
        :road,
        :railroad,
        :fortification,
        :minefield
      ]

      Enum.each(terrain_ids, fn id ->
        terrain = TerrainType.get(id)
        assert terrain != nil, "Expected terrain #{id} to exist"
        assert terrain.id == id
      end)
    end
  end

  describe "movement_cost/2" do
    test "returns defined cost for unit category" do
      terrain = TerrainType.clear()
      assert TerrainType.movement_cost(terrain, :infantry) == 1
    end

    test "returns default cost for undefined category" do
      terrain = TerrainType.clear()
      # Leader is not explicitly defined, should get default
      assert TerrainType.movement_cost(terrain, :leader) == 1
    end

    test "returns :impassable for impassable terrain" do
      terrain = TerrainType.lake()
      assert TerrainType.movement_cost(terrain, :infantry) == :impassable
    end

    test "armor cannot enter mountains" do
      terrain = TerrainType.mountain()
      assert TerrainType.movement_cost(terrain, :armor) == :impassable
    end

    test "roads have reduced movement cost" do
      terrain = TerrainType.road()
      assert TerrainType.movement_cost(terrain, :infantry) == 0.5
      assert TerrainType.movement_cost(terrain, :armor) == 0.5
    end
  end

  describe "clear/0" do
    test "has correct properties" do
      terrain = TerrainType.clear()

      assert terrain.id == :clear
      assert terrain.defense_modifier == 0
      refute terrain.blocks_los
      refute terrain.concealment
      assert terrain.fortifiable
    end

    test "has standard movement cost of 1 for all units" do
      terrain = TerrainType.clear()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 1
      end)
    end
  end

  describe "forest_pine/0" do
    test "has correct properties" do
      terrain = TerrainType.forest_pine()

      assert terrain.id == :forest_pine
      assert terrain.defense_modifier == 2
      assert terrain.blocks_los
      assert terrain.concealment
      assert terrain.fortifiable
    end

    test "has higher movement cost for vehicles" do
      terrain = TerrainType.forest_pine()

      assert TerrainType.movement_cost(terrain, :infantry) == 2
      assert TerrainType.movement_cost(terrain, :armor) == 3
      assert TerrainType.movement_cost(terrain, :motorized) == 4
    end
  end

  describe "mountain/0" do
    test "is impassable for vehicles" do
      terrain = TerrainType.mountain()

      assert TerrainType.movement_cost(terrain, :armor) == :impassable
      assert TerrainType.movement_cost(terrain, :motorized) == :impassable
      assert TerrainType.movement_cost(terrain, :artillery) == :impassable
    end

    test "infantry can enter but slowly" do
      terrain = TerrainType.mountain()
      assert TerrainType.movement_cost(terrain, :infantry) == 3
    end

    test "provides strong defense" do
      terrain = TerrainType.mountain()
      assert terrain.defense_modifier == 3
    end
  end

  describe "swamp/0" do
    test "is impassable for vehicles" do
      terrain = TerrainType.swamp()

      assert TerrainType.movement_cost(terrain, :armor) == :impassable
      assert TerrainType.movement_cost(terrain, :motorized) == :impassable
    end

    test "is not fortifiable" do
      terrain = TerrainType.swamp()
      refute terrain.fortifiable
    end

    test "provides concealment" do
      terrain = TerrainType.swamp()
      assert terrain.concealment
    end
  end

  describe "lake/0" do
    test "is impassable for all ground units" do
      terrain = TerrainType.lake()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == :impassable
      end)
    end

    test "is not fortifiable" do
      terrain = TerrainType.lake()
      refute terrain.fortifiable
    end
  end

  describe "urban/0" do
    test "provides strong defense" do
      terrain = TerrainType.urban()
      assert terrain.defense_modifier == 3
    end

    test "blocks LOS" do
      terrain = TerrainType.urban()
      assert terrain.blocks_los
    end

    test "provides concealment" do
      terrain = TerrainType.urban()
      assert terrain.concealment
    end

    test "slows armor" do
      terrain = TerrainType.urban()
      assert TerrainType.movement_cost(terrain, :armor) == 2
    end
  end

  describe "road/0" do
    test "has reduced movement cost" do
      terrain = TerrainType.road()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 0.5
      end)
    end

    test "has negative defense modifier" do
      terrain = TerrainType.road()
      assert terrain.defense_modifier == -1
    end

    test "is not fortifiable" do
      terrain = TerrainType.road()
      refute terrain.fortifiable
    end
  end

  describe "fortification/0" do
    test "blocks vehicles" do
      terrain = TerrainType.fortification()

      assert TerrainType.movement_cost(terrain, :armor) == :impassable
      assert TerrainType.movement_cost(terrain, :motorized) == :impassable
    end

    test "allows infantry" do
      terrain = TerrainType.fortification()
      assert TerrainType.movement_cost(terrain, :infantry) == 1
    end

    test "provides very strong defense" do
      terrain = TerrainType.fortification()
      assert terrain.defense_modifier == 4
    end
  end

  describe "minefield/0" do
    test "has high movement cost for all units" do
      terrain = TerrainType.minefield()

      assert TerrainType.movement_cost(terrain, :infantry) == 3
      assert TerrainType.movement_cost(terrain, :armor) == 4
    end

    test "engineers have lower cost" do
      terrain = TerrainType.minefield()
      assert TerrainType.movement_cost(terrain, :engineer) == 2
    end

    test "provides no defense modifier" do
      terrain = TerrainType.minefield()
      assert terrain.defense_modifier == 0
    end
  end
end
