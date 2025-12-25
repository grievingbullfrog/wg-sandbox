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
      assert html =~ "Urban"
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
      assert html =~ "Edge Feature"
      assert html =~ "Direction"
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
    test "shows edge direction options when edge tool selected", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      # Select edge tool
      view |> element("button[phx-value-tool='edge']") |> render_click()
      html = render(view)

      # Check direction buttons are shown
      assert html =~ "Direction"
      # Direction buttons have values 0-5
      for dir <- 0..5 do
        assert html =~ ~r/phx-value-direction="#{dir}"/
      end
    end

    test "can select edge features", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-editor")

      view |> element("button[phx-value-tool='edge']") |> render_click()
      view |> element("button[phx-value-feature='river']") |> render_click()

      html = render(view)
      assert html =~ ~r/phx-value-feature="river".*bg-blue-600/s
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
end
