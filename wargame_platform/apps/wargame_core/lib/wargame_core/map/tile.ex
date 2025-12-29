defmodule WargameCore.Map.Tile do
  @moduledoc """
  Represents a single hex tile on the map.

  Each tile has:
  - Coordinate position
  - Base terrain type
  - Elevation
  - Edge features (water crossings: streams and rivers on hex edges)
  - Overlay features (minefields, fortifications placed on the hex)
  - Transport segments (roads, trails, railroads crossing through the tile)
  - Control (which side controls the hex)
  - Victory point value
  - Objective information (name and owning force for victory conditions)
  """

  alias WargameCore.Hex.Coord
  alias WargameCore.Map.TransportSegment
  alias WargameCore.Terrain.TerrainType

  @type edge_feature :: :small_stream | :large_stream | :small_river | :large_river
  @type overlay :: :minefield | :fortification | :trench | :wire | :bunker
  @type objective :: %{name: String.t() | nil, force: atom() | nil}

  @type t :: %__MODULE__{
          coord: Coord.t(),
          terrain: atom(),
          elevation: integer(),
          edges: %{(0..5) => [edge_feature()]},
          overlays: [overlay()],
          transport_segments: [TransportSegment.t()],
          control: atom() | nil,
          victory_points: non_neg_integer(),
          name: String.t() | nil,
          objective: objective() | nil
        }

  @enforce_keys [:coord, :terrain]
  defstruct [
    :coord,
    :terrain,
    elevation: 0,
    edges: %{},
    overlays: [],
    transport_segments: [],
    control: nil,
    victory_points: 0,
    name: nil,
    objective: nil
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
      transport_segments: Keyword.get(opts, :transport_segments, []),
      control: Keyword.get(opts, :control, nil),
      victory_points: Keyword.get(opts, :victory_points, 0),
      name: Keyword.get(opts, :name, nil),
      objective: Keyword.get(opts, :objective, nil)
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

    Enum.reduce_while(edge_features, 0, fn feature, acc ->
      case edge_feature_cost(feature, category) do
        :impassable ->
          {:halt, :impassable}

        cost ->
          {:cont, acc + cost}
      end
    end)
  end

  defp edge_feature_cost(:small_stream, _), do: 0.5
  defp edge_feature_cost(:large_stream, _), do: 1
  defp edge_feature_cost(:small_river, :engineer), do: 1
  defp edge_feature_cost(:small_river, _), do: 2
  defp edge_feature_cost(:large_river, :engineer), do: 2
  defp edge_feature_cost(:large_river, _), do: :impassable
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
  Clears all edge features from a specific edge direction.
  """
  @spec clear_edge(t(), 0..5) :: t()
  def clear_edge(%__MODULE__{edges: edges} = tile, direction) when direction in 0..5 do
    %{tile | edges: Map.delete(edges, direction)}
  end

  @doc """
  Checks if the tile has a specific edge feature on a direction.
  """
  @spec has_edge_feature?(t(), 0..5, edge_feature()) :: boolean()
  def has_edge_feature?(%__MODULE__{edges: edges}, direction, feature) when direction in 0..5 do
    feature in Map.get(edges, direction, [])
  end

  @doc """
  Adds a transport segment to the tile.
  """
  @spec add_transport_segment(t(), TransportSegment.t()) :: t()
  def add_transport_segment(%__MODULE__{transport_segments: segments} = tile, %TransportSegment{} = segment) do
    %{tile | transport_segments: [segment | segments]}
  end

  @doc """
  Removes a transport segment from the tile by matching type and edges.
  """
  @spec remove_transport_segment(t(), TransportSegment.t()) :: t()
  def remove_transport_segment(%__MODULE__{transport_segments: segments} = tile, %TransportSegment{} = segment) do
    updated =
      Enum.reject(segments, fn s ->
        s.type == segment.type and
          s.entry_edges == segment.entry_edges and
          s.exit_edges == segment.exit_edges
      end)

    %{tile | transport_segments: updated}
  end

  @doc """
  Clears all transport segments from the tile.
  """
  @spec clear_transport_segments(t()) :: t()
  def clear_transport_segments(%__MODULE__{} = tile) do
    %{tile | transport_segments: []}
  end

  @doc """
  Gets all transport segments of a specific type on this tile.
  """
  @spec get_segments_by_type(t(), TransportSegment.segment_type()) :: [TransportSegment.t()]
  def get_segments_by_type(%__MODULE__{transport_segments: segments}, type) do
    Enum.filter(segments, fn s -> s.type == type end)
  end

  @doc """
  Checks if the tile has any transport segments.
  """
  @spec has_transport_segments?(t()) :: boolean()
  def has_transport_segments?(%__MODULE__{transport_segments: []}), do: false
  def has_transport_segments?(%__MODULE__{}), do: true

  @doc """
  Checks if the tile has a transport segment connecting to a specific edge.
  """
  @spec has_transport_at_edge?(t(), 0..5) :: boolean()
  def has_transport_at_edge?(%__MODULE__{transport_segments: segments}, edge) when edge >= 0 and edge <= 5 do
    Enum.any?(segments, fn s -> TransportSegment.connects_to?(s, edge) end)
  end

  @doc """
  Sets an objective on the tile.

  ## Parameters
  - tile: The tile to set the objective on
  - name: The objective name (e.g., "Hill 223")
  - force: The force that owns the objective (e.g., :allied, :axis)

  ## Examples

      iex> coord = WargameCore.Hex.Coord.new(5, 5)
      iex> tile = WargameCore.Map.Tile.new(coord, :clear)
      iex> tile = WargameCore.Map.Tile.set_objective(tile, "Hill 223", :allied)
      iex> tile.objective
      %{name: "Hill 223", force: :allied}
  """
  @spec set_objective(t(), String.t() | nil, atom() | nil) :: t()
  def set_objective(%__MODULE__{} = tile, name, force) do
    %{tile | objective: %{name: name, force: force}}
  end

  @doc """
  Clears the objective from a tile.
  """
  @spec clear_objective(t()) :: t()
  def clear_objective(%__MODULE__{} = tile) do
    %{tile | objective: nil}
  end

  @doc """
  Checks if the tile has an objective.
  """
  @spec has_objective?(t()) :: boolean()
  def has_objective?(%__MODULE__{objective: nil}), do: false
  def has_objective?(%__MODULE__{objective: _}), do: true

  @doc """
  Sets the victory points for this tile.
  """
  @spec set_victory_points(t(), non_neg_integer()) :: t()
  def set_victory_points(%__MODULE__{} = tile, points) when is_integer(points) and points >= 0 do
    %{tile | victory_points: points}
  end
end
