defmodule WargameWebWeb.MapDemoLive do
  @moduledoc """
  Demo LiveView for testing the hex map renderer.

  This creates a sample map with various terrain types
  to test rendering, pan, zoom, and selection.
  """

  use WargameWebWeb, :live_view

  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Map.Tile

  @map_width 20
  @map_height 15

  @impl true
  def mount(_params, _session, socket) do
    # Create a demo map
    map = create_demo_map()

    socket =
      socket
      |> assign(:map, map)
      |> assign(:selected_hex, nil)
      |> assign(:hovered_hex, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900">
      <header class="bg-gray-800 text-white p-4 flex justify-between items-center">
        <h1 class="text-xl font-bold">Wargame Map Demo</h1>
        <div class="flex gap-4 text-sm">
          <span :if={@hovered_hex}>
            Hover: ({@hovered_hex.q}, {@hovered_hex.r})
          </span>
          <span :if={@selected_hex} class="text-yellow-400">
            Selected: ({@selected_hex.q}, {@selected_hex.r})
            <%= if tile = get_tile(@map, @selected_hex) do %>
              - <%= tile.terrain %>
              <%= if tile.elevation > 0, do: "(elev: #{tile.elevation})" %>
            <% end %>
          </span>
        </div>
      </header>

      <main class="flex-1 relative">
        <canvas
          id="map-canvas"
          phx-hook="MapHook"
          phx-update="ignore"
          class="w-full h-full"
          data-width={@map.width}
          data-height={@map.height}
          data-hex-size="40"
          data-show-grid="true"
          data-show-coords="false"
          data-show-elevation="true"
        />
      </main>

      <footer class="bg-gray-800 text-white p-2 text-sm text-center">
        <span class="text-gray-400">
          Mouse: Pan (drag) | Zoom (scroll) | Select (click)
        </span>
      </footer>
    </div>
    """
  end

  @impl true
  def handle_event("map_ready", _params, socket) do
    # Send map data to the renderer
    tiles = map_to_tiles(socket.assigns.map)
    {:noreply, push_event(socket, "render_map", %{tiles: tiles})}
  end

  @impl true
  def handle_event("hex_selected", %{"q" => q, "r" => r}, socket) do
    coord = %{q: q, r: r}
    {:noreply, assign(socket, :selected_hex, coord)}
  end

  @impl true
  def handle_event("hex_hovered", %{"q" => q, "r" => r}, socket) do
    coord = %{q: q, r: r}
    {:noreply, assign(socket, :hovered_hex, coord)}
  end

  defp get_tile(map, %{q: q, r: r}) do
    coord = Coord.new(q, r)
    GameMap.get_tile(map, coord)
  end

  defp create_demo_map do
    # Create base map
    map = GameMap.new("Demo Map", @map_width, @map_height, 200, description: "Test map for renderer")

    # Add some varied terrain
    map
    |> add_terrain_patches()
    |> add_roads()
    |> add_rivers()
    |> add_special_features()
  end

  defp add_terrain_patches(map) do
    # Add some forest patches
    map = add_terrain_area(map, 3, 3, 5, 5, :woods)
    map = add_terrain_area(map, 12, 8, 15, 11, :forest)

    # Add hills
    map = add_terrain_area(map, 8, 2, 11, 4, :hills)

    # Add a village
    map = set_terrain(map, 10, 7, :village)
    map = set_terrain(map, 11, 7, :village)

    # Add some marsh near the edge
    map = add_terrain_area(map, 1, 10, 3, 13, :marsh)

    # Add water
    map = set_terrain(map, 15, 5, :lake)
    map = set_terrain(map, 16, 5, :lake)
    map = set_terrain(map, 15, 6, :lake)

    map
  end

  defp add_roads(map) do
    # Add a road from left to right through the middle
    road_coords = [
      {0, 7}, {1, 7}, {2, 7}, {3, 7}, {4, 7}, {5, 7},
      {6, 7}, {7, 7}, {8, 7}, {9, 7}, {10, 7}, {11, 7},
      {12, 7}, {13, 7}, {14, 7}, {15, 7}, {16, 7}, {17, 7},
      {18, 7}, {19, 7}
    ]

    Enum.reduce(road_coords, map, fn {q, r}, acc_map ->
      coord = Coord.new(q, r)

      # Add road edges in the east-west direction
      case GameMap.update_tile(acc_map, coord, fn tile ->
        tile
        |> Tile.add_edge_feature(0, :road)  # East
        |> Tile.add_edge_feature(3, :road)  # West
      end) do
        {:ok, updated} -> updated
        {:error, _} -> acc_map
      end
    end)
  end

  defp add_rivers(map) do
    # Add a river running north-south
    river_coords = [
      {7, 0}, {7, 1}, {7, 2}, {8, 3}, {8, 4}, {8, 5},
      {7, 6}, {7, 7}, {7, 8}, {7, 9}, {7, 10}, {8, 11},
      {8, 12}, {8, 13}, {8, 14}
    ]

    Enum.reduce(river_coords, map, fn {q, r}, acc_map ->
      coord = Coord.new(q, r)

      case GameMap.update_tile(acc_map, coord, fn tile ->
        # Add river on the appropriate edges
        tile
        |> Tile.add_edge_feature(2, :river)  # Northwest edge
        |> Tile.add_edge_feature(5, :river)  # Southeast edge
      end) do
        {:ok, updated} -> updated
        {:error, _} -> acc_map
      end
    end)
  end

  defp add_special_features(map) do
    # Add some victory point hexes
    {:ok, map} = GameMap.update_tile(map, Coord.new(10, 7), fn tile ->
      %{tile | victory_points: 2, control: :german}
    end)

    {:ok, map} = GameMap.update_tile(map, Coord.new(5, 10), fn tile ->
      %{tile | victory_points: 1, control: :soviet}
    end)

    # Add some fortifications
    {:ok, map} = GameMap.update_tile(map, Coord.new(15, 3), fn tile ->
      tile
      |> Tile.add_overlay(:fortification)
      |> Tile.add_overlay(:trench)
    end)

    # Add a minefield
    {:ok, map} = GameMap.update_tile(map, Coord.new(13, 5), fn tile ->
      Tile.add_overlay(tile, :minefield)
    end)

    # Add some elevation
    map = add_elevation_area(map, 8, 2, 11, 4, 2)
    map = add_elevation_area(map, 9, 3, 10, 3, 3)

    map
  end

  defp add_terrain_area(map, q1, r1, q2, r2, terrain) do
    Enum.reduce(q1..q2, map, fn q, acc1 ->
      Enum.reduce(r1..r2, acc1, fn r, acc2 ->
        set_terrain(acc2, q, r, terrain)
      end)
    end)
  end

  defp add_elevation_area(map, q1, r1, q2, r2, elevation) do
    Enum.reduce(q1..q2, map, fn q, acc1 ->
      Enum.reduce(r1..r2, acc1, fn r, acc2 ->
        coord = Coord.new(q, r)
        case GameMap.set_elevation(acc2, coord, elevation) do
          {:ok, updated} -> updated
          {:error, _} -> acc2
        end
      end)
    end)
  end

  defp set_terrain(map, q, r, terrain) do
    coord = Coord.new(q, r)
    case GameMap.set_terrain(map, coord, terrain) do
      {:ok, updated} -> updated
      {:error, _} -> map
    end
  end

  defp map_to_tiles(map) do
    map
    |> GameMap.all_tiles()
    |> Enum.map(&tile_to_json/1)
  end

  defp tile_to_json(%Tile{} = tile) do
    %{
      coord: %{q: tile.coord.q, r: tile.coord.r},
      terrain: Atom.to_string(tile.terrain),
      elevation: tile.elevation,
      edges: edges_to_json(tile.edges),
      overlays: Enum.map(tile.overlays, &Atom.to_string/1),
      control: if(tile.control, do: Atom.to_string(tile.control), else: nil),
      victoryPoints: tile.victory_points,
      name: tile.name
    }
  end

  defp edges_to_json(edges) do
    edges
    |> Enum.map(fn {dir, features} ->
      {Integer.to_string(dir), Enum.map(features, &Atom.to_string/1)}
    end)
    |> Enum.into(%{})
  end
end
