defmodule WargameCore.Map do
  @moduledoc """
  Represents a hex-based wargame map.

  A map consists of:
  - Dimensions (width x height in hexes)
  - Scale (meters per hex)
  - All tiles stored in a coordinate-indexed structure
  - Metadata (name, description, etc.)

  The map uses axial coordinates where:
  - q increases to the right
  - r increases downward (pointy-top orientation)
  """

  alias WargameCore.Hex.Coord
  alias WargameCore.Hex.Grid
  alias WargameCore.Map.Tile

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t(),
          version: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          scale: pos_integer(),
          base_elevation: integer(),
          centerpoint_lat: float() | nil,
          centerpoint_lng: float() | nil,
          tiles: %{Coord.t() => Tile.t()},
          default_terrain: atom(),
          metadata: map()
        }

  @enforce_keys [:name, :width, :height, :scale]
  defstruct [
    :id,
    :name,
    :width,
    :height,
    :scale,
    description: "",
    version: "1.0",
    base_elevation: 0,
    centerpoint_lat: nil,
    centerpoint_lng: nil,
    tiles: %{},
    default_terrain: :clear,
    metadata: %{}
  ]

  @doc """
  Creates a new empty map with the given dimensions.

  All tiles are initialized with the default terrain.

  ## Parameters
  - name: Map name
  - width: Width in hexes
  - height: Height in hexes
  - scale: Meters per hex
  - opts: Optional parameters
    - :default_terrain - Terrain type for all initial tiles (default: :clear)
    - :description - Map description
    - :version - Map version string (default: "1.0")
    - :base_elevation - Base elevation in meters (default: 0)
    - :centerpoint_lat - Latitude of map center (default: nil)
    - :centerpoint_lng - Longitude of map center (default: nil)

  ## Examples

      iex> map = WargameCore.Map.new("Test Map", 10, 10, 200)
      iex> map.width
      10
      iex> map.scale
      200
  """
  @spec new(String.t(), pos_integer(), pos_integer(), pos_integer(), keyword()) :: t()
  def new(name, width, height, scale, opts \\ [])
      when is_binary(name) and width > 0 and height > 0 and scale > 0 do
    default_terrain = Keyword.get(opts, :default_terrain, :clear)
    description = Keyword.get(opts, :description, "")
    version = Keyword.get(opts, :version, "1.0")
    base_elevation = Keyword.get(opts, :base_elevation, 0)
    centerpoint_lat = Keyword.get(opts, :centerpoint_lat, nil)
    centerpoint_lng = Keyword.get(opts, :centerpoint_lng, nil)

    tiles =
      for q <- 0..(width - 1), r <- 0..(height - 1), into: %{} do
        coord = Coord.new(q, r)
        {coord, Tile.new(coord, default_terrain)}
      end

    %__MODULE__{
      name: name,
      width: width,
      height: height,
      scale: scale,
      version: version,
      base_elevation: base_elevation,
      centerpoint_lat: centerpoint_lat,
      centerpoint_lng: centerpoint_lng,
      description: description,
      tiles: tiles,
      default_terrain: default_terrain
    }
  end

  @doc """
  Gets a tile at the given coordinate.

  Returns nil if the coordinate is outside the map bounds.
  """
  @spec get_tile(t(), Coord.t()) :: Tile.t() | nil
  def get_tile(%__MODULE__{tiles: tiles}, %Coord{} = coord) do
    Map.get(tiles, coord)
  end

  @doc """
  Updates a tile at the given coordinate.

  Returns {:error, :out_of_bounds} if the coordinate is outside the map.
  """
  @spec put_tile(t(), Coord.t(), Tile.t()) :: {:ok, t()} | {:error, :out_of_bounds}
  def put_tile(%__MODULE__{tiles: tiles} = map, %Coord{} = coord, %Tile{} = tile) do
    if in_bounds?(map, coord) do
      {:ok, %{map | tiles: Map.put(tiles, coord, tile)}}
    else
      {:error, :out_of_bounds}
    end
  end

  @doc """
  Updates a tile using a function.

  The function receives the current tile and should return the updated tile.
  """
  @spec update_tile(t(), Coord.t(), (Tile.t() -> Tile.t())) ::
          {:ok, t()} | {:error, :out_of_bounds}
  def update_tile(%__MODULE__{tiles: tiles} = map, %Coord{} = coord, fun) when is_function(fun) do
    case Map.get(tiles, coord) do
      nil ->
        {:error, :out_of_bounds}

      tile ->
        updated_tile = fun.(tile)
        {:ok, %{map | tiles: Map.put(tiles, coord, updated_tile)}}
    end
  end

  @doc """
  Sets the terrain of a tile at the given coordinate.
  """
  @spec set_terrain(t(), Coord.t(), atom()) :: {:ok, t()} | {:error, :out_of_bounds}
  def set_terrain(%__MODULE__{} = map, %Coord{} = coord, terrain) when is_atom(terrain) do
    update_tile(map, coord, fn tile -> %{tile | terrain: terrain} end)
  end

  @doc """
  Sets the elevation of a tile at the given coordinate.
  """
  @spec set_elevation(t(), Coord.t(), integer()) :: {:ok, t()} | {:error, :out_of_bounds}
  def set_elevation(%__MODULE__{} = map, %Coord{} = coord, elevation) when is_integer(elevation) do
    update_tile(map, coord, fn tile -> %{tile | elevation: elevation} end)
  end

  @doc """
  Checks if a coordinate is within the map bounds.
  """
  @spec in_bounds?(t(), Coord.t()) :: boolean()
  def in_bounds?(%__MODULE__{width: width, height: height}, %Coord{q: q, r: r}) do
    q >= 0 and q < width and r >= 0 and r < height
  end

  @doc """
  Returns all coordinates that are within the map bounds.
  """
  @spec all_coords(t()) :: [Coord.t()]
  def all_coords(%__MODULE__{width: width, height: height}) do
    for q <- 0..(width - 1), r <- 0..(height - 1) do
      Coord.new(q, r)
    end
  end

  @doc """
  Returns all tiles as a list.
  """
  @spec all_tiles(t()) :: [Tile.t()]
  def all_tiles(%__MODULE__{tiles: tiles}) do
    Map.values(tiles)
  end

  @doc """
  Gets neighboring tiles for a coordinate, excluding those outside map bounds.
  """
  @spec neighbors(t(), Coord.t()) :: [Tile.t()]
  def neighbors(%__MODULE__{} = map, %Coord{} = coord) do
    coord
    |> Coord.neighbors()
    |> Enum.map(&get_tile(map, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets tiles within a range of a coordinate, excluding those outside map bounds.
  """
  @spec tiles_in_range(t(), Coord.t(), non_neg_integer()) :: [Tile.t()]
  def tiles_in_range(%__MODULE__{} = map, %Coord{} = center, range) do
    center
    |> Grid.hexes_in_range(range)
    |> Enum.map(&get_tile(map, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Finds a path between two coordinates on the map using A* pathfinding.

  The movement cost function considers terrain and unit category.
  """
  @spec find_path(t(), Coord.t(), Coord.t(), atom(), keyword()) ::
          {:ok, [Coord.t()]} | {:error, :no_path | :out_of_bounds}
  def find_path(%__MODULE__{} = map, %Coord{} = from, %Coord{} = to, category, opts \\ []) do
    if not in_bounds?(map, from) or not in_bounds?(map, to) do
      {:error, :out_of_bounds}
    else
      from_direction = Keyword.get(opts, :from_direction, nil)

      cost_fn = fn coord ->
        case get_tile(map, coord) do
          nil -> :impassable
          tile -> Tile.movement_cost(tile, category, from_direction)
        end
      end

      Grid.find_path(from, to, cost_fn)
    end
  end

  @doc """
  Finds all hexes reachable from a starting position within a movement budget.
  """
  @spec reachable_hexes(t(), Coord.t(), number(), atom()) :: %{Coord.t() => number()}
  def reachable_hexes(%__MODULE__{} = map, %Coord{} = start, movement_points, category) do
    cost_fn = fn coord ->
      case get_tile(map, coord) do
        nil -> :impassable
        tile -> Tile.movement_cost(tile, category)
      end
    end

    Grid.reachable_hexes(start, movement_points, cost_fn)
  end

  @doc """
  Checks if there is line of sight between two coordinates on the map.

  Takes into account terrain that blocks LOS and elevation differences.
  """
  @spec has_line_of_sight?(t(), Coord.t(), Coord.t()) :: boolean()
  def has_line_of_sight?(%__MODULE__{} = map, %Coord{} = from, %Coord{} = to) do
    from_tile = get_tile(map, from)
    to_tile = get_tile(map, to)

    if is_nil(from_tile) or is_nil(to_tile) do
      false
    else
      from_elevation = from_tile.elevation
      to_elevation = to_tile.elevation

      blocks_fn = fn coord ->
        case get_tile(map, coord) do
          nil ->
            true

          tile ->
            # Check if terrain blocks LOS
            if Tile.blocks_los?(tile) do
              # Blocking terrain only blocks if it's at or above the highest endpoint
              # (i.e., you can see over lower blocking terrain from higher ground)
              tile.elevation >= min(from_elevation, to_elevation)
            else
              false
            end
        end
      end

      Grid.has_line_of_sight?(from, to, blocks_fn)
    end
  end

  @doc """
  Gets all tiles controlled by a specific side.
  """
  @spec tiles_controlled_by(t(), atom()) :: [Tile.t()]
  def tiles_controlled_by(%__MODULE__{tiles: tiles}, side) do
    tiles
    |> Map.values()
    |> Enum.filter(fn tile -> tile.control == side end)
  end

  @doc """
  Calculates total victory points controlled by a side.
  """
  @spec victory_points_for(t(), atom()) :: non_neg_integer()
  def victory_points_for(%__MODULE__{} = map, side) do
    map
    |> tiles_controlled_by(side)
    |> Enum.reduce(0, fn tile, acc -> acc + tile.victory_points end)
  end

  @doc """
  Adds an edge feature between two adjacent hexes.

  This sets the feature on both hexes for the shared edge.
  """
  @spec add_edge_feature(t(), Coord.t(), Coord.t(), Tile.edge_feature()) ::
          {:ok, t()} | {:error, :out_of_bounds | :not_adjacent}
  def add_edge_feature(%__MODULE__{} = map, %Coord{} = from, %Coord{} = to, feature) do
    direction = Coord.direction_to(from, to)

    if is_nil(direction) do
      {:error, :not_adjacent}
    else
      opposite = rem(direction + 3, 6)

      with {:ok, map} <- update_tile(map, from, &Tile.add_edge_feature(&1, direction, feature)),
           {:ok, map} <- update_tile(map, to, &Tile.add_edge_feature(&1, opposite, feature)) do
        {:ok, map}
      end
    end
  end

  @doc """
  Paints terrain in a rectangular region.
  """
  @spec fill_terrain(t(), Coord.t(), Coord.t(), atom()) :: t()
  def fill_terrain(%__MODULE__{} = map, %Coord{q: q1, r: r1}, %Coord{q: q2, r: r2}, terrain) do
    min_q = min(q1, q2)
    max_q = max(q1, q2)
    min_r = min(r1, r2)
    max_r = max(r1, r2)

    Enum.reduce(min_q..max_q, map, fn q, acc_map ->
      Enum.reduce(min_r..max_r, acc_map, fn r, acc_map2 ->
        coord = Coord.new(q, r)

        case set_terrain(acc_map2, coord, terrain) do
          {:ok, updated_map} -> updated_map
          {:error, _} -> acc_map2
        end
      end)
    end)
  end

  @doc """
  Returns map dimensions as {width, height}.
  """
  @spec dimensions(t()) :: {pos_integer(), pos_integer()}
  def dimensions(%__MODULE__{width: width, height: height}) do
    {width, height}
  end

  @doc """
  Returns the real-world size of the map in meters.
  """
  @spec real_world_size(t()) :: {number(), number()}
  def real_world_size(%__MODULE__{width: width, height: height, scale: scale}) do
    # For pointy-top hexes:
    # Horizontal spacing = sqrt(3) * size
    # Vertical spacing = 1.5 * size
    # Width needs to account for the offset rows
    hex_width = :math.sqrt(3) * scale
    hex_height = 2 * scale

    map_width = width * hex_width + hex_width / 2
    map_height = height * hex_height * 0.75 + hex_height * 0.25

    {map_width, map_height}
  end
end
