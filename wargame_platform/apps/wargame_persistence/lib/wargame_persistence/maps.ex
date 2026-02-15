defmodule WargamePersistence.Maps do
  @moduledoc "Context for map persistence operations."

  import Ecto.Query
  alias WargamePersistence.Repo
  alias WargamePersistence.Schemas.Map, as: MapSchema

  def list_maps(opts \\ []) do
    MapSchema
    |> filter_by_published(opts[:published])
    |> filter_by_author(opts[:author_id])
    |> order_by([m], desc: m.updated_at)
    |> Repo.all()
  end

  def get_map!(id), do: Repo.get!(MapSchema, id)

  def get_map(id), do: Repo.get(MapSchema, id)

  def create_map(attrs) do
    %MapSchema{}
    |> MapSchema.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_map(%MapSchema{} = map, attrs) do
    map
    |> MapSchema.changeset(attrs)
    |> Repo.update()
  end

  def delete_map(%MapSchema{} = map) do
    Repo.delete(map)
  end

  @doc """
  Save a WargameCore.Map struct to the database.
  Serializes tile_data to compressed binary.
  """
  def save_game_map(game_map, metadata \\ %{}) do
    tile_data = MapSchema.serialize_tile_data(game_map)

    attrs =
      metadata
      |> Map.put(:tile_data, tile_data)
      |> Map.put_new(:name, Map.get(game_map, :name, "Untitled"))
      |> Map.put_new(:width, Map.get(game_map, :width, 0))
      |> Map.put_new(:height, Map.get(game_map, :height, 0))

    case metadata[:id] do
      nil ->
        create_map(attrs)

      id ->
        case get_map(id) do
          nil -> create_map(attrs)
          existing -> update_map(existing, attrs)
        end
    end
  end

  @doc """
  Load a map from the database and deserialize tile_data.
  Returns a map with deserialized tiles under the :tiles key.
  """
  def load_game_map(id) do
    case get_map(id) do
      nil ->
        nil

      map_record ->
        tiles = MapSchema.deserialize_tile_data(map_record.tile_data)
        %{map_record | tile_data: nil} |> Map.from_struct() |> Map.put(:tiles, tiles)
    end
  end

  defp filter_by_published(query, nil), do: query
  defp filter_by_published(query, published), do: where(query, [m], m.published == ^published)

  defp filter_by_author(query, nil), do: query
  defp filter_by_author(query, author_id), do: where(query, [m], m.author_id == ^author_id)
end
