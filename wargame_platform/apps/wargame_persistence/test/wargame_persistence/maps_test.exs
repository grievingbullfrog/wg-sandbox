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

  describe "list_maps/1 filters by author" do
    test "filters by author_id" do
      {:ok, user} =
        %WargamePersistence.Schemas.User{}
        |> WargamePersistence.Schemas.User.changeset(%{
          username: "mapmaker",
          email: "maps@example.com"
        })
        |> WargamePersistence.Repo.insert()

      {:ok, _owned} = Maps.create_map(Map.put(@valid_attrs, :author_id, user.id))
      {:ok, _other} = Maps.create_map(%{@valid_attrs | name: "Other Map"})

      assert length(Maps.list_maps(author_id: user.id)) == 1
    end
  end

  describe "create_map/1 error paths" do
    test "returns error for missing required fields" do
      assert {:error, changeset} = Maps.create_map(%{})
      refute changeset.valid?
    end

    test "returns error for invalid width" do
      assert {:error, changeset} = Maps.create_map(%{@valid_attrs | width: -1})
      refute changeset.valid?
    end
  end

  describe "save_game_map/2 and load_game_map/1" do
    test "round-trips tile data on create" do
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

    test "updates existing map when id provided in metadata" do
      tiles_v1 = %{"0,0" => %{terrain: :clear}}
      tiles_v2 = %{"0,0" => %{terrain: :forest_pine}, "1,0" => %{terrain: :marsh}}

      game_map_v1 = %{tiles: tiles_v1, name: "My Map", width: 5, height: 5}
      assert {:ok, saved} = Maps.save_game_map(game_map_v1)

      game_map_v2 = %{tiles: tiles_v2, name: "My Map Updated", width: 5, height: 5}
      assert {:ok, updated} = Maps.save_game_map(game_map_v2, %{id: saved.id})

      assert updated.id == saved.id
      loaded = Maps.load_game_map(saved.id)
      assert loaded.tiles == tiles_v2
      assert loaded.name == "My Map Updated"
    end

    test "creates new map when id provided but not found" do
      game_map = %{tiles: %{}, name: "New Map", width: 3, height: 3}
      fake_id = Ecto.UUID.generate()
      assert {:ok, created} = Maps.save_game_map(game_map, %{id: fake_id})
      assert created.id != fake_id
    end

    test "load_game_map/1 returns nil for missing id" do
      assert Maps.load_game_map(Ecto.UUID.generate()) == nil
    end
  end
end
