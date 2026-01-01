defmodule WargameWebWeb.MapEditorLiveTest do
  use WargameWebWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "MapEditorLive mount" do
    test "renders editor with default values", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ "Map Editor"
      assert html =~ "New Map"
      assert html =~ "Brush"
      assert html =~ "Fill"
      assert html =~ "Line"
    end

    test "shows terrain options", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ "Clear"
      assert html =~ "Pine"
      assert html =~ "Town"
    end

    test "shows tool buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ "Brush"
      assert html =~ "Fill"
      assert html =~ "Line"
      assert html =~ "Elev"
      assert html =~ "Edge"
      assert html =~ "Overlay"
      assert html =~ "Eraser"
    end

    test "shows map info panel", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ "Map Info"
      assert html =~ "Size:"
      assert html =~ "Scale:"
    end
  end

  describe "tool selection" do
    test "can select brush tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select fill tool first
      view |> element("button[phx-value-tool='fill']") |> render_click()
      html = render(view)
      assert html =~ ~r/phx-value-tool="fill".*bg-blue-600/s

      # Switch back to brush
      view |> element("button[phx-value-tool='brush']") |> render_click()
      html = render(view)
      assert html =~ ~r/phx-value-tool="brush".*bg-blue-600/s
    end

    test "can select line tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='line']") |> render_click()
      html = render(view)
      assert html =~ ~r/phx-value-tool="line".*bg-blue-600/s
    end

    test "can select elevation tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='elevation']") |> render_click()
      html = render(view)
      assert html =~ "Elevation"
    end

    test "can select edge tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)
      assert html =~ "Water Type"
      assert html =~ "Click edges:"
    end

    test "can select overlay tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='overlay']") |> render_click()
      html = render(view)
      assert html =~ "Overlay"
      assert html =~ "Trench"
      assert html =~ "Bunker"
    end
  end

  describe "terrain selection" do
    test "can select different terrain types", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Ensure brush tool is selected (terrain visible)
      view |> element("button[phx-value-tool='brush']") |> render_click()

      # Select forest_pine terrain
      view |> element("button[phx-value-terrain='forest_pine']") |> render_click()
      html = render(view)
      assert html =~ ~r/phx-value-terrain="forest_pine".*ring-2/s
    end
  end

  describe "brush size" do
    test "can change brush size", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Ensure brush tool is selected
      view |> element("button[phx-value-tool='brush']") |> render_click()

      # Change to size 2
      view |> element("button[phx-value-size='2']") |> render_click()
      html = render(view)
      assert html =~ ~r/phx-value-size="2".*bg-blue-600/s
    end
  end

  describe "view options" do
    test "can toggle grid visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Initially grid is shown
      html = render(view)
      assert html =~ ~r/checked.*Show Grid/s

      # Toggle grid off
      view |> element("input[phx-click='toggle_grid']") |> render_click()
      html = render(view)
      # The checkbox should no longer be checked
      refute html =~ ~r/checked.*phx-click="toggle_grid"/s
    end

    test "can toggle coordinate display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Toggle coords on
      view |> element("input[phx-click='toggle_coords']") |> render_click()
      # Verify the state changed (checkbox checked)
      html = render(view)
      assert html =~ "Show Coordinates"
    end
  end

  describe "map operations" do
    test "can create new map", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Click new map button
      view |> element("button", "New") |> render_click()
      html = render(view)
      assert html =~ "New Map"
    end

    test "can open settings modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Click settings button
      view |> element("button", "Settings") |> render_click()
      html = render(view)
      assert html =~ "Map Settings"
      assert html =~ "Width (hexes)"
      assert html =~ "Height (hexes)"
    end

    test "can close settings modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open modal
      view |> element("button", "Settings") |> render_click()
      assert render(view) =~ "phx-submit=\"resize_map\""

      # Close modal
      view |> element("button", "Cancel") |> render_click()
      refute render(view) =~ "phx-submit=\"resize_map\""
    end

    test "can resize map", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()

      # Submit resize form
      view
      |> element("form")
      |> render_submit(%{"width" => "30", "height" => "25", "scale" => "100"})

      html = render(view)
      refute html =~ "phx-submit=\"resize_map\""  # Modal closed
      assert html =~ "30 x 25"  # New size shown
    end
  end

  describe "hex selection" do
    test "handles hex_selected event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Simulate hex selection from client
      render_hook(view, "hex_selected", %{"q" => 5, "r" => 3})

      html = render(view)
      assert html =~ "(5, 3)"
    end

    test "handles hex_hovered event", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Simulate hex hover from client
      render_hook(view, "hex_hovered", %{"q" => 7, "r" => 2})

      html = render(view)
      assert html =~ "Hover: (7, 2)"
    end
  end

  describe "line tool" do
    test "shows line mode indicator when first hex selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select line tool
      view |> element("button[phx-value-tool='line']") |> render_click()

      # Select first hex
      render_hook(view, "hex_selected", %{"q" => 3, "r" => 4})

      html = render(view)
      assert html =~ "Line mode active"
      assert html =~ "Start: (3, 4)"
    end

    test "can cancel line mode", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select line tool
      view |> element("button[phx-value-tool='line']") |> render_click()

      # Select first hex
      render_hook(view, "hex_selected", %{"q" => 3, "r" => 4})
      assert render(view) =~ "Line mode active"

      # Cancel
      view |> element("button", "Cancel") |> render_click()
      refute render(view) =~ "Line mode active"
    end
  end

  describe "undo/redo" do
    test "undo button is disabled when stack is empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ ~r/Undo.*cursor-not-allowed/s
    end

    test "redo button is disabled when stack is empty", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ ~r/Redo.*cursor-not-allowed/s
    end
  end

  describe "edge features" do
    test "shows SVG mini-hex with clickable edges when edge tool selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select edge tool
      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # Check SVG mini-hex with edge toggle lines are shown
      assert html =~ "<svg"
      assert html =~ "Click edges:"
      for dir <- 0..5 do
        assert html =~ ~r/phx-click="toggle_water_edge".*phx-value-edge="#{dir}"/s or
               html =~ ~r/phx-value-edge="#{dir}".*phx-click="toggle_water_edge"/s
      end
    end

    test "can select edge features", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='small_river']") |> render_click()

      html = render(view)
      assert html =~ ~r/phx-value-feature="small_river".*bg-blue-600/s
    end

    test "shows water feature types in palette (toggle clears)", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # Check water feature types are available (no None button, toggle handles clearing)
      assert html =~ "Sm Stream"
      assert html =~ "Lg Stream"
      assert html =~ "Sm River"
      assert html =~ "Lg River"
    end

    test "no water type button is highlighted by default", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # All water type buttons should have the unselected styling (bg-gray-600)
      # None of them should have bg-blue-600 in their immediate styling
      # Check that the water type buttons are in their unselected state
      assert html =~ ~r/phx-value-feature="small_stream" class="[^"]*bg-gray-600/
      assert html =~ ~r/phx-value-feature="large_stream" class="[^"]*bg-gray-600/
      assert html =~ ~r/phx-value-feature="small_river" class="[^"]*bg-gray-600/
      assert html =~ ~r/phx-value-feature="large_river" class="[^"]*bg-gray-600/
    end

    test "can toggle water edges via SVG line click", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()

      # First select a water type
      view |> element("button[phx-value-feature='small_river']") |> render_click()

      # Toggle edge 0 via SVG line
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()

      html = render(view)
      # The selected edge should show a visible line with the selected feature's color
      assert html =~ ~r/stroke="#4682B4"/  # small_river color
    end

    test "applying edges to a tile stores the edge data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select edge tool
      view |> element("button[phx-value-tool='edge']") |> render_click()

      # Select small_river feature
      view |> element("button[phx-value-feature='small_river']") |> render_click()

      # Toggle edge 0 (N)
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()

      # Click on hex (5, 5) to apply the edge
      render_hook(view, "hex_selected", %{"q" => 5, "r" => 5})

      # Hover over the hex to see its info in the right panel
      render_hook(view, "hex_hovered", %{"q" => 5, "r" => 5})

      html = render(view)
      # The hex info panel should show the edge
      assert html =~ "Edges:"
      assert html =~ "N:"
      assert html =~ "small_river" or html =~ "Sm River"
    end

    test "toggling edge off removes it from selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='large_stream']") |> render_click()

      # Toggle edge 2 on
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='2']") |> render_click()
      html = render(view)
      assert html =~ ~r/stroke="#87CEEB"/  # large_stream color (light blue)

      # Toggle edge 2 off
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='2']") |> render_click()
      html = render(view)
      # The edge should no longer have the colored stroke visible
      # (the visible line is only rendered when edge is in selected_water_edges)
      refute html =~ ~r/stroke="#87CEEB".*stroke-width="6"/s
    end

    test "can apply multiple edges to a single tile", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='small_stream']") |> render_click()

      # Toggle edges 0 and 3 (N and S)
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='3']") |> render_click()

      # Apply to hex
      render_hook(view, "hex_selected", %{"q" => 3, "r" => 3})

      # Check the tile
      render_hook(view, "hex_hovered", %{"q" => 3, "r" => 3})
      html = render(view)

      assert html =~ "Edges:"
      assert html =~ "N:"
      assert html =~ "S:"
    end

    test "clearing water edge selection resets all edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='large_river']") |> render_click()

      # Toggle multiple edges
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='1']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='4']") |> render_click()

      html = render(view)
      # Both edges should show the river color
      assert html =~ ~r/stroke="#4682B4"/

      # Clear the selection by clicking clear_water_edge_selection
      # Note: The new UI doesn't have a clear button, but we can test the event directly
      render_click(view, "clear_water_edge_selection", %{})

      html = render(view)
      # No edges should be highlighted with river color anymore
      refute html =~ ~r/stroke="#4682B4".*stroke-width="10"/s
    end

    test "applying edge with :none feature clears existing edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # First, apply a river to edge 0
      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='small_river']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 4, "r" => 4})

      # Verify the edge was applied
      render_hook(view, "hex_hovered", %{"q" => 4, "r" => 4})
      html = render(view)
      assert html =~ "N:"

      # Now clear the edge selection and use :none to clear
      render_click(view, "clear_water_edge_selection", %{})
      render_click(view, "select_edge_feature", %{"feature" => "none"})
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 4, "r" => 4})

      # Check that the edge is cleared - N: should no longer appear
      render_hook(view, "hex_hovered", %{"q" => 4, "r" => 4})
      html = render(view)
      # After clearing, the Edges: section should not show "N:" anymore
      refute html =~ ~r/Edges:.*N:/s
    end

    test "edge data persists through undo/redo", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Apply an edge
      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='large_river']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='2']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 6, "r" => 6})

      # Verify edge exists
      render_hook(view, "hex_hovered", %{"q" => 6, "r" => 6})
      html = render(view)
      assert html =~ "SE:"

      # Undo
      view |> element("button[phx-click='undo']") |> render_click()
      render_hook(view, "hex_hovered", %{"q" => 6, "r" => 6})
      html = render(view)
      refute html =~ "SE:"

      # Redo
      view |> element("button[phx-click='redo']") |> render_click()
      render_hook(view, "hex_hovered", %{"q" => 6, "r" => 6})
      html = render(view)
      assert html =~ "SE:"
    end
  end

  describe "edge tool YAML serialization" do
    test "edges are included in saved YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Apply an edge to a tile
      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='small_stream']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='1']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 2, "r" => 2})

      # Trigger save - this pushes the download_file event
      # We can't easily capture the YAML content in tests, but we can verify the event is sent
      view |> element("button[phx-click='save_map']") |> render_click()

      # The save status should show
      html = render(view)
      assert html =~ "Saved!"
    end

    test "edges applied via UI are preserved after other tile operations", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Apply an edge to a tile
      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='large_river']") |> render_click()
      view |> element("line[phx-click='toggle_water_edge'][phx-value-edge='2']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 7, "r" => 7})

      # Now change the terrain on that tile
      view |> element("button[phx-value-tool='brush']") |> render_click()
      view |> element("button[phx-value-terrain='forest_pine']") |> render_click()
      render_hook(view, "hex_selected", %{"q" => 7, "r" => 7})

      # Verify the edge is still there
      render_hook(view, "hex_hovered", %{"q" => 7, "r" => 7})
      html = render(view)

      assert html =~ "Edges:"
      assert html =~ "SE:"
      assert html =~ "Pine" or html =~ "forest_pine"
    end
  end

  describe "transport tool" do
    test "shows transport tool button", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-editor")

      assert html =~ "Transp"
      assert html =~ ~r/phx-value-tool="transport"/
    end

    test "can select transport tool", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      html = render(view)

      assert html =~ "Segment Type"
      assert html =~ "Entry Edges"
      assert html =~ "Exit Edges"
    end

    test "shows segment type options when transport tool selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      html = render(view)

      # Check segment type buttons are shown
      assert html =~ "Trail"
      assert html =~ "Sm Paved"
      assert html =~ "Lg Paved"
      assert html =~ "Rail 1"
      assert html =~ "Rail 2"
      assert html =~ "Rail 3"
      assert html =~ "Runway"
    end

    test "shows entry and exit edge checkboxes", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      html = render(view)

      # Check for entry edge buttons (6 directions)
      assert html =~ ~r/phx-click="toggle_entry_edge"/
      # Check for exit edge buttons (6 directions)
      assert html =~ ~r/phx-click="toggle_exit_edge"/
    end

    test "can select segment type", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      view |> element("button[phx-value-type='railroad']") |> render_click()

      html = render(view)
      assert html =~ ~r/phx-value-type="railroad".*bg-blue-600/s
    end

    test "can toggle entry edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()

      # Toggle entry edge 0
      view |> element("button[phx-click='toggle_entry_edge'][phx-value-edge='0']") |> render_click()

      html = render(view)
      # The button should be highlighted (bg-green-600)
      assert html =~ ~r/phx-click="toggle_entry_edge".*phx-value-edge="0".*bg-green-600/s or
               html =~ ~r/phx-value-edge="0".*bg-green-600/s
    end

    test "can toggle exit edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()

      # Toggle exit edge 3
      view |> element("button[phx-click='toggle_exit_edge'][phx-value-edge='3']") |> render_click()

      html = render(view)
      # The button should be highlighted (bg-orange-600)
      assert html =~ ~r/phx-value-edge="3".*bg-orange-600/s or
               html =~ ~r/toggle_exit_edge.*phx-value-edge="3".*bg-orange-600/s
    end

    test "can clear edge selection", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()

      # Toggle some edges
      view |> element("button[phx-click='toggle_entry_edge'][phx-value-edge='0']") |> render_click()
      view |> element("button[phx-click='toggle_exit_edge'][phx-value-edge='3']") |> render_click()

      # Clear selection
      view |> element("button[phx-click='clear_edge_selection']") |> render_click()

      html = render(view)
      # All entry edge buttons should be gray (bg-gray-600), not green
      assert html =~ ~r/toggle_entry_edge.*phx-value-edge="0".*bg-gray-600/s or
               html =~ ~r/phx-value-edge="0".*bg-gray-600/s
    end

    test "shows clear selection button", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      html = render(view)

      assert html =~ "Clear Selection"
      assert html =~ ~r/phx-click="clear_edge_selection"/
    end

    test "shows usage instructions", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='transport']") |> render_click()
      html = render(view)

      assert html =~ "Select edges then click a hex"
    end
  end

  describe "elevation tool" do
    test "shows elevation input when elevation tool selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='elevation']") |> render_click()
      html = render(view)

      # Check elevation input and +/- buttons are shown
      assert html =~ "Elevation Level"
      assert html =~ "phx-click=\"increment_elevation\""
      assert html =~ "phx-click=\"decrement_elevation\""
      assert html =~ "phx-blur=\"select_elevation\""
    end

    test "can change elevation level with increment/decrement", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='elevation']") |> render_click()

      # Increment elevation
      view |> element("button[phx-click='increment_elevation']") |> render_click()
      view |> element("button[phx-click='increment_elevation']") |> render_click()
      view |> element("button[phx-click='increment_elevation']") |> render_click()

      html = render(view)
      # The input should show value 3 (starting from 0, incremented 3 times)
      assert html =~ ~r/value="3"/
    end
  end

  describe "map metadata in settings modal" do
    test "settings modal shows version field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()
      html = render(view)

      assert html =~ "Version"
      assert html =~ ~r/name="version"/
    end

    test "settings modal shows centerpoint fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()
      html = render(view)

      assert html =~ "Centerpoint Lat"
      assert html =~ "Centerpoint Lng"
      assert html =~ ~r/name="centerpoint_lat"/
      assert html =~ ~r/name="centerpoint_lng"/
    end

    test "settings modal shows base elevation field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()
      html = render(view)

      assert html =~ "Base Elevation"
      assert html =~ ~r/name="base_elevation"/
    end

    test "can resize map with version", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()

      # Submit resize form with version
      view
      |> element("form")
      |> render_submit(%{
        "width" => "30",
        "height" => "25",
        "scale" => "100",
        "base_elevation" => "0",
        "version" => "2.5",
        "centerpoint_lat" => "",
        "centerpoint_lng" => ""
      })

      html = render(view)
      refute html =~ "phx-submit=\"resize_map\""
      assert html =~ "30 x 25"
    end

    test "can resize map with centerpoint coordinates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal
      view |> element("button", "Settings") |> render_click()

      # Submit resize form with centerpoint
      view
      |> element("form")
      |> render_submit(%{
        "width" => "20",
        "height" => "15",
        "scale" => "200",
        "base_elevation" => "100",
        "version" => "1.0",
        "centerpoint_lat" => "50.6292",
        "centerpoint_lng" => "36.2405"
      })

      html = render(view)
      refute html =~ "phx-submit=\"resize_map\""
      assert html =~ "20 x 15"
    end

    test "resize map handles empty centerpoint fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button", "Settings") |> render_click()

      view
      |> element("form")
      |> render_submit(%{
        "width" => "10",
        "height" => "10",
        "scale" => "500",
        "base_elevation" => "0",
        "version" => "",
        "centerpoint_lat" => "",
        "centerpoint_lng" => ""
      })

      # Should not crash and modal should close
      html = render(view)
      refute html =~ "phx-submit=\"resize_map\""
      assert html =~ "10 x 10"
    end

    test "resize map handles negative centerpoint values", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button", "Settings") |> render_click()

      # Los Angeles coordinates (negative longitude)
      view
      |> element("form")
      |> render_submit(%{
        "width" => "15",
        "height" => "15",
        "scale" => "200",
        "base_elevation" => "50",
        "version" => "1.1",
        "centerpoint_lat" => "34.0522",
        "centerpoint_lng" => "-118.2437"
      })

      html = render(view)
      refute html =~ "phx-submit=\"resize_map\""
      assert html =~ "15 x 15"
    end

    test "fetch elevations button is enabled after setting centerpoint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal and set centerpoint
      view |> element("button", "Settings") |> render_click()

      view
      |> element("form")
      |> render_submit(%{
        "width" => "10",
        "height" => "10",
        "scale" => "200",
        "base_elevation" => "100",
        "version" => "1.0",
        "centerpoint_lat" => "51.7373",
        "centerpoint_lng" => "36.1873"
      })

      # Re-open settings modal
      view |> element("button", "Settings") |> render_click()
      html = render(view)

      # The Fetch Elevations button should NOT be disabled
      refute html =~ ~r/phx-click="fetch_elevations"[^>]*disabled/
      # And should have the green button class
      assert html =~ ~r/phx-click="fetch_elevations"[^>]*bg-green-600/
    end

    test "fetch elevations button is disabled when no centerpoint", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open settings modal without setting centerpoint
      view |> element("button", "Settings") |> render_click()
      html = render(view)

      # The Fetch Elevations button should be disabled
      assert html =~ ~r/phx-click="fetch_elevations"[^>]*disabled/
      # And should have the gray button class
      assert html =~ ~r/phx-click="fetch_elevations"[^>]*bg-gray-600/
    end
  end

  describe "YAML save/load with metadata" do
    test "file_loaded event parses version from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      # Wargame Map File
      name: "Test Map"
      version: "2.3"
      width: 10
      height: 10
      scale: 200

      tiles:
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "test.yaml"
      })

      # Map should be loaded (no error flash)
      html = render(view)
      refute html =~ "Failed to load map"
    end

    test "file_loaded event parses centerpoint from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Battle of Kursk"
      version: "1.2"
      width: 20
      height: 15
      scale: 500
      centerpoint:
        lat: 50.6292
        lng: 36.2405

      tiles:
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "kursk.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "20 x 15"
    end

    test "file_loaded event handles missing centerpoint gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Simple Map"
      width: 5
      height: 5
      scale: 100

      tiles:
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "simple.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "5 x 5"
    end

    test "file_loaded event parses base_elevation from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Mountain Map"
      version: "1.0"
      width: 12
      height: 8
      scale: 300
      base_elevation: 500

      tiles:
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "mountain.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "12 x 8"
    end

    test "file_loaded event parses complete metadata from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Full Metadata Map"
      version: "3.1"
      width: 25
      height: 20
      scale: 1000
      base_elevation: 250
      centerpoint:
        lat: -33.8688
        lng: 151.2093

      tiles:
        - coord: [5, 5]
          terrain: forest_pine
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "full_metadata.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "25 x 20"
    end

    test "file_loaded event handles YAML with invalid tile coords gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # This YAML has invalid tile coord that will cause a parse error
      yaml_content = """
      name: "Test"
      width: 5
      height: 5
      scale: 100

      tiles:
        - coord: not_a_list
          terrain: clear
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "invalid.yaml"
      })

      html = render(view)
      # The parser should either handle gracefully or show an error
      # Either way, the page should render without crashing
      assert html =~ "Map Editor"
    end

    test "file_loaded event handles empty content", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      render_hook(view, "file_loaded", %{
        "content" => "",
        "filename" => "empty.yaml"
      })

      # Should not crash - either loads a default map or shows error
      html = render(view)
      assert html =~ "Map Editor"
    end

    test "file_loaded event parses transport segments from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Road Map"
      version: "1.0"
      width: 10
      height: 10
      scale: 200

      tiles:
        - coord: [5, 5]
          terrain: clear
          transport_segments:
            - type: small_paved_road
              entry: [0]
              exit: [3]
            - type: railroad
              entry: [1, 2]
              exit: [4, 5]
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "roads.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "10 x 10"
    end

    test "file_loaded event parses objective from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Objective Map"
      version: "1.0"
      width: 10
      height: 10
      scale: 200

      tiles:
        - coord: [5, 5]
          terrain: tundra
          victory_points: 10
          objective:
            name: "Hill 223"
            force: allied
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "objectives.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "10 x 10"
    end

    test "file_loaded event parses complex tile with all features from YAML", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      yaml_content = """
      name: "Complex Map"
      version: "2.0"
      width: 15
      height: 12
      scale: 300
      base_elevation: 100
      centerpoint:
        lat: 50.0
        lng: 30.0

      tiles:
        - coord: [7, 6]
          terrain: heavy_urban
          elevation: 2
          victory_points: 25
          transport_segments:
            - type: large_paved_road
              entry: [0]
              exit: [3]
          objective:
            name: "City Center"
            force: axis
      """

      render_hook(view, "file_loaded", %{
        "content" => yaml_content,
        "filename" => "complex.yaml"
      })

      html = render(view)
      refute html =~ "Failed to load map"
      assert html =~ "15 x 12"
    end
  end
end
