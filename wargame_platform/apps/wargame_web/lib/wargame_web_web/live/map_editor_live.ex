defmodule WargameWebWeb.MapEditorLive do
  @moduledoc """
  LiveView-based hex map editor.

  Features:
  - Terrain painting with brush, fill, and line tools
  - Elevation editing
  - Edge features (roads, rivers, railroads)
  - Map save/load to YAML format
  - Map resize and scale configuration
  """

  use WargameWebWeb, :live_view

  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Map.Tile
  alias WargameCore.Terrain.TerrainType

  @default_width 20
  @default_height 15
  @default_scale 200

  @impl true
  def mount(_params, _session, socket) do
    terrain_types = TerrainType.all() |> Enum.map(& &1.id)
    edge_features = [:road, :railroad, :river, :stream, :bridge, :ford]
    overlay_types = [:minefield, :fortification, :trench, :wire, :bunker]

    socket =
      socket
      |> assign(:map, create_empty_map(@default_width, @default_height, @default_scale))
      |> assign(:map_name, "New Map")
      |> assign(:selected_hex, nil)
      |> assign(:hovered_hex, nil)
      |> assign(:tool, :brush)
      |> assign(:selected_terrain, :clear)
      |> assign(:selected_elevation, 0)
      |> assign(:selected_edge_feature, :road)
      |> assign(:selected_edge_direction, 0)
      |> assign(:selected_overlay, :trench)
      |> assign(:brush_size, 1)
      |> assign(:terrain_types, terrain_types)
      |> assign(:edge_features, edge_features)
      |> assign(:overlay_types, overlay_types)
      |> assign(:show_grid, true)
      |> assign(:show_coords, false)
      |> assign(:tile_overlay, :none)
      |> assign(:undo_stack, [])
      |> assign(:redo_stack, [])
      |> assign(:line_start, nil)
      |> assign(:save_status, nil)
      |> assign(:modal, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900">
      <!-- Header -->
      <header class="bg-gray-800 text-white p-3 flex justify-between items-center border-b border-gray-700">
        <div class="flex items-center gap-4">
          <h1 class="text-xl font-bold">Map Editor</h1>
          <input
            type="text"
            value={@map_name}
            phx-blur="update_map_name"
            phx-keydown="update_map_name"
            phx-key="Enter"
            class="bg-gray-700 text-white px-2 py-1 rounded text-sm w-48"
            placeholder="Map name"
          />
        </div>
        <div class="flex gap-2">
          <button
            phx-click="new_map"
            class="bg-gray-600 hover:bg-gray-500 px-3 py-1 rounded text-sm"
          >
            New
          </button>
          <button
            phx-click="show_resize_modal"
            class="bg-gray-600 hover:bg-gray-500 px-3 py-1 rounded text-sm"
          >
            Resize
          </button>
          <button
            phx-click="load_map"
            class="bg-blue-600 hover:bg-blue-500 px-3 py-1 rounded text-sm"
          >
            Load
          </button>
          <button
            phx-click="save_map"
            class="bg-green-600 hover:bg-green-500 px-3 py-1 rounded text-sm"
          >
            Save
          </button>
          <span :if={@save_status} class="text-green-400 text-sm self-center ml-2">
            {@save_status}
          </span>
        </div>
      </header>

      <div class="flex flex-1 overflow-hidden">
        <!-- Left Toolbar -->
        <aside class="w-56 bg-gray-800 text-white p-3 overflow-y-auto border-r border-gray-700">
          <!-- Tools -->
          <div class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Tools</h3>
            <div class="grid grid-cols-4 gap-1">
              <button
                :for={tool <- [:brush, :fill, :line, :elevation, :edge, :overlay, :eraser]}
                phx-click="select_tool"
                phx-value-tool={tool}
                class={"px-2 py-2 rounded text-xs font-medium #{if @tool == tool, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {tool_label(tool)}
              </button>
            </div>
          </div>

          <!-- Brush Size -->
          <div :if={@tool in [:brush, :eraser]} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Brush Size</h3>
            <div class="flex gap-2">
              <button
                :for={size <- [1, 2, 3]}
                phx-click="set_brush_size"
                phx-value-size={size}
                class={"px-3 py-1 rounded text-sm #{if @brush_size == size, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {size}
              </button>
            </div>
          </div>

          <!-- Terrain Selection -->
          <div :if={@tool in [:brush, :fill, :line]} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Terrain</h3>
            <div class="grid grid-cols-3 gap-1">
              <button
                :for={terrain <- @terrain_types}
                phx-click="select_terrain"
                phx-value-terrain={terrain}
                class={"px-1 py-1 rounded text-[10px] leading-tight #{if @selected_terrain == terrain, do: "ring-2 ring-blue-400", else: ""}"
                  <> " " <> terrain_button_class(terrain)}
              >
                {terrain_label(terrain)}
              </button>
            </div>
          </div>

          <!-- Elevation Selection -->
          <div :if={@tool == :elevation} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Elevation Level</h3>
            <div class="flex items-center gap-2">
              <button
                phx-click="decrement_elevation"
                class="px-2 py-1 rounded text-sm bg-gray-600 hover:bg-gray-500"
              >
                −
              </button>
              <input
                type="number"
                value={@selected_elevation}
                phx-blur="select_elevation"
                phx-keydown="select_elevation"
                phx-key="Enter"
                class="w-16 bg-gray-700 text-white px-2 py-1 rounded text-sm text-center"
              />
              <button
                phx-click="increment_elevation"
                class="px-2 py-1 rounded text-sm bg-gray-600 hover:bg-gray-500"
              >
                +
              </button>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              Relative to base ({@map.base_elevation}m)
            </p>
          </div>

          <!-- Edge Feature Selection -->
          <div :if={@tool == :edge} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Edge Feature</h3>
            <div class="flex flex-wrap gap-1 mb-2">
              <button
                :for={feature <- @edge_features}
                phx-click="select_edge_feature"
                phx-value-feature={feature}
                class={"px-2 py-1 rounded text-xs #{if @selected_edge_feature == feature, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {feature_label(feature)}
              </button>
            </div>
            <h4 class="text-xs font-semibold text-gray-400 mb-1">Direction</h4>
            <div class="flex flex-wrap gap-1">
              <button
                :for={dir <- 0..5}
                phx-click="select_edge_direction"
                phx-value-direction={dir}
                class={"px-3 py-1 rounded text-sm #{if @selected_edge_direction == dir, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {direction_label(dir)}
              </button>
            </div>
          </div>

          <!-- Overlay Selection -->
          <div :if={@tool == :overlay} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Overlay</h3>
            <div class="flex flex-wrap gap-1">
              <button
                :for={overlay <- @overlay_types}
                phx-click="select_overlay"
                phx-value-overlay={overlay}
                class={"px-2 py-1 rounded text-xs #{if @selected_overlay == overlay, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {overlay_label(overlay)}
              </button>
            </div>
          </div>

          <!-- View Options -->
          <div class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">View Options</h3>
            <div class="space-y-1">
              <label class="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={@show_grid}
                  phx-click="toggle_grid"
                  class="rounded"
                />
                Show Grid
              </label>
              <label class="flex items-center gap-2 text-sm">
                <input
                  type="checkbox"
                  checked={@show_coords}
                  phx-click="toggle_coords"
                  class="rounded"
                />
                Show Coordinates
              </label>
            </div>
            <div class="mt-2">
              <label class="block text-xs text-gray-500 mb-1">Tile Overlay</label>
              <div class="flex flex-wrap gap-1">
                <button
                  :for={{label, value} <- [{"None", "none"}, {"Relative", "elevation_relative"}, {"Absolute", "elevation_absolute"}, {"Terrain", "terrain"}]}
                  phx-click="set_tile_overlay"
                  phx-value-overlay={value}
                  class={"px-2 py-1 rounded text-xs #{if @tile_overlay == String.to_atom(value), do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
                >
                  {label}
                </button>
              </div>
            </div>
          </div>

          <!-- Undo/Redo -->
          <div class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">History</h3>
            <div class="flex gap-2">
              <button
                phx-click="undo"
                disabled={@undo_stack == []}
                class={"px-3 py-1 rounded text-sm #{if @undo_stack != [], do: "bg-gray-600 hover:bg-gray-500", else: "bg-gray-700 text-gray-500 cursor-not-allowed"}"}
              >
                Undo
              </button>
              <button
                phx-click="redo"
                disabled={@redo_stack == []}
                class={"px-3 py-1 rounded text-sm #{if @redo_stack != [], do: "bg-gray-600 hover:bg-gray-500", else: "bg-gray-700 text-gray-500 cursor-not-allowed"}"}
              >
                Redo
              </button>
            </div>
          </div>
        </aside>

        <!-- Map Canvas -->
        <main class="flex-1 relative">
          <canvas
            id="map-editor-canvas"
            phx-hook="MapEditorHook"
            phx-update="ignore"
            class="w-full h-full"
            data-width={@map.width}
            data-height={@map.height}
            data-hex-size="40"
            data-show-grid={@show_grid}
            data-show-coords={@show_coords}
            data-tile-overlay={@tile_overlay}
          />
        </main>

        <!-- Right Panel - Hex Info -->
        <aside class="w-64 bg-gray-800 text-white p-4 overflow-y-auto border-l border-gray-700">
          <!-- Hovered Hex Info (shows on hover, or selected if not hovering) -->
          <h3 class="text-sm font-semibold text-gray-400 mb-2">Hex Info</h3>
          <% display_hex = @hovered_hex || @selected_hex %>
          <%= if display_hex do %>
            <div class="space-y-2 text-sm">
              <p><span class="text-gray-400">Coordinates:</span> ({display_hex.q}, {display_hex.r})</p>
              <%= if tile = get_tile(@map, display_hex) do %>
                <p><span class="text-gray-400">Terrain:</span> {terrain_label(tile.terrain)}</p>
                <p>
                  <span class="text-gray-400">Elevation:</span>
                  {format_elevation(@map.base_elevation, tile.elevation)}
                </p>
                <%= if tile.edges != %{} do %>
                  <div>
                    <span class="text-gray-400">Edges:</span>
                    <ul class="ml-2 mt-1">
                      <%= for {dir, features} <- tile.edges do %>
                        <li>{direction_label(dir)}: {Enum.map_join(features, ", ", &feature_label/1)}</li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
                <%= if tile.overlays != [] do %>
                  <p><span class="text-gray-400">Overlays:</span> {Enum.map_join(tile.overlays, ", ", &overlay_label/1)}</p>
                <% end %>
                <%= if tile.control do %>
                  <p><span class="text-gray-400">Control:</span> {tile.control}</p>
                <% end %>
                <%= if tile.victory_points > 0 do %>
                  <p><span class="text-gray-400">Victory Points:</span> {tile.victory_points}</p>
                <% end %>
              <% end %>
            </div>
          <% else %>
            <p class="text-gray-500 text-sm">Hover over a hex to see details</p>
          <% end %>

          <div class="mt-6">
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Map Info</h3>
            <div class="space-y-1 text-sm">
              <p><span class="text-gray-400">Size:</span> {@map.width} x {@map.height}</p>
              <p><span class="text-gray-400">Scale:</span> {@map.scale}m per hex</p>
              <div class="flex items-center gap-2">
                <span class="text-gray-400">Base Elev:</span>
                <input
                  type="number"
                  value={@map.base_elevation}
                  phx-blur="set_base_elevation"
                  phx-keydown="set_base_elevation"
                  phx-key="Enter"
                  class="w-20 bg-gray-700 text-white px-2 py-0.5 rounded text-sm"
                  min="-1000"
                  max="9000"
                />
                <span class="text-gray-500">m</span>
              </div>
              <p><span class="text-gray-400">Tiles:</span> {map_size(@map.tiles)}</p>
            </div>
          </div>

          <%= if @line_start do %>
            <div class="mt-6 p-2 bg-yellow-900 rounded text-sm">
              <p class="text-yellow-200">Line mode active</p>
              <p class="text-gray-300">Start: ({@line_start.q}, {@line_start.r})</p>
              <p class="text-gray-400 text-xs mt-1">Click another hex to draw line</p>
              <button
                phx-click="cancel_line"
                class="mt-2 px-2 py-1 bg-gray-600 hover:bg-gray-500 rounded text-xs"
              >
                Cancel
              </button>
            </div>
          <% end %>
        </aside>
      </div>

      <!-- Footer Status Bar -->
      <footer class="bg-gray-800 text-white p-2 text-sm border-t border-gray-700">
        <div class="flex justify-between">
          <span class="text-gray-400">
            Mouse: Pan (drag) | Zoom (scroll) | Paint ({tool_label(@tool)})
          </span>
          <span :if={@hovered_hex} class="text-gray-300">
            Hover: ({@hovered_hex.q}, {@hovered_hex.r})
          </span>
        </div>
      </footer>

      <!-- Resize Modal -->
      <%= if @modal == :resize do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-gray-800 p-6 rounded-lg shadow-xl max-w-md w-full">
            <h2 class="text-xl font-bold text-white mb-4">Resize Map</h2>
            <form phx-submit="resize_map" class="space-y-4">
              <div>
                <label class="block text-sm text-gray-400 mb-1">Width (hexes)</label>
                <input
                  type="number"
                  name="width"
                  value={@map.width}
                  min="5"
                  max="100"
                  class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-400 mb-1">Height (hexes)</label>
                <input
                  type="number"
                  name="height"
                  value={@map.height}
                  min="5"
                  max="100"
                  class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-400 mb-1">Scale (meters per hex)</label>
                <input
                  type="number"
                  name="scale"
                  value={@map.scale}
                  min="50"
                  max="1000"
                  step="50"
                  class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                />
              </div>
              <div>
                <label class="block text-sm text-gray-400 mb-1">Base Elevation (meters)</label>
                <input
                  type="number"
                  name="base_elevation"
                  value={@map.base_elevation}
                  min="-1000"
                  max="9000"
                  step="1"
                  class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                />
                <p class="text-xs text-gray-500 mt-1">
                  Tile elevations are relative to this base (e.g., base 100m + tile level 2 = 102m)
                </p>
              </div>
              <div class="flex justify-end gap-2 mt-6">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 bg-gray-600 hover:bg-gray-500 rounded text-white"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-white"
                >
                  Apply
                </button>
              </div>
            </form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("map_ready", _params, socket) do
    tiles = map_to_tiles(socket.assigns.map)

    socket =
      socket
      |> push_event("set_config", %{baseElevation: socket.assigns.map.base_elevation})
      |> push_event("render_map", %{tiles: tiles})

    {:noreply, socket}
  end

  @impl true
  def handle_event("hex_selected", %{"q" => q, "r" => r, "shift" => shift}, socket) do
    coord = %{q: q, r: r}
    socket = assign(socket, :selected_hex, coord)

    socket =
      if shift and socket.assigns[:last_painted_hex] != nil do
        # Shift+click: draw line from last painted hex to current
        apply_shift_line(socket, coord)
      else
        # Normal click: apply current tool
        apply_tool(socket, coord)
      end

    # Track last painted hex for shift+click line drawing
    socket = assign(socket, :last_painted_hex, coord)
    {:noreply, socket}
  end

  # Fallback for events without shift key (backwards compatibility)
  def handle_event("hex_selected", %{"q" => q, "r" => r}, socket) do
    handle_event("hex_selected", %{"q" => q, "r" => r, "shift" => false}, socket)
  end

  @impl true
  def handle_event("hex_hovered", %{"q" => q, "r" => r}, socket) do
    coord = %{q: q, r: r}
    {:noreply, assign(socket, :hovered_hex, coord)}
  end

  @impl true
  def handle_event("select_tool", %{"tool" => tool}, socket) do
    tool_atom = String.to_existing_atom(tool)

    socket =
      socket
      |> assign(:tool, tool_atom)
      |> assign(:line_start, nil)
      |> push_event("set_config", %{elevationToolActive: tool_atom == :elevation})

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_brush_size", %{"size" => size}, socket) do
    {:noreply, assign(socket, :brush_size, String.to_integer(size))}
  end

  @impl true
  def handle_event("select_terrain", %{"terrain" => terrain}, socket) do
    {:noreply, assign(socket, :selected_terrain, String.to_existing_atom(terrain))}
  end

  @impl true
  def handle_event("select_elevation", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {elev, _} -> {:noreply, assign(socket, :selected_elevation, elev)}
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("increment_elevation", _params, socket) do
    {:noreply, assign(socket, :selected_elevation, socket.assigns.selected_elevation + 1)}
  end

  @impl true
  def handle_event("decrement_elevation", _params, socket) do
    {:noreply, assign(socket, :selected_elevation, socket.assigns.selected_elevation - 1)}
  end

  @impl true
  def handle_event("select_edge_feature", %{"feature" => feature}, socket) do
    {:noreply, assign(socket, :selected_edge_feature, String.to_existing_atom(feature))}
  end

  @impl true
  def handle_event("select_edge_direction", %{"direction" => dir}, socket) do
    {:noreply, assign(socket, :selected_edge_direction, String.to_integer(dir))}
  end

  @impl true
  def handle_event("select_overlay", %{"overlay" => overlay}, socket) do
    {:noreply, assign(socket, :selected_overlay, String.to_existing_atom(overlay))}
  end

  @impl true
  def handle_event("toggle_grid", _params, socket) do
    show_grid = !socket.assigns.show_grid
    socket = assign(socket, :show_grid, show_grid)
    {:noreply, push_event(socket, "set_config", %{showGrid: show_grid})}
  end

  @impl true
  def handle_event("toggle_coords", _params, socket) do
    show_coords = !socket.assigns.show_coords
    socket = assign(socket, :show_coords, show_coords)
    {:noreply, push_event(socket, "set_config", %{showCoords: show_coords})}
  end

  @impl true
  def handle_event("set_tile_overlay", %{"overlay" => overlay}, socket) do
    overlay_atom = String.to_existing_atom(overlay)
    socket = assign(socket, :tile_overlay, overlay_atom)
    {:noreply, push_event(socket, "set_config", %{tileOverlay: overlay, baseElevation: socket.assigns.map.base_elevation})}
  end

  @impl true
  def handle_event("set_base_elevation", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {base_elev, _} ->
        # Clamp to valid range
        base_elev = max(-1000, min(9000, base_elev))
        map = %{socket.assigns.map | base_elevation: base_elev}

        socket =
          socket
          |> assign(:map, map)
          |> push_event("set_config", %{baseElevation: base_elev})

        {:noreply, socket}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_map_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :map_name, name)}
  end

  @impl true
  def handle_event("cancel_line", _params, socket) do
    {:noreply, assign(socket, :line_start, nil)}
  end

  @impl true
  def handle_event("undo", _params, socket) do
    case socket.assigns.undo_stack do
      [prev_map | rest] ->
        socket =
          socket
          |> assign(:redo_stack, [socket.assigns.map | socket.assigns.redo_stack])
          |> assign(:undo_stack, rest)
          |> assign(:map, prev_map)
          |> refresh_map()

        {:noreply, socket}

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("redo", _params, socket) do
    case socket.assigns.redo_stack do
      [next_map | rest] ->
        socket =
          socket
          |> assign(:undo_stack, [socket.assigns.map | socket.assigns.undo_stack])
          |> assign(:redo_stack, rest)
          |> assign(:map, next_map)
          |> refresh_map()

        {:noreply, socket}

      [] ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("new_map", _params, socket) do
    map = create_empty_map(@default_width, @default_height, @default_scale)

    socket =
      socket
      |> push_history()
      |> assign(:map, map)
      |> assign(:map_name, "New Map")
      |> assign(:selected_hex, nil)
      |> refresh_map()

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_resize_modal", _params, socket) do
    {:noreply, assign(socket, :modal, :resize)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("resize_map", params, socket) do
    width = String.to_integer(params["width"])
    height = String.to_integer(params["height"])
    scale = String.to_integer(params["scale"])
    base_elevation = String.to_integer(params["base_elevation"] || "0")

    socket = push_history(socket)
    map = resize_map(socket.assigns.map, width, height, scale, base_elevation)

    socket =
      socket
      |> assign(:map, map)
      |> assign(:modal, nil)
      |> refresh_map()

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_map", _params, socket) do
    yaml = map_to_yaml(socket.assigns.map, socket.assigns.map_name)
    filename = sanitize_filename(socket.assigns.map_name) <> ".yaml"

    socket =
      socket
      |> push_event("download_file", %{content: yaml, filename: filename, type: "text/yaml"})
      |> assign(:save_status, "Saved!")

    Process.send_after(self(), :clear_save_status, 3000)
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_map", _params, socket) do
    {:noreply, push_event(socket, "request_file_upload", %{})}
  end

  @impl true
  def handle_event("file_loaded", %{"content" => content, "filename" => filename}, socket) do
    case parse_yaml_map(content) do
      {:ok, map, name} ->
        socket =
          socket
          |> push_history()
          |> assign(:map, map)
          |> assign(:map_name, name || Path.basename(filename, ".yaml"))
          |> refresh_map()

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load map: #{reason}")}
    end
  end

  @impl true
  def handle_info(:clear_save_status, socket) do
    {:noreply, assign(socket, :save_status, nil)}
  end

  # Tool Application

  defp apply_tool(socket, coord) do
    case socket.assigns.tool do
      :brush -> apply_brush(socket, coord)
      :fill -> apply_fill(socket, coord)
      :line -> apply_line(socket, coord)
      :elevation -> apply_elevation_tool(socket, coord)
      :edge -> apply_edge_tool(socket, coord)
      :overlay -> apply_overlay_tool(socket, coord)
      :eraser -> apply_eraser(socket, coord)
    end
  end

  defp apply_brush(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    terrain = socket.assigns.selected_terrain
    brush_size = socket.assigns.brush_size
    center = Coord.new(q, r)

    coords =
      if brush_size == 1 do
        [center]
      else
        WargameCore.Hex.Grid.hexes_in_range(center, brush_size - 1)
      end

    map =
      Enum.reduce(coords, socket.assigns.map, fn coord, acc_map ->
        case GameMap.set_terrain(acc_map, coord, terrain) do
          {:ok, updated} -> updated
          {:error, _} -> acc_map
        end
      end)

    socket
    |> assign(:map, map)
    |> update_tiles(coords)
  end

  defp apply_fill(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    coord = Coord.new(q, r)
    target_terrain = socket.assigns.selected_terrain
    map = socket.assigns.map

    case GameMap.get_tile(map, coord) do
      nil ->
        socket

      tile ->
        source_terrain = tile.terrain

        if source_terrain == target_terrain do
          socket
        else
          {updated_map, filled_coords} = flood_fill(map, coord, source_terrain, target_terrain, MapSet.new())

          socket
          |> assign(:map, updated_map)
          |> update_tiles(MapSet.to_list(filled_coords))
        end
    end
  end

  defp apply_line(socket, %{q: q, r: r}) do
    coord = Coord.new(q, r)

    case socket.assigns.line_start do
      nil ->
        assign(socket, :line_start, coord)

      start_coord ->
        socket = push_history(socket)
        terrain = socket.assigns.selected_terrain
        line_coords = WargameCore.Hex.Grid.line_draw(start_coord, coord)

        map =
          Enum.reduce(line_coords, socket.assigns.map, fn c, acc_map ->
            case GameMap.set_terrain(acc_map, c, terrain) do
              {:ok, updated} -> updated
              {:error, _} -> acc_map
            end
          end)

        socket
        |> assign(:map, map)
        |> assign(:line_start, nil)
        |> update_tiles(line_coords)
    end
  end

  # Shift+click line drawing: draws a line from last painted hex to current
  # using the current tool's settings (terrain, elevation, etc.)
  defp apply_shift_line(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    start = socket.assigns.last_painted_hex
    start_coord = Coord.new(start.q, start.r)
    end_coord = Coord.new(q, r)
    line_coords = WargameCore.Hex.Grid.line_draw(start_coord, end_coord)

    case socket.assigns.tool do
      tool when tool in [:brush, :line, :fill] ->
        # Apply terrain to line
        terrain = socket.assigns.selected_terrain

        map =
          Enum.reduce(line_coords, socket.assigns.map, fn c, acc_map ->
            case GameMap.set_terrain(acc_map, c, terrain) do
              {:ok, updated} -> updated
              {:error, _} -> acc_map
            end
          end)

        socket
        |> assign(:map, map)
        |> update_tiles(line_coords)

      :elevation ->
        # Apply elevation to line
        elevation = socket.assigns.selected_elevation

        map =
          Enum.reduce(line_coords, socket.assigns.map, fn c, acc_map ->
            case GameMap.set_elevation(acc_map, c, elevation) do
              {:ok, updated} -> updated
              {:error, _} -> acc_map
            end
          end)

        socket
        |> assign(:map, map)
        |> update_tiles(line_coords)

      :eraser ->
        # Erase along line
        map =
          Enum.reduce(line_coords, socket.assigns.map, fn c, acc_map ->
            case GameMap.update_tile(acc_map, c, fn tile ->
                   %{tile | terrain: :clear, elevation: 0, edges: %{}, overlays: []}
                 end) do
              {:ok, updated} -> updated
              {:error, _} -> acc_map
            end
          end)

        socket
        |> assign(:map, map)
        |> update_tiles(line_coords)

      _ ->
        # For edge/overlay tools, just apply to the endpoint
        apply_tool(socket, %{q: q, r: r})
    end
  end

  defp apply_elevation_tool(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    coord = Coord.new(q, r)
    elevation = socket.assigns.selected_elevation

    case GameMap.set_elevation(socket.assigns.map, coord, elevation) do
      {:ok, map} ->
        socket
        |> assign(:map, map)
        |> update_tiles([coord])

      {:error, _} ->
        socket
    end
  end

  defp apply_edge_tool(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    coord = Coord.new(q, r)
    feature = socket.assigns.selected_edge_feature
    direction = socket.assigns.selected_edge_direction

    case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
           Tile.add_edge_feature(tile, direction, feature)
         end) do
      {:ok, map} ->
        socket
        |> assign(:map, map)
        |> update_tiles([coord])

      {:error, _} ->
        socket
    end
  end

  defp apply_overlay_tool(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    coord = Coord.new(q, r)
    overlay = socket.assigns.selected_overlay

    case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
           if overlay in tile.overlays do
             Tile.remove_overlay(tile, overlay)
           else
             Tile.add_overlay(tile, overlay)
           end
         end) do
      {:ok, map} ->
        socket
        |> assign(:map, map)
        |> update_tiles([coord])

      {:error, _} ->
        socket
    end
  end

  defp apply_eraser(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    brush_size = socket.assigns.brush_size
    center = Coord.new(q, r)

    coords =
      if brush_size == 1 do
        [center]
      else
        WargameCore.Hex.Grid.hexes_in_range(center, brush_size - 1)
      end

    map =
      Enum.reduce(coords, socket.assigns.map, fn coord, acc_map ->
        case GameMap.update_tile(acc_map, coord, fn tile ->
               %{tile | terrain: :clear, elevation: 0, edges: %{}, overlays: []}
             end) do
          {:ok, updated} -> updated
          {:error, _} -> acc_map
        end
      end)

    socket
    |> assign(:map, map)
    |> update_tiles(coords)
  end

  # Flood fill implementation
  defp flood_fill(map, coord, source_terrain, target_terrain, visited) do
    if MapSet.member?(visited, coord) do
      {map, visited}
    else
      case GameMap.get_tile(map, coord) do
        nil ->
          {map, visited}

        tile when tile.terrain != source_terrain ->
          {map, visited}

        _tile ->
          visited = MapSet.put(visited, coord)

          case GameMap.set_terrain(map, coord, target_terrain) do
            {:ok, updated_map} ->
              neighbors = Coord.neighbors(coord)

              Enum.reduce(neighbors, {updated_map, visited}, fn neighbor, {acc_map, acc_visited} ->
                flood_fill(acc_map, neighbor, source_terrain, target_terrain, acc_visited)
              end)

            {:error, _} ->
              {map, visited}
          end
      end
    end
  end

  # Helper functions

  defp push_history(socket) do
    undo_stack = [socket.assigns.map | socket.assigns.undo_stack] |> Enum.take(50)
    assign(socket, undo_stack: undo_stack, redo_stack: [])
  end

  defp update_tiles(socket, coords) do
    tiles =
      Enum.map(coords, fn coord ->
        c = if is_struct(coord, Coord), do: coord, else: Coord.new(coord.q, coord.r)

        case GameMap.get_tile(socket.assigns.map, c) do
          nil -> nil
          tile -> tile_to_json(tile)
        end
      end)
      |> Enum.reject(&is_nil/1)

    push_event(socket, "update_tiles", %{tiles: tiles})
  end

  defp refresh_map(socket) do
    tiles = map_to_tiles(socket.assigns.map)
    push_event(socket, "render_map", %{tiles: tiles})
  end

  defp create_empty_map(width, height, scale) do
    GameMap.new("New Map", width, height, scale)
  end

  defp resize_map(old_map, new_width, new_height, new_scale, new_base_elevation) do
    new_map = GameMap.new(old_map.name, new_width, new_height, new_scale,
      base_elevation: new_base_elevation)

    # Copy over existing tiles that fit in the new dimensions
    Enum.reduce(GameMap.all_tiles(old_map), new_map, fn tile, acc_map ->
      if tile.coord.q >= 0 and tile.coord.q < new_width and
           tile.coord.r >= 0 and tile.coord.r < new_height do
        case GameMap.update_tile(acc_map, tile.coord, fn _new_tile -> tile end) do
          {:ok, updated} -> updated
          {:error, _} -> acc_map
        end
      else
        acc_map
      end
    end)
  end

  defp get_tile(map, %{q: q, r: r}) do
    coord = Coord.new(q, r)
    GameMap.get_tile(map, coord)
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

  # YAML serialization
  defp map_to_yaml(map, name) do
    tiles_yaml =
      map
      |> GameMap.all_tiles()
      |> Enum.reject(fn tile ->
        # Skip default tiles (clear terrain, no elevation, no features)
        tile.terrain == :clear and tile.elevation == 0 and
          tile.edges == %{} and tile.overlays == []
      end)
      |> Enum.map(&tile_to_yaml/1)
      |> Enum.join("\n")

    base_elevation_line = if map.base_elevation != 0 do
      "base_elevation: #{map.base_elevation}\n"
    else
      ""
    end

    """
    # Wargame Map File
    # Generated by Wargame Platform Map Editor

    name: "#{escape_yaml_string(name)}"
    width: #{map.width}
    height: #{map.height}
    scale: #{map.scale}
    #{base_elevation_line}
    tiles:
    #{tiles_yaml}
    """
  end

  defp tile_to_yaml(tile) do
    base = "  - coord: [#{tile.coord.q}, #{tile.coord.r}]\n    terrain: #{tile.terrain}"

    elevation =
      if tile.elevation > 0,
        do: "\n    elevation: #{tile.elevation}",
        else: ""

    edges =
      if tile.edges != %{} do
        edges_str =
          tile.edges
          |> Enum.map(fn {dir, features} ->
            features_str = Enum.map_join(features, ", ", &Atom.to_string/1)
            "#{dir}: [#{features_str}]"
          end)
          |> Enum.join(", ")

        "\n    edges: {#{edges_str}}"
      else
        ""
      end

    overlays =
      if tile.overlays != [] do
        overlays_str = Enum.map_join(tile.overlays, ", ", &Atom.to_string/1)
        "\n    overlays: [#{overlays_str}]"
      else
        ""
      end

    control =
      if tile.control,
        do: "\n    control: #{tile.control}",
        else: ""

    vp =
      if tile.victory_points > 0,
        do: "\n    victoryPoints: #{tile.victory_points}",
        else: ""

    base <> elevation <> edges <> overlays <> control <> vp
  end

  defp escape_yaml_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end

  defp parse_yaml_map(content) do
    # Simple YAML parser for our map format
    try do
      lines = String.split(content, "\n")

      {metadata, tile_lines} = parse_yaml_sections(lines)

      width = Map.get(metadata, "width", @default_width)
      height = Map.get(metadata, "height", @default_height)
      scale = Map.get(metadata, "scale", @default_scale)
      base_elevation = Map.get(metadata, "base_elevation", 0)
      name = Map.get(metadata, "name", "Loaded Map")

      map = GameMap.new(name, width, height, scale, base_elevation: base_elevation)
      map = apply_yaml_tiles(map, tile_lines)

      {:ok, map, name}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_yaml_sections(lines) do
    lines = Enum.reject(lines, &String.starts_with?(String.trim(&1), "#"))

    {metadata_lines, rest} = Enum.split_while(lines, fn line ->
      trimmed = String.trim(line)
      trimmed != "tiles:" and not String.starts_with?(trimmed, "- coord:")
    end)

    metadata =
      metadata_lines
      |> Enum.map(&parse_yaml_line/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    tile_lines = Enum.drop_while(rest, fn line ->
      String.trim(line) == "tiles:"
    end)

    {metadata, tile_lines}
  end

  defp parse_yaml_line(line) do
    case Regex.run(~r/^(\w+):\s*(.+)$/, String.trim(line)) do
      [_, key, value] ->
        parsed_value = parse_yaml_value(value)
        {key, parsed_value}

      _ ->
        nil
    end
  end

  defp parse_yaml_value(value) do
    cond do
      Regex.match?(~r/^\d+$/, value) -> String.to_integer(value)
      Regex.match?(~r/^".*"$/, value) -> String.slice(value, 1..-2//1)
      Regex.match?(~r/^'.*'$/, value) -> String.slice(value, 1..-2//1)
      true -> value
    end
  end

  defp apply_yaml_tiles(map, lines) do
    tiles = parse_yaml_tiles(lines)

    Enum.reduce(tiles, map, fn tile_data, acc_map ->
      coord = Coord.new(tile_data.q, tile_data.r)

      case GameMap.update_tile(acc_map, coord, fn tile ->
             tile
             |> Map.put(:terrain, tile_data.terrain)
             |> Map.put(:elevation, tile_data.elevation)
             |> Map.put(:edges, tile_data.edges)
             |> Map.put(:overlays, tile_data.overlays)
             |> Map.put(:control, tile_data.control)
             |> Map.put(:victory_points, tile_data.victory_points)
           end) do
        {:ok, updated} -> updated
        {:error, _} -> acc_map
      end
    end)
  end

  defp parse_yaml_tiles(lines) do
    lines
    |> Enum.chunk_while(
      nil,
      fn line, acc ->
        trimmed = String.trim(line)

        if String.starts_with?(trimmed, "- coord:") do
          if acc, do: {:cont, acc, [line]}, else: {:cont, [line]}
        else
          if acc, do: {:cont, acc ++ [line]}, else: {:cont, [line]}
        end
      end,
      fn acc -> if acc, do: {:cont, acc, nil}, else: {:cont, nil} end
    )
    |> Enum.map(&parse_single_tile/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_single_tile(lines) do
    joined = Enum.join(lines, "\n")

    coord_match = Regex.run(~r/coord:\s*\[(\d+),\s*(\d+)\]/, joined)
    terrain_match = Regex.run(~r/terrain:\s*(\w+)/, joined)
    elevation_match = Regex.run(~r/elevation:\s*(\d+)/, joined)

    if coord_match && terrain_match do
      [_, q, r] = coord_match
      [_, terrain] = terrain_match
      elevation = if elevation_match, do: String.to_integer(Enum.at(elevation_match, 1)), else: 0

      %{
        q: String.to_integer(q),
        r: String.to_integer(r),
        terrain: String.to_existing_atom(terrain),
        elevation: elevation,
        edges: %{},
        overlays: [],
        control: nil,
        victory_points: 0
      }
    else
      nil
    end
  end

  defp sanitize_filename(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    |> String.replace(~r/_+/, "_")
    |> String.trim("_")
  end

  # UI helper functions

  defp tool_label(:brush), do: "Brush"
  defp tool_label(:fill), do: "Fill"
  defp tool_label(:line), do: "Line"
  defp tool_label(:elevation), do: "Elev"
  defp tool_label(:edge), do: "Edge"
  defp tool_label(:overlay), do: "Overlay"
  defp tool_label(:eraser), do: "Eraser"

  defp terrain_label(terrain) when is_atom(terrain) do
    # Short labels for compact display
    case terrain do
      :clear -> "Clear"
      :forest_pine -> "Pine"
      :forest_deciduous -> "Decid"
      :hill -> "Hill"
      :mountain -> "Mtn"
      :desert -> "Desert"
      :farmland -> "Farm"
      :pasture -> "Pasture"
      :swamp -> "Swamp"
      :marsh -> "Marsh"
      :lake -> "Lake"
      :river -> "River"
      :ocean -> "Ocean"
      :urban -> "Urban"
      :village -> "Village"
      :ruins -> "Ruins"
      :road -> "Road"
      :railroad -> "Rail"
      :fortification -> "Fort"
      :minefield -> "Mine"
      _ ->
        terrain
        |> Atom.to_string()
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
    end
  end

  defp terrain_label(terrain), do: terrain

  defp terrain_button_class(terrain) do
    case terrain do
      :clear -> "bg-green-200 text-green-900"
      :forest_pine -> "bg-green-700 text-white"
      :forest_deciduous -> "bg-green-500 text-white"
      :hill -> "bg-amber-700 text-white"
      :mountain -> "bg-gray-500 text-white"
      :desert -> "bg-yellow-300 text-yellow-900"
      :farmland -> "bg-yellow-600 text-white"
      :pasture -> "bg-green-300 text-green-900"
      :swamp -> "bg-green-900 text-white"
      :marsh -> "bg-green-800 text-white"
      :lake -> "bg-blue-600 text-white"
      :river -> "bg-blue-500 text-white"
      :ocean -> "bg-blue-900 text-white"
      :urban -> "bg-gray-600 text-white"
      :village -> "bg-gray-400 text-gray-900"
      :ruins -> "bg-orange-800 text-white"
      :road -> "bg-amber-200 text-amber-900"
      :railroad -> "bg-gray-700 text-white"
      :fortification -> "bg-orange-900 text-white"
      :minefield -> "bg-red-500 text-white"
      _ -> "bg-gray-600 text-white"
    end
  end

  defp feature_label(feature) when is_atom(feature) do
    feature
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp feature_label(feature), do: feature

  defp direction_label(0), do: "E"
  defp direction_label(1), do: "SE"
  defp direction_label(2), do: "SW"
  defp direction_label(3), do: "W"
  defp direction_label(4), do: "NW"
  defp direction_label(5), do: "NE"
  defp direction_label(dir), do: "#{dir}"

  defp overlay_label(overlay) when is_atom(overlay) do
    overlay
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp overlay_label(overlay), do: overlay

  defp format_elevation(base_elevation, tile_elevation) do
    abs_elev = base_elevation + tile_elevation

    if tile_elevation == 0 do
      "#{abs_elev}m"
    else
      sign = if tile_elevation > 0, do: "+", else: ""
      "#{abs_elev}m (#{sign}#{tile_elevation})"
    end
  end
end
