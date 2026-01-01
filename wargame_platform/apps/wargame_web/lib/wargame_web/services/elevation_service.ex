defmodule WargameWeb.Services.ElevationService do
  @moduledoc """
  Service for fetching elevation data from external APIs.

  Uses Open-Meteo's free Elevation API which provides 90m resolution
  global elevation data based on Copernicus DEM GLO-90.

  API docs: https://open-meteo.com/en/docs/elevation-api
  """

  require Logger

  @open_meteo_url "https://api.open-meteo.com/v1/elevation"

  # Maximum locations per request (Open-Meteo limit)
  @max_locations_per_request 100

  @doc """
  Fetches elevation data for a list of {lat, lng} coordinate pairs.

  Returns a list of elevations in meters (floats), in the same order as input.
  Returns {:error, reason} if the API call fails.

  ## Examples

      iex> ElevationService.fetch_elevations([{50.0, 30.0}, {50.1, 30.1}])
      {:ok, [123.5, 145.2]}
  """
  @spec fetch_elevations(list({float(), float()})) :: {:ok, list(float())} | {:error, term()}
  def fetch_elevations([]), do: {:ok, []}

  def fetch_elevations(coordinates) when is_list(coordinates) do
    # Split into batches to respect API limits
    coordinates
    |> Enum.chunk_every(@max_locations_per_request)
    |> Enum.reduce_while({:ok, []}, fn batch, {:ok, acc} ->
      case fetch_batch(batch) do
        {:ok, elevations} -> {:cont, {:ok, acc ++ elevations}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp fetch_batch(coordinates) do
    latitudes = Enum.map(coordinates, fn {lat, _lng} -> lat end) |> Enum.join(",")
    longitudes = Enum.map(coordinates, fn {_lat, lng} -> lng end) |> Enum.join(",")

    url = "#{@open_meteo_url}?latitude=#{latitudes}&longitude=#{longitudes}"

    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_response(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        Logger.error("Elevation API returned status #{status}: #{inspect(body)}")
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error("Elevation API request failed: #{inspect(reason)}")
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(%{"elevation" => elevations}) when is_list(elevations) do
    {:ok, elevations}
  end

  defp parse_response(body) do
    Logger.error("Unexpected elevation API response format: #{inspect(body)}")
    {:error, :invalid_response}
  end

  @doc """
  Converts a hex coordinate to lat/lng given a map's centerpoint and scale.

  Uses pointy-top hex geometry where:
  - q increases to the right
  - r increases downward

  The centerpoint is assumed to be at the center of the map grid.

  ## Parameters
  - q, r: Axial hex coordinates
  - center_lat, center_lng: Map centerpoint in decimal degrees
  - scale: Meters per hex
  - map_width, map_height: Map dimensions in hexes
  """
  @spec hex_to_latlon(integer(), integer(), float(), float(), pos_integer(), pos_integer(), pos_integer()) ::
          {float(), float()}
  def hex_to_latlon(q, r, center_lat, center_lng, scale, map_width, map_height) do
    # Center of the map in hex coordinates
    center_q = (map_width - 1) / 2
    center_r = (map_height - 1) / 2

    # Offset from center in hex coordinates
    dq = q - center_q
    dr = r - center_r

    # Convert hex offset to meters using pointy-top geometry
    # For pointy-top hexes:
    #   x = scale * sqrt(3) * (q + r/2)
    #   y = scale * 3/2 * r
    hex_width = scale * :math.sqrt(3)
    hex_height = scale * 1.5

    dx_meters = hex_width * (dq + dr / 2)
    dy_meters = hex_height * dr

    # Convert meters to degrees
    # 1 degree of latitude ≈ 111,320 meters
    # 1 degree of longitude ≈ 111,320 * cos(latitude) meters
    meters_per_deg_lat = 111_320
    meters_per_deg_lng = 111_320 * :math.cos(center_lat * :math.pi() / 180)

    lat = center_lat - (dy_meters / meters_per_deg_lat)  # negative because r increases downward
    lng = center_lng + (dx_meters / meters_per_deg_lng)

    {lat, lng}
  end

  @doc """
  Fetches elevation data for all tiles in a map and returns updated tiles.

  Returns {:ok, updated_map} with elevations set on all tiles,
  or {:error, reason} if the API call fails.

  The elevation is stored as relative to the map's base_elevation,
  scaled by the map's scale (meters per hex).
  """
  @spec fetch_map_elevations(WargameCore.Map.t()) ::
          {:ok, WargameCore.Map.t()} | {:error, term()}
  def fetch_map_elevations(%WargameCore.Map{centerpoint_lat: nil}) do
    {:error, :no_centerpoint}
  end

  def fetch_map_elevations(%WargameCore.Map{centerpoint_lng: nil}) do
    {:error, :no_centerpoint}
  end

  def fetch_map_elevations(%WargameCore.Map{} = map) do
    # Generate all hex coordinates with their lat/lng
    coords_with_latlon =
      for q <- 0..(map.width - 1), r <- 0..(map.height - 1) do
        {lat, lng} = hex_to_latlon(q, r, map.centerpoint_lat, map.centerpoint_lng, map.scale, map.width, map.height)
        {{q, r}, {lat, lng}}
      end

    # Extract just the lat/lng pairs for the API call
    latlons = Enum.map(coords_with_latlon, fn {_coord, latlon} -> latlon end)

    case fetch_elevations(latlons) do
      {:ok, elevations} ->
        # Calculate base elevation as the minimum elevation found
        # Round down to nearest 10m for a clean base value
        min_elevation = Enum.min(elevations)
        base_elevation = floor(min_elevation / 10) * 10

        # Zip coordinates with elevations and update tiles
        updates =
          coords_with_latlon
          |> Enum.zip(elevations)
          |> Enum.map(fn {{{q, r}, _latlon}, elevation_meters} ->
            # Convert absolute elevation to relative elevation level
            # Each elevation level represents one "hex height" worth of elevation
            relative_meters = elevation_meters - base_elevation

            # Round to nearest integer for elevation level
            # Using 10 meters per level
            elevation_level = round(relative_meters / 10)

            {{q, r}, elevation_level}
          end)

        # Update map with new base elevation and tile elevations
        updated_map =
          map
          |> Map.put(:base_elevation, round(base_elevation))
          |> apply_elevation_updates(updates)

        {:ok, updated_map}

      {:error, _} = error ->
        error
    end
  end

  defp apply_elevation_updates(map, updates) do
    updated_tiles =
      Enum.reduce(updates, map.tiles, fn {{q, r}, elevation}, tiles ->
        coord = WargameCore.Hex.Coord.new(q, r)

        case Map.get(tiles, coord) do
          nil ->
            tiles

          tile ->
            Map.put(tiles, coord, %{tile | elevation: elevation})
        end
      end)

    %{map | tiles: updated_tiles}
  end
end
