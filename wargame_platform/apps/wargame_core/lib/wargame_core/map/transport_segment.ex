defmodule WargameCore.Map.TransportSegment do
  @moduledoc """
  Represents a transport segment crossing a hex tile.

  Transport segments are paths (roads, trails, railroads, runways) that cross
  through a hex tile. Each segment has a type and defines which edges it
  enters/exits through.

  Entry/exit edges use the standard edge numbering:
  - 0: N (top)
  - 1: NE (top-right)
  - 2: SE (bottom-right)
  - 3: S (bottom)
  - 4: SW (bottom-left)
  - 5: NW (top-left)

  A single tile can have multiple transport segments (e.g., a road and railroad
  crossing the same hex). Dead-end segments have empty exit_edges.
  """

  @type segment_type ::
          :trail
          | :small_unpaved_road
          | :large_unpaved_road
          | :small_paved_road
          | :large_paved_road
          | :railroad
          | :double_track_railroad
          | :triple_track_railroad
          | :runway

  @type t :: %__MODULE__{
          type: segment_type(),
          entry_edges: [0..5],
          exit_edges: [0..5]
        }

  @enforce_keys [:type]
  defstruct type: nil,
            entry_edges: [],
            exit_edges: []

  @doc """
  Creates a new transport segment.

  ## Parameters
  - type: The type of transport segment
  - entry_edges: List of edges where the segment enters the tile (0-5)
  - exit_edges: List of edges where the segment exits the tile (0-5)

  ## Examples

      iex> TransportSegment.new(:small_paved_road, [0], [3])
      %TransportSegment{type: :small_paved_road, entry_edges: [0], exit_edges: [3]}

      iex> TransportSegment.new(:railroad, [1, 4], [])
      %TransportSegment{type: :railroad, entry_edges: [1, 4], exit_edges: []}
  """
  @spec new(segment_type(), [0..5], [0..5]) :: t()
  def new(type, entry_edges \\ [], exit_edges \\ []) do
    %__MODULE__{
      type: type,
      entry_edges: Enum.filter(entry_edges, &valid_edge?/1),
      exit_edges: Enum.filter(exit_edges, &valid_edge?/1)
    }
  end

  @doc """
  Returns all valid segment types.
  """
  @spec all_types() :: [segment_type()]
  def all_types do
    [
      :trail,
      :small_unpaved_road,
      :large_unpaved_road,
      :small_paved_road,
      :large_paved_road,
      :railroad,
      :double_track_railroad,
      :triple_track_railroad,
      :runway
    ]
  end

  @doc """
  Returns a human-readable name for a segment type.
  """
  @spec type_name(segment_type()) :: String.t()
  def type_name(:trail), do: "Trail"
  def type_name(:small_unpaved_road), do: "Small Unpaved Road"
  def type_name(:large_unpaved_road), do: "Large Unpaved Road"
  def type_name(:small_paved_road), do: "Small Paved Road"
  def type_name(:large_paved_road), do: "Large Paved Road"
  def type_name(:railroad), do: "Railroad"
  def type_name(:double_track_railroad), do: "Double Track Railroad"
  def type_name(:triple_track_railroad), do: "Triple Track Railroad"
  def type_name(:runway), do: "Runway"

  @doc """
  Returns all edges (entry and exit) for this segment.
  """
  @spec all_edges(t()) :: [0..5]
  def all_edges(%__MODULE__{entry_edges: entry, exit_edges: exit}) do
    Enum.uniq(entry ++ exit)
  end

  @doc """
  Checks if a segment connects to a specific edge.
  """
  @spec connects_to?(t(), 0..5) :: boolean()
  def connects_to?(%__MODULE__{} = segment, edge) when edge >= 0 and edge <= 5 do
    edge in segment.entry_edges or edge in segment.exit_edges
  end

  @doc """
  Checks if this is a dead-end segment (no exit edges).
  """
  @spec dead_end?(t()) :: boolean()
  def dead_end?(%__MODULE__{exit_edges: []}), do: true
  def dead_end?(_), do: false

  @doc """
  Checks if this is a through segment (has both entry and exit edges).
  """
  @spec through_segment?(t()) :: boolean()
  def through_segment?(%__MODULE__{entry_edges: entry, exit_edges: exit})
      when length(entry) > 0 and length(exit) > 0,
      do: true

  def through_segment?(_), do: false

  defp valid_edge?(edge) when is_integer(edge) and edge >= 0 and edge <= 5, do: true
  defp valid_edge?(_), do: false
end
