defmodule WargameWebWeb.PageControllerTest do
  use WargameWebWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Wargame Platform"
  end
end
