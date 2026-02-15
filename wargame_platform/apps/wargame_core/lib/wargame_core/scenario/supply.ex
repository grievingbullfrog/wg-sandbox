defmodule WargameCore.Scenario.Supply do
  @moduledoc """
  Supply system inspired by Unity of Command.

  Supply traces a path from supply sources to units via BFS.
  Paths cannot cross enemy ZOC or impassable terrain.
  Units out of supply suffer attrition (strength loss, morale degradation).

  ## Supply Sources

  Each side has supply sources defined as hexes (usually on map edges):

      [%{side: :axis, hex: {0, 5}}, %{side: :axis, hex: {0, 6}}]

  ## Zone of Control (ZOC)

  Enemy units project a zone of control into adjacent hexes.
  Supply lines cannot pass through enemy-controlled hexes.
  """

  alias WargameCore.Hex.Coord

  @attrition_strength_loss 1
  @attrition_morale_loss 5

  @type supply_source :: %{side: atom(), hex: Coord.t() | {integer(), integer()}}
  @type supply_status :: :supplied | :unsupplied

  @doc """
  Calculates supply status for all units of a given side.

  Uses BFS from supply sources, blocked by enemy ZOC and impassable terrain.
  Returns a map of `%{unit_id => :supplied | :unsupplied}`.

  ## Parameters
  - tiles: map of `%{Coord.t() => Tile.t()}` or similar
  - units: map of `%{unit_id => unit}` where unit has `:position` and `:side`
  - supply_sources: list of `%{side: atom(), hex: Coord.t() | {q, r}}`
  - side: which side to calculate supply for
  """
  @spec calculate_supply_status(map(), map(), [supply_source()], atom()) :: %{String.t() => supply_status()}
  def calculate_supply_status(tiles, units, supply_sources, side) do
    # Get source hexes for this side
    source_coords = sources_for_side(supply_sources, side)

    # Build enemy ZOC set (hexes adjacent to enemy units)
    enemy_zoc = build_enemy_zoc(units, side)

    # Build set of impassable hexes
    impassable = build_impassable_set(tiles)

    # BFS from supply sources, blocked by enemy ZOC and impassable
    supplied_hexes = bfs_supply(source_coords, tiles, enemy_zoc, impassable)

    # Check each unit of this side
    units
    |> Enum.filter(fn {_id, unit} -> unit.side == side end)
    |> Enum.into(%{}, fn {id, unit} ->
      coord = normalize_coord(unit.position)
      status = if coord && MapSet.member?(supplied_hexes, coord), do: :supplied, else: :unsupplied
      {id, status}
    end)
  end

  @doc """
  Applies attrition to unsupplied units.

  Returns an updated units map with strength/morale reduced for unsupplied units.
  Units must have :current_strength and :morale fields.
  """
  @spec apply_attrition(map(), %{String.t() => supply_status()}) :: map()
  def apply_attrition(units, supply_statuses) do
    Enum.into(units, %{}, fn {id, unit} ->
      case Map.get(supply_statuses, id) do
        :unsupplied ->
          updated = unit
            |> reduce_strength(@attrition_strength_loss)
            |> reduce_morale(@attrition_morale_loss)
          {id, updated}
        _ ->
          {id, unit}
      end
    end)
  end

  @doc """
  Checks if a specific unit is in supply.
  """
  @spec in_supply?(map(), String.t()) :: boolean()
  def in_supply?(supply_statuses, unit_id) do
    Map.get(supply_statuses, unit_id) == :supplied
  end

  # --- Private helpers ---

  defp sources_for_side(supply_sources, side) do
    supply_sources
    |> Enum.filter(fn source -> source.side == side end)
    |> Enum.map(fn source -> normalize_coord(source.hex) end)
    |> Enum.reject(&is_nil/1)
    |> MapSet.new()
  end

  defp build_enemy_zoc(units, friendly_side) do
    units
    |> Enum.reject(fn {_id, unit} -> unit.side == friendly_side end)
    |> Enum.flat_map(fn {_id, unit} ->
      coord = normalize_coord(unit.position)
      if coord do
        [coord | Coord.neighbors(coord)]
      else
        []
      end
    end)
    |> MapSet.new()
  end

  defp build_impassable_set(tiles) do
    tiles
    |> Enum.filter(fn {_coord, tile} ->
      terrain = tile.terrain
      terrain in [:ocean, :freshwater_lake]
    end)
    |> Enum.map(fn {coord, _tile} -> normalize_coord(coord) end)
    |> MapSet.new()
  end

  defp bfs_supply(source_coords, tiles, enemy_zoc, impassable) do
    # BFS from all source hexes simultaneously
    # Only visit hexes that exist on the map, are not impassable, and are not in enemy ZOC
    map_hexes = tiles |> Map.keys() |> Enum.map(&normalize_coord/1) |> MapSet.new()

    # Sources themselves are always supplied (even if in ZOC)
    initial_queue = :queue.from_list(MapSet.to_list(source_coords))
    visited = source_coords

    bfs_loop(initial_queue, visited, map_hexes, enemy_zoc, impassable)
  end

  defp bfs_loop(queue, visited, map_hexes, enemy_zoc, impassable) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, coord}, rest_queue} ->
        neighbors = Coord.neighbors(coord)

        {new_queue, new_visited} =
          Enum.reduce(neighbors, {rest_queue, visited}, fn neighbor, {q, v} ->
            if MapSet.member?(map_hexes, neighbor) &&
               !MapSet.member?(v, neighbor) &&
               !MapSet.member?(impassable, neighbor) &&
               !MapSet.member?(enemy_zoc, neighbor) do
              {:queue.in(neighbor, q), MapSet.put(v, neighbor)}
            else
              {q, v}
            end
          end)

        bfs_loop(new_queue, new_visited, map_hexes, enemy_zoc, impassable)
    end
  end

  defp normalize_coord(%Coord{} = coord), do: coord
  defp normalize_coord({q, r}), do: Coord.new(q, r)
  defp normalize_coord(nil), do: nil

  defp reduce_strength(unit, loss) do
    new_strength = max((Map.get(unit, :current_strength) || 0) - loss, 0)
    Map.put(unit, :current_strength, new_strength)
  end

  defp reduce_morale(unit, loss) do
    new_morale = max((Map.get(unit, :morale) || 0) - loss, 0)
    Map.put(unit, :morale, new_morale)
  end
end
