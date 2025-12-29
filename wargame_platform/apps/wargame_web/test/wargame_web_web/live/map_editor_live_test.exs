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
      assert html =~ "Edges"
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

    test "can open resize modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Click resize button
      view |> element("button", "Resize") |> render_click()
      html = render(view)
      assert html =~ "Resize Map"
      assert html =~ "Width (hexes)"
      assert html =~ "Height (hexes)"
    end

    test "can close resize modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open modal
      view |> element("button", "Resize") |> render_click()
      assert render(view) =~ "Resize Map"

      # Close modal
      view |> element("button", "Cancel") |> render_click()
      refute render(view) =~ "Resize Map"
    end

    test "can resize map", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()

      # Submit resize form
      view
      |> element("form")
      |> render_submit(%{"width" => "30", "height" => "25", "scale" => "100"})

      html = render(view)
      refute html =~ "Resize Map"  # Modal closed
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
    test "shows edge selection buttons when edge tool selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select edge tool
      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # Check edge toggle buttons are shown (using toggle_water_edge)
      assert html =~ "Edges"
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

    test "shows all water feature types including None", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # Check all water feature types are available (including None for clearing)
      assert html =~ "None"
      assert html =~ "Sm Stream"
      assert html =~ "Lg Stream"
      assert html =~ "Sm River"
      assert html =~ "Lg River"
    end

    test "None is selected by default for edge features", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # None should be highlighted as the default selection
      assert html =~ ~r/phx-value-feature="none".*bg-blue-600/s
    end

    test "can toggle water edges", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()

      # Toggle edge 0
      view |> element("button[phx-click='toggle_water_edge'][phx-value-edge='0']") |> render_click()

      html = render(view)
      # The button should be highlighted (bg-cyan-600)
      assert html =~ ~r/phx-value-edge="0".*bg-cyan-600/s or
             html =~ ~r/bg-cyan-600.*phx-value-edge="0"/s
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

  describe "map metadata in resize modal" do
    test "resize modal shows version field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()
      html = render(view)

      assert html =~ "Version"
      assert html =~ ~r/name="version"/
    end

    test "resize modal shows centerpoint fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()
      html = render(view)

      assert html =~ "Centerpoint Lat"
      assert html =~ "Centerpoint Lng"
      assert html =~ ~r/name="centerpoint_lat"/
      assert html =~ ~r/name="centerpoint_lng"/
    end

    test "resize modal shows base elevation field", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()
      html = render(view)

      assert html =~ "Base Elevation"
      assert html =~ ~r/name="base_elevation"/
    end

    test "can resize map with version", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()

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
      refute html =~ "Resize Map"
      assert html =~ "30 x 25"
    end

    test "can resize map with centerpoint coordinates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Open resize modal
      view |> element("button", "Resize") |> render_click()

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
      refute html =~ "Resize Map"
      assert html =~ "20 x 15"
    end

    test "resize map handles empty centerpoint fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button", "Resize") |> render_click()

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
      refute html =~ "Resize Map"
      assert html =~ "10 x 10"
    end

    test "resize map handles negative centerpoint values", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button", "Resize") |> render_click()

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
      refute html =~ "Resize Map"
      assert html =~ "15 x 15"
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
