defmodule WargameCore.Terrain.TerrainTypeTest do
  use ExUnit.Case, async: true

  alias WargameCore.Terrain.TerrainType

  describe "all/0" do
    test "returns list of all terrain types" do
      all = TerrainType.all()
      assert is_list(all)
      assert length(all) == 16
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
        :marsh,
        :orchard,
        :light_urban,
        :heavy_urban,
        :industrial,
        :desert,
        :semi_arid,
        :tundra,
        :arctic,
        :freshwater_lake,
        :frozen_lake,
        :ocean,
        :frozen_ocean
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
      terrain = TerrainType.freshwater_lake()
      assert TerrainType.movement_cost(terrain, :infantry) == :impassable
    end

    test "ocean is impassable for armor" do
      terrain = TerrainType.ocean()
      assert TerrainType.movement_cost(terrain, :armor) == :impassable
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

  describe "marsh/0" do
    test "has correct properties" do
      terrain = TerrainType.marsh()

      assert terrain.id == :marsh
      assert terrain.defense_modifier == 1
      refute terrain.blocks_los
      assert terrain.concealment
      refute terrain.fortifiable
    end

    test "slows vehicles more than infantry" do
      terrain = TerrainType.marsh()

      assert TerrainType.movement_cost(terrain, :infantry) == 2
      assert TerrainType.movement_cost(terrain, :armor) == 3
      assert TerrainType.movement_cost(terrain, :motorized) == 4
    end
  end

  describe "freshwater_lake/0" do
    test "is impassable for all ground units" do
      terrain = TerrainType.freshwater_lake()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == :impassable
      end)
    end

    test "is not fortifiable" do
      terrain = TerrainType.freshwater_lake()
      refute terrain.fortifiable
    end
  end

  describe "light_urban/0" do
    test "provides good defense" do
      terrain = TerrainType.light_urban()
      assert terrain.defense_modifier == 2
    end

    test "blocks LOS" do
      terrain = TerrainType.light_urban()
      assert terrain.blocks_los
    end

    test "provides concealment" do
      terrain = TerrainType.light_urban()
      assert terrain.concealment
    end

    test "slows armor" do
      terrain = TerrainType.light_urban()
      assert TerrainType.movement_cost(terrain, :armor) == 2
    end
  end

  describe "heavy_urban/0" do
    test "provides strong defense" do
      terrain = TerrainType.heavy_urban()
      assert terrain.defense_modifier == 3
    end

    test "blocks LOS" do
      terrain = TerrainType.heavy_urban()
      assert terrain.blocks_los
    end

    test "provides concealment" do
      terrain = TerrainType.heavy_urban()
      assert terrain.concealment
    end

    test "slows all units" do
      terrain = TerrainType.heavy_urban()
      assert TerrainType.movement_cost(terrain, :infantry) == 2
      assert TerrainType.movement_cost(terrain, :armor) == 3
    end
  end

  describe "desert/0" do
    test "has correct properties" do
      terrain = TerrainType.desert()

      assert terrain.id == :desert
      assert terrain.defense_modifier == 0
      refute terrain.blocks_los
      refute terrain.concealment
      assert terrain.fortifiable
    end

    test "has standard movement cost" do
      terrain = TerrainType.desert()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 1
      end)
    end
  end

  describe "ocean/0" do
    test "is impassable for all ground units" do
      terrain = TerrainType.ocean()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == :impassable
      end)
    end

    test "is not fortifiable" do
      terrain = TerrainType.ocean()
      refute terrain.fortifiable
    end
  end

  describe "orchard/0" do
    test "has correct properties" do
      terrain = TerrainType.orchard()

      assert terrain.id == :orchard
      assert terrain.name == "Orchard"
      assert terrain.defense_modifier == 1
      assert terrain.blocks_los
      assert terrain.concealment
      assert terrain.fortifiable
      assert terrain.color == 0x9ACD32
    end

    test "has moderate movement cost for all units" do
      terrain = TerrainType.orchard()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 2
      end)
    end
  end

  describe "semi_arid/0" do
    test "has correct properties" do
      terrain = TerrainType.semi_arid()

      assert terrain.id == :semi_arid
      assert terrain.name == "Semi-Arid"
      assert terrain.defense_modifier == 0
      refute terrain.blocks_los
      refute terrain.concealment
      assert terrain.fortifiable
      assert terrain.color == 0xC2B280
    end

    test "has standard movement cost like clear" do
      terrain = TerrainType.semi_arid()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 1
      end)
    end
  end

  describe "tundra/0" do
    test "has correct properties" do
      terrain = TerrainType.tundra()

      assert terrain.id == :tundra
      assert terrain.name == "Tundra"
      assert terrain.defense_modifier == 0
      refute terrain.blocks_los
      refute terrain.concealment
      assert terrain.fortifiable
      assert terrain.color == 0x8B8682
    end

    test "has moderate movement cost for all units" do
      terrain = TerrainType.tundra()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 2
      end)
    end
  end

  describe "arctic/0" do
    test "has correct properties" do
      terrain = TerrainType.arctic()

      assert terrain.id == :arctic
      assert terrain.name == "Arctic"
      assert terrain.defense_modifier == 0
      refute terrain.blocks_los
      refute terrain.concealment
      refute terrain.fortifiable
      assert terrain.color == 0xE8E8E8
    end

    test "has high movement cost for all units" do
      terrain = TerrainType.arctic()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 3
      end)
    end
  end

  describe "frozen_lake/0" do
    test "has correct properties" do
      terrain = TerrainType.frozen_lake()

      assert terrain.id == :frozen_lake
      assert terrain.name == "Frozen Lake"
      assert terrain.defense_modifier == -1
      refute terrain.blocks_los
      refute terrain.concealment
      refute terrain.fortifiable
      assert terrain.color == 0xB0E0E6
    end

    test "infantry moves easily, armor slowed" do
      terrain = TerrainType.frozen_lake()

      assert TerrainType.movement_cost(terrain, :infantry) == 1
      assert TerrainType.movement_cost(terrain, :armor) == 2
    end
  end

  describe "frozen_ocean/0" do
    test "has correct properties" do
      terrain = TerrainType.frozen_ocean()

      assert terrain.id == :frozen_ocean
      assert terrain.name == "Frozen Ocean"
      assert terrain.defense_modifier == -1
      refute terrain.blocks_los
      refute terrain.concealment
      refute terrain.fortifiable
      assert terrain.color == 0xADD8E6
    end

    test "has moderate movement cost for all units" do
      terrain = TerrainType.frozen_ocean()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 2
      end)
    end
  end

  describe "industrial/0" do
    test "has correct properties" do
      terrain = TerrainType.industrial()

      assert terrain.id == :industrial
      assert terrain.name == "Industrial"
      assert terrain.defense_modifier == 2
      assert terrain.blocks_los
      assert terrain.concealment
      assert terrain.fortifiable
      assert terrain.color == 0x505050
    end

    test "has moderate movement cost for all units" do
      terrain = TerrainType.industrial()

      Enum.each([:infantry, :armor, :motorized, :artillery, :recon, :engineer], fn category ->
        assert TerrainType.movement_cost(terrain, category) == 2
      end)
    end
  end
end
