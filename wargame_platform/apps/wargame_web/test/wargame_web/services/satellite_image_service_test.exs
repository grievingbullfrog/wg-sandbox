defmodule WargameWeb.Services.SatelliteImageServiceTest do
  use ExUnit.Case, async: true

  alias WargameWeb.Services.SatelliteImageService

  describe "calculate_bounds/5" do
    test "calculates correct bounds for a small map" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 1000  # 1km per hex
      width = 10
      height = 10

      {min_lat, min_lng, max_lat, max_lng} =
        SatelliteImageService.calculate_bounds(center_lat, center_lng, scale, width, height)

      # Check that bounds are symmetric around center
      lat_range = max_lat - min_lat
      lng_range = max_lng - min_lng

      assert_in_delta center_lat, (max_lat + min_lat) / 2, 0.0001
      assert_in_delta center_lng, (max_lng + min_lng) / 2, 0.0001

      # Check that the ranges are reasonable
      assert lat_range > 0
      assert lng_range > 0
    end

    test "larger scale produces larger bounds" do
      center_lat = 50.0
      center_lng = 30.0
      width = 10
      height = 10

      {min_lat1, min_lng1, max_lat1, max_lng1} =
        SatelliteImageService.calculate_bounds(center_lat, center_lng, 100, width, height)

      {min_lat2, min_lng2, max_lat2, max_lng2} =
        SatelliteImageService.calculate_bounds(center_lat, center_lng, 1000, width, height)

      # Larger scale should give larger bounds
      assert (max_lat2 - min_lat2) > (max_lat1 - min_lat1)
      assert (max_lng2 - min_lng2) > (max_lng1 - min_lng1)
    end

    test "larger map dimensions produce larger bounds" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500

      {min_lat1, min_lng1, max_lat1, max_lng1} =
        SatelliteImageService.calculate_bounds(center_lat, center_lng, scale, 10, 10)

      {min_lat2, min_lng2, max_lat2, max_lng2} =
        SatelliteImageService.calculate_bounds(center_lat, center_lng, scale, 20, 20)

      # Larger map should give larger bounds
      assert (max_lat2 - min_lat2) > (max_lat1 - min_lat1)
      assert (max_lng2 - min_lng2) > (max_lng1 - min_lng1)
    end
  end

  describe "get_satellite_tiles/6" do
    test "returns tile data for a valid map" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      {:ok, result} =
        SatelliteImageService.get_satellite_tiles(center_lat, center_lng, scale, width, height)

      assert is_integer(result.zoom)
      assert result.zoom >= 0 and result.zoom <= 19
      assert is_list(result.tiles)
      assert length(result.tiles) > 0

      # Check bounds structure
      assert is_float(result.bounds.north)
      assert is_float(result.bounds.south)
      assert is_float(result.bounds.west)
      assert is_float(result.bounds.east)

      # Check center structure
      assert result.center.lat == center_lat
      assert result.center.lng == center_lng

      # Check map extent
      assert is_float(result.map_extent_meters.width)
      assert is_float(result.map_extent_meters.height)
    end

    test "tiles have correct structure" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      {:ok, result} =
        SatelliteImageService.get_satellite_tiles(center_lat, center_lng, scale, width, height)

      for tile <- result.tiles do
        assert is_binary(tile.url)
        # URL should use proxy endpoint with .png extension
        assert String.starts_with?(tile.url, "/api/tiles/")
        assert String.ends_with?(tile.url, ".png")
        assert is_integer(tile.x)
        assert is_integer(tile.y)
        assert is_float(tile.north)
        assert is_float(tile.south)
        assert is_float(tile.west)
        assert is_float(tile.east)

        # North should be greater than south
        assert tile.north > tile.south
        # East should be greater than west
        assert tile.east > tile.west
      end
    end

    test "tiles cover the map bounds" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      {:ok, result} =
        SatelliteImageService.get_satellite_tiles(center_lat, center_lng, scale, width, height)

      # Find the extent covered by all tiles
      tile_north = result.tiles |> Enum.map(& &1.north) |> Enum.max()
      tile_south = result.tiles |> Enum.map(& &1.south) |> Enum.min()
      tile_west = result.tiles |> Enum.map(& &1.west) |> Enum.min()
      tile_east = result.tiles |> Enum.map(& &1.east) |> Enum.max()

      # Tiles should cover at least the map bounds
      assert tile_north >= result.bounds.north
      assert tile_south <= result.bounds.south
      assert tile_west <= result.bounds.west
      assert tile_east >= result.bounds.east
    end
  end

  describe "get_satellite_image_url/6" do
    test "returns proxy tile URL for openstreetmap provider" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      {:ok, url} =
        SatelliteImageService.get_satellite_image_url(
          center_lat,
          center_lng,
          scale,
          width,
          height,
          provider: :openstreetmap
        )

      assert is_binary(url)
      # Uses proxy URL to bypass CORS with .png extension
      assert String.starts_with?(url, "/api/tiles/")
      assert String.ends_with?(url, ".png")
    end

    test "returns error for maptiler without API key" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      result =
        SatelliteImageService.get_satellite_image_url(
          center_lat,
          center_lng,
          scale,
          width,
          height,
          provider: :maptiler
        )

      # Without an API key configured, this should return an error
      assert result == {:error, :no_api_key}
    end

    test "returns error for unsupported provider" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 500
      width = 10
      height = 10

      result =
        SatelliteImageService.get_satellite_image_url(
          center_lat,
          center_lng,
          scale,
          width,
          height,
          provider: :unknown_provider
        )

      assert {:error, {:unsupported_provider, :unknown_provider}} = result
    end
  end

  describe "zoom level calculation" do
    test "smaller maps get higher zoom levels" do
      center_lat = 50.0
      center_lng = 30.0

      # Small map (100m scale, 5x5)
      {:ok, small_result} =
        SatelliteImageService.get_satellite_tiles(center_lat, center_lng, 100, 5, 5)

      # Large map (1000m scale, 50x50)
      {:ok, large_result} =
        SatelliteImageService.get_satellite_tiles(center_lat, center_lng, 1000, 50, 50)

      # Smaller map should have higher zoom (more detailed)
      assert small_result.zoom >= large_result.zoom
    end
  end
end
