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
  alias WargameCore.Map.TransportSegment
  alias WargameCore.Terrain.TerrainType

  @default_width 20
  @default_height 15
  @default_scale 200

  @impl true
  def mount(_params, _session, socket) do
    terrain_types = TerrainType.all() |> Enum.map(& &1.id)
    edge_features = [:none, :small_stream, :large_stream, :small_river, :large_river]
    overlay_types = [:minefield, :fortification, :trench, :wire, :bunker]
    transport_segment_types = TransportSegment.all_types()
    objective_forces = [:allied, :axis, :soviet, :german, :american, :british, :french, :japanese, :neutral]

    socket =
      socket
      |> assign(:map, create_empty_map(@default_width, @default_height, @default_scale))
      |> assign(:map_name, "New Map")
      |> assign(:selected_hex, nil)
      |> assign(:hovered_hex, nil)
      |> assign(:tool, :brush)
      |> assign(:selected_terrain, :clear)
      |> assign(:selected_elevation, 0)
      |> assign(:selected_edge_feature, :none)
      |> assign(:selected_water_edges, MapSet.new())
      |> assign(:selected_overlay, :trench)
      |> assign(:selected_segment_type, :small_paved_road)
      |> assign(:selected_entry_edges, MapSet.new())
      |> assign(:selected_exit_edges, MapSet.new())
      |> assign(:objective_name, "")
      |> assign(:objective_force, :neutral)
      |> assign(:objective_points, 0)
      |> assign(:objective_forces, objective_forces)
      |> assign(:brush_size, 1)
      |> assign(:terrain_types, terrain_types)
      |> assign(:edge_features, edge_features)
      |> assign(:overlay_types, overlay_types)
      |> assign(:transport_segment_types, transport_segment_types)
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
            <div class="grid grid-cols-3 gap-1">
              <button
                :for={tool <- [:brush, :fill, :line, :elevation, :edge, :transport, :overlay, :objective, :eraser]}
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
            <h3 class="text-sm font-semibold text-gray-400 mb-2">Water Type</h3>
            <div class="flex gap-3">
              <!-- Left column: Water type palette -->
              <div class="flex flex-col gap-1">
                <button
                  :for={feature <- [:small_stream, :large_stream, :small_river, :large_river]}
                  phx-click="select_edge_feature"
                  phx-value-feature={feature}
                  class={"px-2 py-1 rounded text-xs whitespace-nowrap #{if @selected_edge_feature == feature, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
                >
                  {feature_label(feature)}
                </button>
              </div>

              <!-- Right column: SVG mini-hexagon (pointy-top, matching map) -->
              <div class="flex flex-col items-center">
                <p class="text-xs text-gray-500 mb-1">Click edges:</p>
                <svg viewBox="0 0 100 100" class="w-20 h-20">
                  <!-- Hex fill (pointy-top orientation) -->
                  <polygon
                    points={hex_points()}
                    fill="#374151"
                    stroke="#6B7280"
                    stroke-width="1"
                  />

                  <!-- Visible edge styling based on selection (render first, behind clickable areas) -->
                  <%= for edge <- 0..5 do %>
                    <% {{x1, y1}, {x2, y2}} = edge_coords(edge) %>
                    <%= if MapSet.member?(@selected_water_edges, edge) do %>
                      <line
                        x1={x1}
                        y1={y1}
                        x2={x2}
                        y2={y2}
                        stroke={edge_color(@selected_edge_feature)}
                        stroke-width={edge_stroke_width(@selected_edge_feature)}
                        stroke-linecap="round"
                      />
                    <% end %>
                  <% end %>

                  <!-- Clickable edge segments (wider invisible stroke for easy clicking) -->
                  <%= for edge <- 0..5 do %>
                    <% {{x1, y1}, {x2, y2}} = edge_coords(edge) %>
                    <line
                      x1={x1}
                      y1={y1}
                      x2={x2}
                      y2={y2}
                      stroke="transparent"
                      stroke-width="14"
                      class="cursor-pointer hover:stroke-white/20"
                      phx-click="toggle_water_edge"
                      phx-value-edge={edge}
                    />
                  <% end %>

                  <!-- Edge labels (positioned for pointy-top hex edges) -->
                  <!-- Edge 0 (N): top to upper-right slant -->
                  <!-- Edge 1 (NE): right vertical edge -->
                  <!-- Edge 2 (SE): lower-right to bottom slant -->
                  <!-- Edge 3 (S): bottom to lower-left slant -->
                  <!-- Edge 4 (SW): left vertical edge -->
                  <!-- Edge 5 (NW): upper-left to top slant -->
                  <text x="72" y="12" text-anchor="start" fill="#9CA3AF" font-size="7">N</text>
                  <text x="92" y="52" text-anchor="start" fill="#9CA3AF" font-size="7">NE</text>
                  <text x="72" y="90" text-anchor="start" fill="#9CA3AF" font-size="7">SE</text>
                  <text x="28" y="90" text-anchor="end" fill="#9CA3AF" font-size="7">S</text>
                  <text x="8" y="52" text-anchor="end" fill="#9CA3AF" font-size="7">SW</text>
                  <text x="28" y="12" text-anchor="end" fill="#9CA3AF" font-size="7">NW</text>
                </svg>
              </div>
            </div>

            <p class="text-xs text-gray-500 mt-2">
              Select type, toggle edges, then click hex on map.
            </p>
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

          <!-- Transport Segment Selection -->
          <div :if={@tool == :transport} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Segment Type</h3>
            <div class="flex flex-wrap gap-1 mb-3">
              <button
                :for={seg_type <- @transport_segment_types}
                phx-click="select_segment_type"
                phx-value-type={seg_type}
                class={"px-2 py-1 rounded text-xs #{if @selected_segment_type == seg_type, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {segment_type_label(seg_type)}
              </button>
            </div>

            <h4 class="text-xs font-semibold text-gray-400 mb-1">Entry Edges</h4>
            <div class="flex flex-wrap gap-1 mb-2">
              <button
                :for={dir <- 0..5}
                phx-click="toggle_entry_edge"
                phx-value-edge={dir}
                class={"px-2 py-1 rounded text-xs #{if MapSet.member?(@selected_entry_edges, dir), do: "bg-green-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {direction_label(dir)}
              </button>
            </div>

            <h4 class="text-xs font-semibold text-gray-400 mb-1">Exit Edges</h4>
            <div class="flex flex-wrap gap-1 mb-3">
              <button
                :for={dir <- 0..5}
                phx-click="toggle_exit_edge"
                phx-value-edge={dir}
                class={"px-2 py-1 rounded text-xs #{if MapSet.member?(@selected_exit_edges, dir), do: "bg-orange-600", else: "bg-gray-600 hover:bg-gray-500"}"}
              >
                {direction_label(dir)}
              </button>
            </div>

            <p class="text-xs text-gray-500 mb-2">
              Select edges then click a hex to add segment.
              Click existing segment to remove it.
            </p>

            <div class="flex gap-1">
              <button
                phx-click="clear_edge_selection"
                class="flex-1 px-2 py-1 rounded text-xs bg-gray-700 hover:bg-gray-600"
              >
                Clear Selection
              </button>
              <button
                phx-click="clear_tile_transport"
                class="flex-1 px-2 py-1 rounded text-xs bg-red-700 hover:bg-red-600"
              >
                Clear Transport
              </button>
            </div>
          </div>

          <!-- Objective Tool -->
          <div :if={@tool == :objective} class="mb-4">
            <h3 class="text-sm font-semibold text-gray-400 mb-1">Objective</h3>
            <div class="space-y-2">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Name</label>
                <input
                  type="text"
                  value={@objective_name}
                  phx-blur="set_objective_name"
                  phx-keydown="set_objective_name"
                  phx-key="Enter"
                  class="w-full bg-gray-700 text-white px-2 py-1 rounded text-sm"
                  placeholder="e.g., Hill 223"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Force</label>
                <div class="flex flex-wrap gap-1">
                  <button
                    :for={force <- @objective_forces}
                    phx-click="set_objective_force"
                    phx-value-force={force}
                    class={"px-2 py-1 rounded text-xs #{if @objective_force == force, do: "bg-blue-600", else: "bg-gray-600 hover:bg-gray-500"}"}
                  >
                    {force_label(force)}
                  </button>
                </div>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Victory Points</label>
                <input
                  type="number"
                  value={@objective_points}
                  phx-blur="set_objective_points"
                  phx-keydown="set_objective_points"
                  phx-key="Enter"
                  class="w-20 bg-gray-700 text-white px-2 py-1 rounded text-sm"
                  min="0"
                  max="100"
                />
              </div>
              <p class="text-xs text-gray-500">
                Click a hex to set objective.
                Click again to clear.
              </p>
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
                <%= if tile.transport_segments != [] do %>
                  <div>
                    <span class="text-gray-400">Transport:</span>
                    <ul class="ml-2 mt-1 text-xs">
                      <%= for segment <- tile.transport_segments do %>
                        <li class="flex items-center justify-between py-0.5">
                          <span>
                            {segment_type_label(segment.type)}
                            <span class="text-gray-500">
                              ({format_segment_edges(segment)})
                            </span>
                          </span>
                          <button
                            phx-click="remove_transport_segment"
                            phx-value-q={display_hex.q}
                            phx-value-r={display_hex.r}
                            phx-value-type={segment.type}
                            phx-value-entry={Enum.join(segment.entry_edges, ",")}
                            phx-value-exit={Enum.join(segment.exit_edges, ",")}
                            class="text-red-400 hover:text-red-300 text-xs px-1"
                          >
                            ×
                          </button>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
                <%= if tile.control do %>
                  <p><span class="text-gray-400">Control:</span> {tile.control}</p>
                <% end %>
                <%= if tile.victory_points > 0 do %>
                  <p><span class="text-gray-400">Victory Points:</span> {tile.victory_points}</p>
                <% end %>
                <%= if tile.objective do %>
                  <div>
                    <span class="text-gray-400">Objective:</span>
                    <span class="text-yellow-300 ml-1">★</span>
                    <%= if tile.objective.name do %>
                      <span>{tile.objective.name}</span>
                    <% end %>
                    <%= if tile.objective.force do %>
                      <span class="text-xs text-gray-400">({force_label(tile.objective.force)})</span>
                    <% end %>
                  </div>
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
              <div>
                <label class="block text-sm text-gray-400 mb-1">Version</label>
                <input
                  type="text"
                  name="version"
                  value={@map.version}
                  class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                  placeholder="1.0"
                />
              </div>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-sm text-gray-400 mb-1">Centerpoint Lat</label>
                  <input
                    type="number"
                    name="centerpoint_lat"
                    value={@map.centerpoint_lat}
                    step="0.0001"
                    min="-90"
                    max="90"
                    class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                    placeholder="e.g., 50.6292"
                  />
                </div>
                <div>
                  <label class="block text-sm text-gray-400 mb-1">Centerpoint Lng</label>
                  <input
                    type="number"
                    name="centerpoint_lng"
                    value={@map.centerpoint_lng}
                    step="0.0001"
                    min="-180"
                    max="180"
                    class="w-full bg-gray-700 text-white px-3 py-2 rounded"
                    placeholder="e.g., 36.2405"
                  />
                </div>
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
  @impl true
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
  def handle_event("toggle_water_edge", %{"edge" => edge_str}, socket) do
    edge = String.to_integer(edge_str)
    water_edges = socket.assigns.selected_water_edges

    updated_edges =
      if MapSet.member?(water_edges, edge) do
        MapSet.delete(water_edges, edge)
      else
        MapSet.put(water_edges, edge)
      end

    {:noreply, assign(socket, :selected_water_edges, updated_edges)}
  end

  @impl true
  def handle_event("clear_water_edge_selection", _params, socket) do
    {:noreply, assign(socket, :selected_water_edges, MapSet.new())}
  end

  @impl true
  def handle_event("clear_tile_edges", _params, socket) do
    display_hex = socket.assigns.selected_hex || socket.assigns.hovered_hex

    if display_hex do
      coord = Coord.new(display_hex.q, display_hex.r)
      socket = push_history(socket)

      case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
             %{tile | edges: %{}}
           end) do
        {:ok, map} ->
          socket =
            socket
            |> assign(:map, map)
            |> update_tiles([coord])

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_overlay", %{"overlay" => overlay}, socket) do
    {:noreply, assign(socket, :selected_overlay, String.to_existing_atom(overlay))}
  end

  @impl true
  def handle_event("select_segment_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_segment_type, String.to_existing_atom(type))}
  end

  @impl true
  def handle_event("toggle_entry_edge", %{"edge" => edge_str}, socket) do
    edge = String.to_integer(edge_str)
    entry_edges = socket.assigns.selected_entry_edges

    updated_edges =
      if MapSet.member?(entry_edges, edge) do
        MapSet.delete(entry_edges, edge)
      else
        MapSet.put(entry_edges, edge)
      end

    {:noreply, assign(socket, :selected_entry_edges, updated_edges)}
  end

  @impl true
  def handle_event("toggle_exit_edge", %{"edge" => edge_str}, socket) do
    edge = String.to_integer(edge_str)
    exit_edges = socket.assigns.selected_exit_edges

    updated_edges =
      if MapSet.member?(exit_edges, edge) do
        MapSet.delete(exit_edges, edge)
      else
        MapSet.put(exit_edges, edge)
      end

    {:noreply, assign(socket, :selected_exit_edges, updated_edges)}
  end

  @impl true
  def handle_event("clear_edge_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_entry_edges, MapSet.new())
      |> assign(:selected_exit_edges, MapSet.new())

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_tile_transport", _params, socket) do
    # Clear all transport segments from the selected or hovered hex
    display_hex = socket.assigns.selected_hex || socket.assigns.hovered_hex

    if display_hex do
      coord = Coord.new(display_hex.q, display_hex.r)
      socket = push_history(socket)

      case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
             Tile.clear_transport_segments(tile)
           end) do
        {:ok, map} ->
          socket =
            socket
            |> assign(:map, map)
            |> update_tiles([coord])

          {:noreply, socket}

        {:error, _} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_transport_segment", params, socket) do
    %{"q" => q_str, "r" => r_str, "type" => type_str, "entry" => entry_str, "exit" => exit_str} = params

    coord = Coord.new(String.to_integer(q_str), String.to_integer(r_str))
    type = String.to_existing_atom(type_str)
    entry_edges = parse_edge_list(entry_str)
    exit_edges = parse_edge_list(exit_str)

    segment = TransportSegment.new(type, entry_edges, exit_edges)

    socket = push_history(socket)

    case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
           Tile.remove_transport_segment(tile, segment)
         end) do
      {:ok, map} ->
        socket =
          socket
          |> assign(:map, map)
          |> update_tiles([coord])

        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_objective_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, :objective_name, value)}
  end

  @impl true
  def handle_event("set_objective_force", %{"force" => force}, socket) do
    {:noreply, assign(socket, :objective_force, String.to_existing_atom(force))}
  end

  @impl true
  def handle_event("set_objective_points", %{"value" => value}, socket) do
    case Integer.parse(value) do
      {points, _} -> {:noreply, assign(socket, :objective_points, max(0, points))}
      :error -> {:noreply, socket}
    end
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
    version = params["version"] || "1.0"
    centerpoint_lat = parse_float(params["centerpoint_lat"])
    centerpoint_lng = parse_float(params["centerpoint_lng"])

    socket = push_history(socket)

    map =
      resize_map(socket.assigns.map, width, height, scale, base_elevation,
        version: version,
        centerpoint_lat: centerpoint_lat,
        centerpoint_lng: centerpoint_lng
      )

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

  # Helper Functions

  defp parse_float(nil), do: nil
  defp parse_float(""), do: nil

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> nil
    end
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  # Tool Application

  defp apply_tool(socket, coord) do
    case socket.assigns.tool do
      :brush -> apply_brush(socket, coord)
      :fill -> apply_fill(socket, coord)
      :line -> apply_line(socket, coord)
      :elevation -> apply_elevation_tool(socket, coord)
      :edge -> apply_edge_tool(socket, coord)
      :transport -> apply_transport_tool(socket, coord)
      :overlay -> apply_overlay_tool(socket, coord)
      :objective -> apply_objective_tool(socket, coord)
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
    water_edges = socket.assigns.selected_water_edges
    socket = push_history(socket)
    coord = Coord.new(q, r)
    feature = socket.assigns.selected_edge_feature

    # The mini-hex represents the desired state of the tile's edges.
    # Selected edges get the selected feature; unselected edges are cleared.
    case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
           Enum.reduce(0..5, tile, fn edge, acc_tile ->
             if MapSet.member?(water_edges, edge) do
               if feature == :none do
                 # Edge selected but feature is :none -> clear this edge
                 Tile.clear_edge(acc_tile, edge)
               else
                 # Edge selected with a feature -> set this edge to the feature
                 # First clear any existing features, then add the new one
                 acc_tile
                 |> Tile.clear_edge(edge)
                 |> Tile.add_edge_feature(edge, feature)
               end
             else
               # Edge not selected -> clear it
               Tile.clear_edge(acc_tile, edge)
             end
           end)
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

  defp apply_transport_tool(socket, %{q: q, r: r}) do
    entry_edges = socket.assigns.selected_entry_edges
    exit_edges = socket.assigns.selected_exit_edges

    # Only apply if at least one edge is selected
    if MapSet.size(entry_edges) == 0 and MapSet.size(exit_edges) == 0 do
      socket
    else
      socket = push_history(socket)
      coord = Coord.new(q, r)
      segment_type = socket.assigns.selected_segment_type

      segment =
        TransportSegment.new(
          segment_type,
          MapSet.to_list(entry_edges),
          MapSet.to_list(exit_edges)
        )

      case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
             Tile.add_transport_segment(tile, segment)
           end) do
        {:ok, map} ->
          socket
          |> assign(:map, map)
          |> update_tiles([coord])

        {:error, _} ->
          socket
      end
    end
  end

  defp apply_objective_tool(socket, %{q: q, r: r}) do
    socket = push_history(socket)
    coord = Coord.new(q, r)

    name = socket.assigns.objective_name
    force = socket.assigns.objective_force
    points = socket.assigns.objective_points

    # Toggle: if tile already has an objective, clear it; otherwise set it
    case GameMap.update_tile(socket.assigns.map, coord, fn tile ->
           if tile.objective do
             # Clear objective
             tile
             |> Tile.clear_objective()
             |> Tile.set_victory_points(0)
           else
             # Set objective
             tile
             |> Tile.set_objective(if(name == "", do: nil, else: name), force)
             |> Tile.set_victory_points(points)
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

  defp resize_map(old_map, new_width, new_height, new_scale, new_base_elevation, opts) do
    version = Keyword.get(opts, :version, old_map.version)
    centerpoint_lat = Keyword.get(opts, :centerpoint_lat, old_map.centerpoint_lat)
    centerpoint_lng = Keyword.get(opts, :centerpoint_lng, old_map.centerpoint_lng)

    new_map =
      GameMap.new(old_map.name, new_width, new_height, new_scale,
        base_elevation: new_base_elevation,
        version: version,
        centerpoint_lat: centerpoint_lat,
        centerpoint_lng: centerpoint_lng
      )

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
      transportSegments: transport_segments_to_json(tile.transport_segments),
      control: if(tile.control, do: Atom.to_string(tile.control), else: nil),
      victoryPoints: tile.victory_points,
      name: tile.name,
      objective: objective_to_json(tile.objective)
    }
  end

  defp edges_to_json(edges) do
    edges
    |> Enum.map(fn {dir, features} ->
      {Integer.to_string(dir), Enum.map(features, &Atom.to_string/1)}
    end)
    |> Enum.into(%{})
  end

  defp transport_segments_to_json(segments) do
    Enum.map(segments, fn segment ->
      %{
        type: Atom.to_string(segment.type),
        entry_edges: segment.entry_edges,
        exit_edges: segment.exit_edges
      }
    end)
  end

  defp objective_to_json(nil), do: nil

  defp objective_to_json(%{name: name, force: force}) do
    %{
      name: name,
      force: if(force, do: Atom.to_string(force), else: nil)
    }
  end

  # YAML serialization
  defp map_to_yaml(map, name) do
    tiles_yaml =
      map
      |> GameMap.all_tiles()
      |> Enum.reject(fn tile ->
        # Skip default tiles (clear terrain, no elevation, no features)
        tile.terrain == :clear and tile.elevation == 0 and
          tile.edges == %{} and tile.overlays == [] and
          tile.transport_segments == [] and tile.objective == nil
      end)
      |> Enum.map(&tile_to_yaml/1)
      |> Enum.join("\n")

    base_elevation_line =
      if map.base_elevation != 0 do
        "base_elevation: #{map.base_elevation}\n"
      else
        ""
      end

    centerpoint_lines =
      if map.centerpoint_lat && map.centerpoint_lng do
        """
        centerpoint:
          lat: #{map.centerpoint_lat}
          lng: #{map.centerpoint_lng}
        """
      else
        ""
      end

    """
    # Wargame Map File
    # Generated by Wargame Platform Map Editor

    name: "#{escape_yaml_string(name)}"
    version: "#{map.version}"
    width: #{map.width}
    height: #{map.height}
    scale: #{map.scale}
    #{base_elevation_line}#{centerpoint_lines}
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
        do: "\n    victory_points: #{tile.victory_points}",
        else: ""

    transport_segments =
      if tile.transport_segments != [] do
        segments_str =
          tile.transport_segments
          |> Enum.map(fn segment ->
            entry_str = "[#{Enum.join(segment.entry_edges, ", ")}]"
            exit_str = "[#{Enum.join(segment.exit_edges, ", ")}]"
            "      - type: #{segment.type}\n        entry: #{entry_str}\n        exit: #{exit_str}"
          end)
          |> Enum.join("\n")

        "\n    transport_segments:\n#{segments_str}"
      else
        ""
      end

    objective =
      if tile.objective do
        obj = tile.objective
        name_line = if obj.name, do: "\n      name: \"#{escape_yaml_string(obj.name)}\"", else: ""
        force_line = if obj.force, do: "\n      force: #{obj.force}", else: ""
        "\n    objective:#{name_line}#{force_line}"
      else
        ""
      end

    base <> elevation <> edges <> overlays <> control <> vp <> transport_segments <> objective
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
      version = Map.get(metadata, "version", "1.0")
      name = Map.get(metadata, "name", "Loaded Map")

      # Parse centerpoint from nested structure
      centerpoint_lat = parse_centerpoint_lat(content)
      centerpoint_lng = parse_centerpoint_lng(content)

      map =
        GameMap.new(name, width, height, scale,
          base_elevation: base_elevation,
          version: version,
          centerpoint_lat: centerpoint_lat,
          centerpoint_lng: centerpoint_lng
        )

      map = apply_yaml_tiles(map, tile_lines)

      {:ok, map, name}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp parse_centerpoint_lat(content) do
    case Regex.run(~r/centerpoint:\s*\n\s*lat:\s*([\d.-]+)/m, content) do
      [_, lat] -> parse_float(lat)
      _ -> nil
    end
  end

  defp parse_centerpoint_lng(content) do
    case Regex.run(~r/centerpoint:\s*\n\s*lat:\s*[\d.-]+\s*\n\s*lng:\s*([\d.-]+)/m, content) do
      [_, lng] -> parse_float(lng)
      _ -> nil
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
             |> Map.put(:transport_segments, tile_data.transport_segments)
             |> Map.put(:objective, tile_data.objective)
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
    victory_points_match = Regex.run(~r/victory_points:\s*(\d+)/, joined)

    if coord_match && terrain_match do
      [_, q, r] = coord_match
      [_, terrain] = terrain_match
      elevation = if elevation_match, do: String.to_integer(Enum.at(elevation_match, 1)), else: 0
      victory_points = if victory_points_match, do: String.to_integer(Enum.at(victory_points_match, 1)), else: 0

      # Parse transport segments
      transport_segments = parse_transport_segments(joined)

      # Parse objective
      objective = parse_objective(joined)

      %{
        q: String.to_integer(q),
        r: String.to_integer(r),
        terrain: String.to_existing_atom(terrain),
        elevation: elevation,
        edges: %{},
        overlays: [],
        control: nil,
        victory_points: victory_points,
        transport_segments: transport_segments,
        objective: objective
      }
    else
      nil
    end
  end

  defp parse_transport_segments(yaml_string) do
    # Match the transport_segments section and extract individual segments
    case Regex.run(~r/transport_segments:\s*\n((?:\s+-\s+type:.*\n(?:\s+\w+:.*\n)*)+)/s, yaml_string) do
      [_, segments_block] ->
        # Parse each segment
        segment_pattern = ~r/-\s+type:\s*(\w+)\s*\n\s+entry:\s*\[([^\]]*)\]\s*\n\s+exit:\s*\[([^\]]*)\]/

        Regex.scan(segment_pattern, segments_block)
        |> Enum.map(fn [_, type, entry, exit] ->
          entry_edges = parse_edge_list_yaml(entry)
          exit_edges = parse_edge_list_yaml(exit)

          TransportSegment.new(
            String.to_existing_atom(type),
            entry_edges,
            exit_edges
          )
        end)

      _ ->
        []
    end
  end

  defp parse_edge_list_yaml(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&String.to_integer/1)
  end

  defp parse_objective(yaml_string) do
    # Check if objective section exists
    if String.contains?(yaml_string, "objective:") do
      name_match = Regex.run(~r/objective:.*?name:\s*"([^"]*)"/, yaml_string)
      force_match = Regex.run(~r/objective:.*?force:\s*(\w+)/, yaml_string)

      name = if name_match, do: Enum.at(name_match, 1), else: nil
      force = if force_match, do: String.to_existing_atom(Enum.at(force_match, 1)), else: nil

      if name || force do
        %{name: name, force: force}
      else
        nil
      end
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
  defp tool_label(:transport), do: "Transp"
  defp tool_label(:overlay), do: "Overlay"
  defp tool_label(:objective), do: "Obj"
  defp tool_label(:eraser), do: "Eraser"

  defp terrain_label(terrain) when is_atom(terrain) do
    # Short labels for compact display
    case terrain do
      :clear -> "Clear"
      :forest_pine -> "Pine"
      :forest_deciduous -> "Decid"
      :marsh -> "Marsh"
      :orchard -> "Orchard"
      :light_urban -> "Town"
      :heavy_urban -> "City"
      :industrial -> "Indust"
      :desert -> "Desert"
      :semi_arid -> "S-Arid"
      :tundra -> "Tundra"
      :arctic -> "Arctic"
      :freshwater_lake -> "Lake"
      :frozen_lake -> "FrzLake"
      :ocean -> "Ocean"
      :frozen_ocean -> "FrzOcn"
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
      :marsh -> "bg-green-800 text-white"
      :orchard -> "bg-lime-500 text-white"
      :light_urban -> "bg-gray-400 text-gray-900"
      :heavy_urban -> "bg-gray-600 text-white"
      :industrial -> "bg-neutral-700 text-white"
      :desert -> "bg-yellow-300 text-yellow-900"
      :semi_arid -> "bg-amber-300 text-amber-900"
      :tundra -> "bg-stone-500 text-white"
      :arctic -> "bg-slate-100 text-slate-800"
      :freshwater_lake -> "bg-blue-600 text-white"
      :frozen_lake -> "bg-sky-200 text-sky-900"
      :ocean -> "bg-blue-900 text-white"
      :frozen_ocean -> "bg-sky-300 text-sky-900"
      _ -> "bg-gray-600 text-white"
    end
  end

  defp feature_label(:none), do: "None"
  defp feature_label(:small_stream), do: "Sm Stream"
  defp feature_label(:large_stream), do: "Lg Stream"
  defp feature_label(:small_river), do: "Sm River"
  defp feature_label(:large_river), do: "Lg River"

  defp feature_label(feature) when is_atom(feature) do
    feature
    |> Atom.to_string()
    |> String.capitalize()
  end

  defp feature_label(feature), do: feature

  # SVG mini-hex coordinates for edge tool UI (pointy-top orientation, matching map)
  # For a pointy-top hex in a 100x100 viewBox centered at (50, 50) with radius ~43:
  # Vertices are at angles starting at -30° going clockwise (same as renderer):
  #   Vertex 0: Upper-right (2 o'clock)  = (87, 28.5)
  #   Vertex 1: Lower-right (4 o'clock)  = (87, 71.5)
  #   Vertex 2: Bottom (6 o'clock)       = (50, 93)
  #   Vertex 3: Lower-left (8 o'clock)   = (13, 71.5)
  #   Vertex 4: Upper-left (10 o'clock)  = (13, 28.5)
  #   Vertex 5: Top (12 o'clock)         = (50, 7)
  #
  # Edge numbering: 0=N, 1=NE, 2=SE, 3=S, 4=SW, 5=NW
  # Edge connects vertex pairs: N=[5,0], NE=[0,1], SE=[1,2], S=[2,3], SW=[3,4], NW=[4,5]

  defp hex_points do
    "87,28.5 87,71.5 50,93 13,71.5 13,28.5 50,7"
  end

  defp edge_coords(0), do: {{50, 7}, {87, 28.5}}    # N: vertex 5 to vertex 0 (top to upper-right)
  defp edge_coords(1), do: {{87, 28.5}, {87, 71.5}} # NE: vertex 0 to vertex 1 (upper-right to lower-right)
  defp edge_coords(2), do: {{87, 71.5}, {50, 93}}   # SE: vertex 1 to vertex 2 (lower-right to bottom)
  defp edge_coords(3), do: {{50, 93}, {13, 71.5}}   # S: vertex 2 to vertex 3 (bottom to lower-left)
  defp edge_coords(4), do: {{13, 71.5}, {13, 28.5}} # SW: vertex 3 to vertex 4 (lower-left to upper-left)
  defp edge_coords(5), do: {{13, 28.5}, {50, 7}}    # NW: vertex 4 to vertex 5 (upper-left to top)

  defp edge_color(:none), do: "#4B5563"
  defp edge_color(:small_stream), do: "#87CEEB"
  defp edge_color(:large_stream), do: "#87CEEB"
  defp edge_color(:small_river), do: "#4682B4"
  defp edge_color(:large_river), do: "#4682B4"

  defp edge_stroke_width(:none), do: 2
  defp edge_stroke_width(:small_stream), do: 4
  defp edge_stroke_width(:large_stream), do: 6
  defp edge_stroke_width(:small_river), do: 8
  defp edge_stroke_width(:large_river), do: 10

  defp direction_label(0), do: "N"
  defp direction_label(1), do: "NE"
  defp direction_label(2), do: "SE"
  defp direction_label(3), do: "S"
  defp direction_label(4), do: "SW"
  defp direction_label(5), do: "NW"
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

  defp segment_type_label(type) when is_atom(type) do
    case type do
      :trail -> "Trail"
      :small_unpaved_road -> "Sm Unpaved"
      :large_unpaved_road -> "Lg Unpaved"
      :small_paved_road -> "Sm Paved"
      :large_paved_road -> "Lg Paved"
      :railroad -> "Rail 1"
      :double_track_railroad -> "Rail 2"
      :triple_track_railroad -> "Rail 3"
      :runway -> "Runway"
      _ -> Atom.to_string(type)
    end
  end

  defp segment_type_label(type), do: type

  defp format_segment_edges(segment) do
    entry =
      case segment.entry_edges do
        [] -> ""
        edges -> "in: " <> Enum.map_join(edges, ",", &direction_label/1)
      end

    exit =
      case segment.exit_edges do
        [] -> ""
        edges -> "out: " <> Enum.map_join(edges, ",", &direction_label/1)
      end

    [entry, exit]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" ")
  end

  defp parse_edge_list(""), do: []

  defp parse_edge_list(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
  end

  defp force_label(force) when is_atom(force) do
    case force do
      :allied -> "Allied"
      :axis -> "Axis"
      :soviet -> "Soviet"
      :german -> "German"
      :american -> "US"
      :british -> "UK"
      :french -> "French"
      :japanese -> "Japan"
      :neutral -> "Neutral"
      _ -> force |> Atom.to_string() |> String.capitalize()
    end
  end

  defp force_label(force), do: force
end
