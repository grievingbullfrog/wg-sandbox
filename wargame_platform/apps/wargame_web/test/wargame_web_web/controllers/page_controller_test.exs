defmodule WargameWebWeb.HomeLiveTest do
  use WargameWebWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "GET / renders the landing page", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Wargame Platform"
  end
end
