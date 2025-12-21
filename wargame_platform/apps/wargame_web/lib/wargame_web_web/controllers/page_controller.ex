defmodule WargameWebWeb.PageController do
  use WargameWebWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
