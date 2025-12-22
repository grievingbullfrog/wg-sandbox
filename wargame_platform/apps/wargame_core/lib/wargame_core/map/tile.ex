defmodule WargameCore.Map.Tile do
  @moduledoc """
  Represents a single hex tile on the map.

  Each tile has:
  - Coordinate position
  - Base terrain type
  - Elevation
  - Edge features (roads, rivers, etc. on hex edges)
  - Overlay features (minefields, fortifications placed on the hex)
  - Control (which side controls the hex)
  - Victory point value
  """

  alias WargameCore.Hex.Coord
  alias WargameCore.Terrain.TerrainType

  @type edge_feature :: :road | :railroad | :river | :stream | :bridge | :ford
  @type overlay :: :minefield | :fortification | :trench | :wire | :bunker

  @type t :: %__MODULE__{
          coord: Coord.t(),
          terrain: atom(),
          elevation: integer(),
          edges: %{(0..5) => [edge_feature()]},
          overlays: [overlay()],
          control: atom() | nil,
          victory_points: non_neg_integer(),
          name: String.t() | nil
        }

  @enforce_keys [:coord, :terrain]
  defstruct [
    :coord,
    :terrain,
    elevation: 0,
    edges: %{},
    overlays: [],
    control: nil,
    victory_points: 0,
    name: nil
  ]

  @doc """
  Creates a new tile with the given coordinate and terrain.

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(0, 0)
      iex> tile = WargameCore.Map.Tile.new(coord, :clear)
      iex> tile.terrain
      :clear
  """
  @spec new(Coord.t(), atom(), keyword()) :: t()
  def new(%Coord{} = coord, terrain, opts \\ []) when is_atom(terrain) do
    %__MODULE__{
      coord: coord,
      terrain: terrain,
      elevation: Keyword.get(opts, :elevation, 0),
      edges: Keyword.get(opts, :edges, %{}),
      overlays: Keyword.get(opts, :overlays, []),
      control: Keyword.get(opts, :control, nil),
      victory_points: Keyword.get(opts, :victory_points, 0),
      name: Keyword.get(opts, :name, nil)
    }
  end

  @doc """
  Returns the terrain type struct for this tile.
  """
  @spec terrain_type(t()) :: TerrainType.t() | nil
  def terrain_type(%__MODULE__{terrain: terrain_id}) do
    TerrainType.get(terrain_id)
  end

  @doc """
  Calculates the movement cost to enter this tile for a given unit category.
  Takes into account terrain, overlays, and edge crossings.

  ## Parameters
  - tile: The tile being entered
  - category: Unit category (infantry, armor, etc.)
  - from_direction: Direction entering from (0-5), optional for edge effects
  """
  @spec movement_cost(t(), TerrainType.unit_category(), 0..5 | nil) :: number() | :impassable
  def movement_cost(%__MODULE__{} = tile, category, from_direction \\ nil) do
    terrain = terrain_type(tile)
    base_cost = TerrainType.movement_cost(terrain, category)

    if base_cost == :impassable do
      :impassable
    else
      # Add overlay costs
      overlay_cost = calculate_overlay_cost(tile.overlays, category)

      if overlay_cost == :impassable do
        :impassable
      else
        # Add edge crossing cost if applicable
        edge_cost =
          if from_direction do
            calculate_edge_cost(tile.edges, from_direction, category)
          else
            0
          end

        if edge_cost == :impassable do
          :impassable
        else
          base_cost + overlay_cost + edge_cost
        end
      end
    end
  end

  defp calculate_overlay_cost(overlays, category) do
    Enum.reduce_while(overlays, 0, fn overlay, acc ->
      case overlay_movement_cost(overlay, category) do
        :impassable -> {:halt, :impassable}
        cost -> {:cont, acc + cost}
      end
    end)
  end

  defp overlay_movement_cost(:minefield, :engineer), do: 1
  defp overlay_movement_cost(:minefield, _), do: 2
  defp overlay_movement_cost(:fortification, :armor), do: :impassable
  defp overlay_movement_cost(:fortification, _), do: 0
  defp overlay_movement_cost(:trench, _), do: 0
  defp overlay_movement_cost(:wire, :infantry), do: 2
  defp overlay_movement_cost(:wire, :armor), do: 0
  defp overlay_movement_cost(:wire, _), do: 1
  defp overlay_movement_cost(:bunker, _), do: 0
  defp overlay_movement_cost(_, _), do: 0

  defp calculate_edge_cost(edges, direction, category) do
    edge_features = Map.get(edges, direction, [])

    # Check if a bridge or ford negates river impassability
    has_bridge = :bridge in edge_features
    has_ford = :ford in edge_features

    Enum.reduce_while(edge_features, 0, fn feature, acc ->
      case edge_feature_cost(feature, category) do
        :impassable when feature == :river and has_bridge ->
          # Bridge negates river impassability completely
          {:cont, acc}

        :impassable when feature == :river and has_ford ->
          # Ford makes river passable but adds cost
          {:cont, acc + edge_feature_cost(:ford, category)}

        :impassable ->
          {:halt, :impassable}

        cost ->
          {:cont, acc + cost}
      end
    end)
  end

  defp edge_feature_cost(:river, :engineer), do: 2
  defp edge_feature_cost(:river, _), do: :impassable
  defp edge_feature_cost(:stream, _), do: 1
  defp edge_feature_cost(:bridge, _), do: 0
  defp edge_feature_cost(:ford, :armor), do: 1
  defp edge_feature_cost(:ford, _), do: 0
  defp edge_feature_cost(:road, _), do: -0.5
  defp edge_feature_cost(:railroad, _), do: 0
  defp edge_feature_cost(_, _), do: 0

  @doc """
  Returns the defense modifier for this tile.
  Combines terrain and overlay modifiers.
  """
  @spec defense_modifier(t()) :: integer()
  def defense_modifier(%__MODULE__{} = tile) do
    terrain = terrain_type(tile)
    base_defense = terrain.defense_modifier

    overlay_defense =
      Enum.reduce(tile.overlays, 0, fn overlay, acc ->
        acc + overlay_defense_modifier(overlay)
      end)

    base_defense + overlay_defense
  end

  defp overlay_defense_modifier(:fortification), do: 3
  defp overlay_defense_modifier(:trench), do: 2
  defp overlay_defense_modifier(:bunker), do: 4
  defp overlay_defense_modifier(:wire), do: 0
  defp overlay_defense_modifier(:minefield), do: 0
  defp overlay_defense_modifier(_), do: 0

  @doc """
  Checks if this tile blocks line of sight.
  """
  @spec blocks_los?(t()) :: boolean()
  def blocks_los?(%__MODULE__{} = tile) do
    terrain = terrain_type(tile)
    terrain.blocks_los
  end

  @doc """
  Checks if this tile provides concealment.
  """
  @spec concealment?(t()) :: boolean()
  def concealment?(%__MODULE__{} = tile) do
    terrain = terrain_type(tile)
    terrain.concealment or :trench in tile.overlays
  end

  @doc """
  Adds an overlay to the tile.
  """
  @spec add_overlay(t(), overlay()) :: t()
  def add_overlay(%__MODULE__{overlays: overlays} = tile, overlay) do
    if overlay in overlays do
      tile
    else
      %{tile | overlays: [overlay | overlays]}
    end
  end

  @doc """
  Removes an overlay from the tile.
  """
  @spec remove_overlay(t(), overlay()) :: t()
  def remove_overlay(%__MODULE__{overlays: overlays} = tile, overlay) do
    %{tile | overlays: List.delete(overlays, overlay)}
  end

  @doc """
  Sets the control of the tile to a side.
  """
  @spec set_control(t(), atom() | nil) :: t()
  def set_control(%__MODULE__{} = tile, side) do
    %{tile | control: side}
  end

  @doc """
  Adds an edge feature to a specific edge.
  """
  @spec add_edge_feature(t(), 0..5, edge_feature()) :: t()
  def add_edge_feature(%__MODULE__{edges: edges} = tile, direction, feature)
      when direction in 0..5 do
    current = Map.get(edges, direction, [])

    if feature in current do
      tile
    else
      %{tile | edges: Map.put(edges, direction, [feature | current])}
    end
  end

  @doc """
  Checks if the tile has a specific edge feature on a direction.
  """
  @spec has_edge_feature?(t(), 0..5, edge_feature()) :: boolean()
  def has_edge_feature?(%__MODULE__{edges: edges}, direction, feature) when direction in 0..5 do
    feature in Map.get(edges, direction, [])
  end
end
