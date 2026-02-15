defmodule WargamePersistence.Schemas.MapTest do
  use WargamePersistence.DataCase, async: true

  alias WargamePersistence.Schemas.Map, as: MapSchema

  @valid_attrs %{name: "Test Map", width: 20, height: 15}

  describe "changeset/2" do
    test "valid attrs produce valid changeset" do
      changeset = MapSchema.changeset(%MapSchema{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = MapSchema.changeset(%MapSchema{}, Map.delete(@valid_attrs, :name))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "requires width" do
      changeset = MapSchema.changeset(%MapSchema{}, Map.delete(@valid_attrs, :width))
      refute changeset.valid?
    end

    test "requires height" do
      changeset = MapSchema.changeset(%MapSchema{}, Map.delete(@valid_attrs, :height))
      refute changeset.valid?
    end

    test "validates width > 0" do
      changeset = MapSchema.changeset(%MapSchema{}, %{@valid_attrs | width: 0})
      refute changeset.valid?
    end

    test "validates height > 0" do
      changeset = MapSchema.changeset(%MapSchema{}, %{@valid_attrs | height: -1})
      refute changeset.valid?
    end

    test "accepts optional fields" do
      attrs = Map.merge(@valid_attrs, %{
        description: "A test map",
        scale: 500,
        base_elevation: 100,
        centerpoint_lat: 52.5,
        centerpoint_lng: 13.4,
        default_terrain: "forest_pine",
        published: true
      })

      changeset = MapSchema.changeset(%MapSchema{}, attrs)
      assert changeset.valid?
    end
  end

  describe "serialize/deserialize tile_data" do
    test "round-trips tile data through serialization" do
      tiles = %{
        "0,0" => %{terrain: :clear, elevation: 0},
        "1,0" => %{terrain: :forest_pine, elevation: 50}
      }

      binary = MapSchema.serialize_tile_data(%{tiles: tiles})
      assert is_binary(binary)

      result = MapSchema.deserialize_tile_data(binary)
      assert result == tiles
    end

    test "deserialize nil returns empty map" do
      assert MapSchema.deserialize_tile_data(nil) == %{}
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
