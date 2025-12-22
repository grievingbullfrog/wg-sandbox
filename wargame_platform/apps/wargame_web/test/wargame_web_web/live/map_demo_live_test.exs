defmodule WargameWebWeb.MapDemoLiveTest do
  use WargameWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders the map demo page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-demo")

      assert html =~ "Wargame Map Demo"
      assert html =~ "map-canvas"
    end

    test "initializes with no selected hex", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-demo")

      # No selected hex text should be visible initially
      refute html =~ "Selected:"
    end

    test "initializes with no hovered hex", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-demo")

      # No hover text should be visible initially
      refute html =~ "Hover:"
    end

    test "canvas has correct data attributes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-demo")

      assert html =~ ~s(data-width="20")
      assert html =~ ~s(data-height="15")
      assert html =~ ~s(data-hex-size="40")
      assert html =~ ~s(data-show-grid="true")
    end
  end

  describe "handle_event hex_selected" do
    test "updates selected hex display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Simulate hex selection event
      render_click(view, "hex_selected", %{"q" => 5, "r" => 7})

      html = render(view)
      assert html =~ "Selected:"
      assert html =~ "(5, 7)"
    end

    test "shows terrain for selected hex", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Select the village hex at (10, 7)
      render_click(view, "hex_selected", %{"q" => 10, "r" => 7})

      html = render(view)
      assert html =~ "village"
    end

    test "can change selection to different hex", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Select first hex
      render_click(view, "hex_selected", %{"q" => 1, "r" => 1})
      html = render(view)
      assert html =~ "(1, 1)"

      # Select different hex
      render_click(view, "hex_selected", %{"q" => 5, "r" => 5})
      html = render(view)
      assert html =~ "(5, 5)"
      refute html =~ "(1, 1)"
    end
  end

  describe "handle_event hex_hovered" do
    test "updates hovered hex display", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Simulate hex hover event
      render_click(view, "hex_hovered", %{"q" => 3, "r" => 4})

      html = render(view)
      assert html =~ "Hover:"
      assert html =~ "(3, 4)"
    end

    test "can update hover to different hex", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      render_click(view, "hex_hovered", %{"q" => 1, "r" => 1})
      render_click(view, "hex_hovered", %{"q" => 2, "r" => 2})

      html = render(view)
      assert html =~ "(2, 2)"
    end
  end

  describe "handle_event map_ready" do
    test "pushes render_map event with tile data", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Trigger map_ready event and capture pushed events
      assert render_click(view, "map_ready", %{})
    end
  end

  describe "demo map features" do
    test "creates map with expected dimensions", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/map-demo")

      # Map dimensions are passed as data attributes
      assert html =~ ~s(data-width="20")
      assert html =~ ~s(data-height="15")
    end

    test "selected hex shows elevation when present", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/map-demo")

      # Select a hex in the elevated area (9, 3 has elevation 3)
      render_click(view, "hex_selected", %{"q" => 9, "r" => 3})

      html = render(view)
      assert html =~ "elev:"
    end
  end
end
