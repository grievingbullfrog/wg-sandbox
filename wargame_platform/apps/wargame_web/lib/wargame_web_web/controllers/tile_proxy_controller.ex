defmodule WargameWebWeb.TileProxyController do
  @moduledoc """
  Proxies map tile requests to avoid CORS issues when loading tiles in the browser.

  This controller fetches tiles from OpenStreetMap and returns them with appropriate
  headers to allow the browser to use them in canvas/WebGL contexts.
  """

  use WargameWebWeb, :controller

  require Logger

  @osm_tile_url "https://tile.openstreetmap.org"
  @user_agent "WargameMapEditor/1.0 (https://github.com/example/wargame)"

  @doc """
  Proxies a tile request to OpenStreetMap.

  Expects path parameter in the form ["z", "x", "y.png"] from wildcard route.
  """
  def proxy(conn, %{"path" => path}) do
    # Path comes as ["z", "x", "y.png"] from the wildcard route
    [z, x, y_png] = path
    # Remove .png extension if present
    y = String.replace_suffix(y_png, ".png", "")
    url = "#{@osm_tile_url}/#{z}/#{x}/#{y}.png"

    case Req.get(url,
           headers: [{"user-agent", @user_agent}],
           receive_timeout: 10_000
         ) do
      {:ok, %Req.Response{status: 200, body: body, headers: headers}} ->
        # Req returns headers as a map with list values
        content_type =
          case Map.get(headers, "content-type") do
            [ct | _] -> ct
            ct when is_binary(ct) -> ct
            _ -> "image/png"
          end

        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_resp(200, body)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("Tile proxy got status #{status} for #{url}")

        conn
        |> send_resp(status, "")

      {:error, reason} ->
        Logger.error("Tile proxy failed for #{url}: #{inspect(reason)}")

        conn
        |> send_resp(502, "Failed to fetch tile")
    end
  end
end
