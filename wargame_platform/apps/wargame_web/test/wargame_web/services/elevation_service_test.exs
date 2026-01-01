defmodule WargameWeb.Services.ElevationServiceTest do
  use ExUnit.Case, async: true

  alias WargameWeb.Services.ElevationService

  describe "hex_to_latlon/7" do
    test "center hex returns centerpoint" do
      # 10x10 map, center hex is at (4.5, 4.5)
      # For an odd-sized map, let's use 11x11 where center is exactly (5, 5)
      center_lat = 50.0
      center_lng = 30.0
      scale = 1000  # 1km per hex
      map_width = 11
      map_height = 11

      {lat, lng} = ElevationService.hex_to_latlon(5, 5, center_lat, center_lng, scale, map_width, map_height)

      # Center hex should be very close to centerpoint
      assert_in_delta lat, center_lat, 0.0001
      assert_in_delta lng, center_lng, 0.0001
    end

    test "moving right increases longitude" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 1000
      map_width = 11
      map_height = 11

      {_lat1, lng1} = ElevationService.hex_to_latlon(5, 5, center_lat, center_lng, scale, map_width, map_height)
      {_lat2, lng2} = ElevationService.hex_to_latlon(6, 5, center_lat, center_lng, scale, map_width, map_height)

      assert lng2 > lng1
    end

    test "moving down decreases latitude" do
      center_lat = 50.0
      center_lng = 30.0
      scale = 1000
      map_width = 11
      map_height = 11

      {lat1, _lng1} = ElevationService.hex_to_latlon(5, 5, center_lat, center_lng, scale, map_width, map_height)
      {lat2, _lng2} = ElevationService.hex_to_latlon(5, 6, center_lat, center_lng, scale, map_width, map_height)

      # r increases downward, so latitude should decrease
      assert lat2 < lat1
    end

    test "scale affects distance" do
      center_lat = 50.0
      center_lng = 30.0
      map_width = 11
      map_height = 11

      # Moving one hex down (r+1) should result in different latitude offsets
      # based on scale
      {lat1, _} = ElevationService.hex_to_latlon(5, 6, center_lat, center_lng, 100, map_width, map_height)
      {lat2, _} = ElevationService.hex_to_latlon(5, 6, center_lat, center_lng, 1000, map_width, map_height)

      # With larger scale, the same hex coordinate is further from center
      dist1 = abs(lat1 - center_lat)
      dist2 = abs(lat2 - center_lat)

      assert dist2 > dist1
    end
  end

  describe "fetch_map_elevations/1" do
    test "returns error when centerpoint is nil" do
      map = %WargameCore.Map{
        name: "Test",
        width: 5,
        height: 5,
        scale: 200,
        centerpoint_lat: nil,
        centerpoint_lng: nil,
        tiles: %{},
        base_elevation: 0
      }

      assert {:error, :no_centerpoint} = ElevationService.fetch_map_elevations(map)
    end

    test "returns error when only lat is nil" do
      map = %WargameCore.Map{
        name: "Test",
        width: 5,
        height: 5,
        scale: 200,
        centerpoint_lat: nil,
        centerpoint_lng: 30.0,
        tiles: %{},
        base_elevation: 0
      }

      assert {:error, :no_centerpoint} = ElevationService.fetch_map_elevations(map)
    end

    test "returns error when only lng is nil" do
      map = %WargameCore.Map{
        name: "Test",
        width: 5,
        height: 5,
        scale: 200,
        centerpoint_lat: 50.0,
        centerpoint_lng: nil,
        tiles: %{},
        base_elevation: 0
      }

      assert {:error, :no_centerpoint} = ElevationService.fetch_map_elevations(map)
    end
  end

  describe "fetch_elevations/1" do
    test "returns empty list for empty input" do
      assert {:ok, []} = ElevationService.fetch_elevations([])
    end

    # Note: This test makes a real API call - skip in CI or mock in production
    @tag :external_api
    test "fetches real elevation data" do
      # Kursk, Russia - known elevation around 250m
      coords = [{51.7373, 36.1873}]

      case ElevationService.fetch_elevations(coords) do
        {:ok, [elevation]} ->
          # Kursk is on a plateau, elevation should be between 150-300m
          assert is_number(elevation)
          assert elevation > 100
          assert elevation < 400

        {:error, reason} ->
          # API might be unavailable in test environment
          IO.puts("Skipping API test: #{inspect(reason)}")
      end
    end
  end
end
