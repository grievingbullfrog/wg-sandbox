defmodule WargameWeb.Services.SatelliteImageService do
  @moduledoc """
  Service for fetching satellite imagery based on map coordinates.

  Uses static map APIs to fetch satellite images that can be overlaid
  on the hex map editor. The primary use case is to help map authors
  design maps based on real-world terrain.

  ## Supported Providers

  - `:maptiler` - MapTiler Static Maps API (requires API key)
  - `:openstreetmap` - OpenStreetMap tiles (free, no key required)

  ## Configuration

  Set the API key in your config:

      config :wargame_web, WargameWeb.Services.SatelliteImageService,
        maptiler_api_key: "your_api_key"

  Or set the environment variable `MAPTILER_API_KEY`.
  """

  require Logger

  @default_provider :openstreetmap
  @maptiler_url "https://api.maptiler.com/maps/satellite/static"
  # Use local proxy to bypass CORS restrictions
  @tile_proxy_url "/api/tiles"

  @doc """
  Fetches satellite image URL for a map based on centerpoint and dimensions.

  ## Parameters

  - `centerpoint_lat` - Latitude of map center
  - `centerpoint_lng` - Longitude of map center
  - `scale` - Meters per hex
  - `width_hexes` - Map width in hexes
  - `height_hexes` - Map height in hexes
  - `opts` - Options:
    - `:provider` - Which satellite provider to use (default: `:openstreetmap`)
    - `:image_width` - Desired image width in pixels (default: 1024)
    - `:image_height` - Desired image height in pixels (default: 768)

  ## Returns

  - `{:ok, image_url}` - URL to the satellite image
  - `{:error, reason}` - If the request fails
  """
  @spec get_satellite_image_url(float(), float(), pos_integer(), pos_integer(), pos_integer(), keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def get_satellite_image_url(centerpoint_lat, centerpoint_lng, scale, width_hexes, height_hexes, opts \\ []) do
    provider = Keyword.get(opts, :provider, @default_provider)
    image_width = Keyword.get(opts, :image_width, 1024)
    image_height = Keyword.get(opts, :image_height, 768)

    # Calculate the map extent in meters
    # For pointy-top hexes:
    #   hex_width = scale * sqrt(3)
    #   hex_height = scale * 1.5
    hex_width = scale * :math.sqrt(3)
    hex_height = scale * 1.5

    map_width_meters = hex_width * width_hexes
    map_height_meters = hex_height * height_hexes

    # Calculate appropriate zoom level based on map extent
    zoom = calculate_zoom_level(map_width_meters, map_height_meters, centerpoint_lat, image_width, image_height)

    case provider do
      :maptiler ->
        get_maptiler_url(centerpoint_lat, centerpoint_lng, zoom, image_width, image_height)

      :openstreetmap ->
        # For OSM, we return tile URLs that the frontend will stitch together
        {:ok, get_osm_tile_urls(centerpoint_lat, centerpoint_lng, zoom, image_width, image_height)}

      _ ->
        {:error, {:unsupported_provider, provider}}
    end
  end

  @doc """
  Calculates the bounding box for the map in lat/lng coordinates.

  Returns `{min_lat, min_lng, max_lat, max_lng}`.
  """
  @spec calculate_bounds(float(), float(), pos_integer(), pos_integer(), pos_integer()) ::
          {float(), float(), float(), float()}
  def calculate_bounds(centerpoint_lat, centerpoint_lng, scale, width_hexes, height_hexes) do
    hex_width = scale * :math.sqrt(3)
    hex_height = scale * 1.5

    map_width_meters = hex_width * width_hexes
    map_height_meters = hex_height * height_hexes

    # Convert meters to degrees
    meters_per_deg_lat = 111_320
    meters_per_deg_lng = 111_320 * :math.cos(centerpoint_lat * :math.pi() / 180)

    lat_offset = map_height_meters / 2 / meters_per_deg_lat
    lng_offset = map_width_meters / 2 / meters_per_deg_lng

    min_lat = centerpoint_lat - lat_offset
    max_lat = centerpoint_lat + lat_offset
    min_lng = centerpoint_lng - lng_offset
    max_lng = centerpoint_lng + lng_offset

    {min_lat, min_lng, max_lat, max_lng}
  end

  @doc """
  Returns satellite tile data for the frontend to fetch and display.

  This returns a structure that the frontend can use to fetch tiles
  and position them correctly under the hex map.
  """
  @spec get_satellite_tiles(float(), float(), pos_integer(), pos_integer(), pos_integer(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def get_satellite_tiles(centerpoint_lat, centerpoint_lng, scale, width_hexes, height_hexes, opts \\ []) do
    image_width = Keyword.get(opts, :image_width, 1024)
    image_height = Keyword.get(opts, :image_height, 768)

    # Calculate map extent
    hex_width = scale * :math.sqrt(3)
    hex_height = scale * 1.5
    map_width_meters = hex_width * width_hexes
    map_height_meters = hex_height * height_hexes

    # Calculate zoom level
    zoom = calculate_zoom_level(map_width_meters, map_height_meters, centerpoint_lat, image_width, image_height)

    # Calculate bounds
    {min_lat, min_lng, max_lat, max_lng} =
      calculate_bounds(centerpoint_lat, centerpoint_lng, scale, width_hexes, height_hexes)

    # Calculate tile coordinates
    {min_tile_x, min_tile_y} = lat_lng_to_tile(max_lat, min_lng, zoom)
    {max_tile_x, max_tile_y} = lat_lng_to_tile(min_lat, max_lng, zoom)

    tiles =
      for tile_x <- min_tile_x..max_tile_x,
          tile_y <- min_tile_y..max_tile_y do
        # Use proxy URL to bypass CORS restrictions
        # .png extension helps PixiJS identify content type
        tile_url = "#{@tile_proxy_url}/#{zoom}/#{tile_x}/#{tile_y}.png"
        {tile_lat, tile_lng} = tile_to_lat_lng(tile_x, tile_y, zoom)
        {next_lat, next_lng} = tile_to_lat_lng(tile_x + 1, tile_y + 1, zoom)

        %{
          url: tile_url,
          x: tile_x,
          y: tile_y,
          north: tile_lat,
          south: next_lat,
          west: tile_lng,
          east: next_lng
        }
      end

    {:ok,
     %{
       zoom: zoom,
       tiles: tiles,
       bounds: %{
         north: max_lat,
         south: min_lat,
         west: min_lng,
         east: max_lng
       },
       center: %{
         lat: centerpoint_lat,
         lng: centerpoint_lng
       },
       map_extent_meters: %{
         width: map_width_meters,
         height: map_height_meters
       }
     }}
  end

  # Private functions

  defp get_maptiler_url(lat, lng, zoom, width, height) do
    api_key = get_maptiler_api_key()

    if api_key do
      # MapTiler static map URL format:
      # https://api.maptiler.com/maps/{mapId}/static/{lng},{lat},{zoom}/{width}x{height}.{format}?key={key}
      url = "#{@maptiler_url}/#{lng},#{lat},#{zoom}/#{width}x#{height}.png?key=#{api_key}"
      {:ok, url}
    else
      {:error, :no_api_key}
    end
  end

  defp get_osm_tile_urls(lat, lng, zoom, _width, _height) do
    # Calculate the tile coordinates for the center point
    {tile_x, tile_y} = lat_lng_to_tile(lat, lng, zoom)

    # Return the center tile URL via proxy - frontend will handle fetching multiple tiles
    # .png extension helps PixiJS identify content type
    "#{@tile_proxy_url}/#{zoom}/#{tile_x}/#{tile_y}.png"
  end

  defp get_maptiler_api_key do
    Application.get_env(:wargame_web, __MODULE__, [])
    |> Keyword.get(:maptiler_api_key)
    |> case do
      nil -> System.get_env("MAPTILER_API_KEY")
      key -> key
    end
  end

  # Calculate appropriate zoom level based on map extent
  defp calculate_zoom_level(width_meters, height_meters, lat, image_width, image_height) do
    # Meters per pixel at zoom level 0 at the equator
    meters_per_pixel_at_zoom_0 = 156_543.03392

    # Adjust for latitude
    lat_rad = lat * :math.pi() / 180
    meters_per_pixel_at_zoom_0_lat = meters_per_pixel_at_zoom_0 * :math.cos(lat_rad)

    # Calculate zoom for width and height
    zoom_for_width = :math.log2(image_width * meters_per_pixel_at_zoom_0_lat / width_meters)
    zoom_for_height = :math.log2(image_height * meters_per_pixel_at_zoom_0_lat / height_meters)

    # Use the smaller zoom to fit both dimensions
    zoom = min(zoom_for_width, zoom_for_height)

    # Clamp to valid zoom range (0-19)
    max(0, min(19, round(zoom)))
  end

  # Convert lat/lng to tile coordinates
  defp lat_lng_to_tile(lat, lng, zoom) do
    n = :math.pow(2, zoom)
    lat_rad = lat * :math.pi() / 180

    x = floor((lng + 180) / 360 * n)
    y = floor((1 - :math.log(:math.tan(lat_rad) + 1 / :math.cos(lat_rad)) / :math.pi()) / 2 * n)

    {x, y}
  end

  # Convert tile coordinates to lat/lng (northwest corner of tile)
  defp tile_to_lat_lng(x, y, zoom) do
    n = :math.pow(2, zoom)
    lng = x / n * 360 - 180
    lat_rad = :math.atan(:math.sinh(:math.pi() * (1 - 2 * y / n)))
    lat = lat_rad * 180 / :math.pi()

    {lat, lng}
  end
end
