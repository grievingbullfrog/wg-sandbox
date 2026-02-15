defmodule WargamePersistence.MapsTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Maps

  @valid_attrs %{name: "Test Map", width: 20, height: 15, description: "A test"}

  describe "CRUD" do
    test "create_map/1 creates a map" do
      assert {:ok, map} = Maps.create_map(@valid_attrs)
      assert map.name == "Test Map"
      assert map.width == 20
    end

    test "get_map!/1 returns the map" do
      {:ok, map} = Maps.create_map(@valid_attrs)
      assert Maps.get_map!(map.id).name == "Test Map"
    end

    test "get_map/1 returns nil for missing id" do
      assert Maps.get_map(Ecto.UUID.generate()) == nil
    end

    test "update_map/2 updates the map" do
      {:ok, map} = Maps.create_map(@valid_attrs)
      assert {:ok, updated} = Maps.update_map(map, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "delete_map/1 deletes the map" do
      {:ok, map} = Maps.create_map(@valid_attrs)
      assert {:ok, _} = Maps.delete_map(map)
      assert Maps.get_map(map.id) == nil
    end

    test "list_maps/0 returns all maps" do
      {:ok, _} = Maps.create_map(@valid_attrs)
      {:ok, _} = Maps.create_map(%{@valid_attrs | name: "Map 2"})
      assert length(Maps.list_maps()) == 2
    end

    test "list_maps/1 filters by published" do
      {:ok, _} = Maps.create_map(Map.put(@valid_attrs, :published, true))
      {:ok, _} = Maps.create_map(Map.put(@valid_attrs, :published, false))
      assert length(Maps.list_maps(published: true)) == 1
      assert length(Maps.list_maps(published: false)) == 1
    end
  end

  describe "save_game_map/2 and load_game_map/1" do
    test "round-trips tile data" do
      tiles = %{
        "0,0" => %{terrain: :clear, elevation: 0},
        "1,0" => %{terrain: :forest_pine, elevation: 50}
      }

      game_map = %{tiles: tiles, name: "Test Game Map", width: 10, height: 10}
      assert {:ok, saved} = Maps.save_game_map(game_map)

      loaded = Maps.load_game_map(saved.id)
      assert loaded != nil
      assert loaded.tiles == tiles
      assert loaded.name == "Test Game Map"
    end
  end
end
