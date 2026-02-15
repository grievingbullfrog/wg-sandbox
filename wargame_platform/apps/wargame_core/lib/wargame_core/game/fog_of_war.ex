defmodule WargameCore.Game.FogOfWar do
  @moduledoc """
  Fog of war visibility calculations.

  Determines which hexes are visible to each side based on unit spotting ranges,
  line of sight, elevation, weather, and leader bonuses.

  ## Fog of War Modes

  - `:none` - All units and terrain visible (default)
  - `:partial` - Terrain always visible, enemy units hidden unless spotted
  - `:full` - Unspotted hexes are completely hidden
  """

  alias WargameCore.Hex.{Coord, Grid}
  alias WargameCore.Map, as: GameMap

  @weather_visibility_modifiers %{
    clear: 0,
    overcast: -1,
    rain: -2,
    snow: -2,
    blizzard: -3,
    rasputitsa: -1
  }

  @doc """
  Calculates the set of visible hex coordinates for a given side.

  Returns a `MapSet` of `Coord.t()` representing all hexes the side can see.
  """
  @spec calculate_visibility(map(), atom()) :: MapSet.t()
  def calculate_visibility(game_state, side) do
    map = game_state.map
    weather = get_weather(game_state)
    weather_mod = Map.get(@weather_visibility_modifiers, weather, 0)

    friendly_units =
      game_state.units
      |> Map.values()
      |> Enum.filter(&(&1.side == side and &1.position != nil))

    leaders = Map.get(game_state, :leaders, %{}) |> Map.values()

    friendly_units
    |> Enum.reduce(MapSet.new(), fn unit, visible ->
      spotting = unit.template.spotting + weather_mod
      leader_bonus = leader_spotting_bonus(unit, leaders, side)
      elevation_bonus = elevation_spotting_bonus(map, unit.position)
      effective_range = max(spotting + leader_bonus + elevation_bonus, 1)

      unit_visible = visible_from(map, unit.position, effective_range)
      MapSet.union(visible, unit_visible)
    end)
  end

  @doc """
  Filters game state to remove information not visible to a given side.

  In `:partial` mode, hides enemy unit positions outside visible hexes.
  In `:full` mode, also hides tile details for non-visible hexes.
  In `:none` mode, returns state unchanged.
  """
  @spec filter_state_for_side(map(), atom()) :: map()
  def filter_state_for_side(game_state, side) do
    fog_mode = get_fog_mode(game_state)

    case fog_mode do
      :none ->
        game_state

      mode when mode in [:partial, :full] ->
        visible = calculate_visibility(game_state, side)

        filtered_units = filter_units(game_state.units, side, visible)
        filtered_leaders = filter_leaders(game_state, side, visible)

        state = %{game_state | units: filtered_units}
        state = Map.put(state, :leaders, filtered_leaders)
        state = Map.put(state, :visible_hexes, visible)

        if mode == :full do
          filter_tiles(state, visible)
        else
          state
        end
    end
  end

  # --- Visibility Calculation ---

  defp visible_from(map, position, range) do
    # Get all hexes within spotting range
    coords_in_range = Grid.hexes_in_range(position, range)

    Enum.reduce(coords_in_range, MapSet.new(), fn coord, visible ->
      if GameMap.get_tile(map, coord) != nil and
         GameMap.has_line_of_sight?(map, position, coord) do
        MapSet.put(visible, coord)
      else
        visible
      end
    end)
    |> MapSet.put(position)  # Always see your own hex
  end

  # --- Leader Bonus ---

  defp leader_spotting_bonus(unit, leaders, side) do
    leaders
    |> Enum.filter(fn leader ->
      leader.side == side and leader.position != nil and
        Coord.distance(unit.position, leader.position) <= leader.command_radius
    end)
    |> Enum.reduce(0, fn leader, bonus ->
      leader_bonus = if :recon_bonus in leader.abilities, do: 2, else: 1
      max(bonus, leader_bonus)
    end)
  end

  # --- Elevation Bonus ---

  defp elevation_spotting_bonus(map, position) do
    tile = GameMap.get_tile(map, position)

    cond do
      is_nil(tile) -> 0
      tile.elevation >= 200 -> 2
      tile.elevation >= 100 -> 1
      true -> 0
    end
  end

  # --- Filtering ---

  defp filter_units(units, side, visible) do
    Map.new(units, fn {id, unit} ->
      if unit.side == side or (unit.position != nil and MapSet.member?(visible, unit.position)) do
        {id, unit}
      else
        # Hide unit by removing position info
        {id, %{unit | position: nil}}
      end
    end)
    |> Enum.reject(fn {_id, unit} -> unit.side != side and unit.position == nil end)
    |> Map.new()
  end

  defp filter_leaders(game_state, side, visible) do
    leaders = Map.get(game_state, :leaders, %{})

    leaders
    |> Enum.filter(fn {_id, leader} ->
      leader.side == side or
        (leader.position != nil and MapSet.member?(visible, leader.position))
    end)
    |> Map.new()
  end

  defp filter_tiles(state, visible) do
    filtered_tiles =
      state.map.tiles
      |> Map.new(fn {coord, tile} ->
        if MapSet.member?(visible, coord) do
          {coord, tile}
        else
          # Hide tile details: keep coord and basic terrain but strip control/units info
          {coord, %{tile | control: nil, victory_points: 0}}
        end
      end)

    map = %{state.map | tiles: filtered_tiles}
    %{state | map: map}
  end

  # --- Helpers ---

  defp get_weather(game_state) do
    case Map.get(game_state, :weather) do
      %{weather: w} -> w
      _ -> :clear
    end
  end

  defp get_fog_mode(game_state) do
    case get_in(game_state, [:settings, :fog_of_war]) do
      mode when mode in [:none, :partial, :full] -> mode
      _ -> :none
    end
  end
end
