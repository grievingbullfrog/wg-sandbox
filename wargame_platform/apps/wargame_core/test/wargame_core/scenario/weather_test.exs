defmodule WargameCore.Scenario.WeatherTest do
  use ExUnit.Case, async: true

  alias WargameCore.Scenario.Weather

  @schedule [
    %{turns: 1..4, weather: :clear, ground: :dry},
    %{turns: 5..8, weather: :rain, ground: :mud},
    %{turns: 9..10, weather: :overcast, ground: :dry},
    %{turns: 11..14, weather: :snow, ground: :frozen},
    %{turns: 15..16, weather: :blizzard, ground: :frozen},
    %{turns: 17..20, weather: :rasputitsa, ground: :deep_mud}
  ]

  describe "current_weather/2" do
    test "returns weather for turn within first range" do
      assert Weather.current_weather(@schedule, 1) == %{weather: :clear, ground: :dry}
      assert Weather.current_weather(@schedule, 4) == %{weather: :clear, ground: :dry}
    end

    test "returns weather for turn in middle ranges" do
      assert Weather.current_weather(@schedule, 6) == %{weather: :rain, ground: :mud}
      assert Weather.current_weather(@schedule, 12) == %{weather: :snow, ground: :frozen}
      assert Weather.current_weather(@schedule, 15) == %{weather: :blizzard, ground: :frozen}
      assert Weather.current_weather(@schedule, 18) == %{weather: :rasputitsa, ground: :deep_mud}
    end

    test "returns clear/dry default for turn outside all ranges" do
      assert Weather.current_weather(@schedule, 25) == %{weather: :clear, ground: :dry}
    end

    test "returns clear/dry for empty schedule" do
      assert Weather.current_weather([], 1) == %{weather: :clear, ground: :dry}
    end
  end

  describe "movement_modifier/2" do
    test "clear/dry: all movement types get 1.0" do
      state = %{weather: :clear, ground: :dry}
      assert Weather.movement_modifier(state, :foot) == 1.0
      assert Weather.movement_modifier(state, :wheeled) == 1.0
      assert Weather.movement_modifier(state, :tracked) == 1.0
      assert Weather.movement_modifier(state, :horse) == 1.0
    end

    test "rain/mud: wheeled most penalized" do
      state = %{weather: :rain, ground: :mud}
      assert Weather.movement_modifier(state, :foot) == 0.7
      assert Weather.movement_modifier(state, :wheeled) == 0.5
      assert Weather.movement_modifier(state, :tracked) == 0.7
      assert Weather.movement_modifier(state, :horse) == 0.6
    end

    test "overcast/dry: no movement penalty" do
      state = %{weather: :overcast, ground: :dry}
      assert Weather.movement_modifier(state, :foot) == 1.0
      assert Weather.movement_modifier(state, :wheeled) == 1.0
    end

    test "snow/frozen: uniform 0.8 penalty" do
      state = %{weather: :snow, ground: :frozen}
      assert Weather.movement_modifier(state, :foot) == 0.8
      assert Weather.movement_modifier(state, :wheeled) == 0.8
      assert Weather.movement_modifier(state, :tracked) == 0.8
      assert Weather.movement_modifier(state, :horse) == 0.8
    end

    test "blizzard/frozen: severe 0.5 penalty for all" do
      state = %{weather: :blizzard, ground: :frozen}
      assert Weather.movement_modifier(state, :foot) == 0.5
      assert Weather.movement_modifier(state, :wheeled) == 0.5
      assert Weather.movement_modifier(state, :tracked) == 0.5
      assert Weather.movement_modifier(state, :horse) == 0.5
    end

    test "rasputitsa/deep_mud: wheeled nearly immobilized" do
      state = %{weather: :rasputitsa, ground: :deep_mud}
      assert Weather.movement_modifier(state, :foot) == 0.5
      assert Weather.movement_modifier(state, :wheeled) == 0.3
      assert Weather.movement_modifier(state, :tracked) == 0.5
      assert Weather.movement_modifier(state, :horse) == 0.4
    end

    test "unknown movement type defaults to 1.0" do
      state = %{weather: :clear, ground: :dry}
      assert Weather.movement_modifier(state, :air) == 1.0
    end
  end

  describe "combat_modifier/1" do
    test "clear/dry: no penalty" do
      assert Weather.combat_modifier(%{weather: :clear, ground: :dry}) == 0
    end

    test "rain/mud: -1 attacker penalty" do
      assert Weather.combat_modifier(%{weather: :rain, ground: :mud}) == -1
    end

    test "overcast/dry: no penalty" do
      assert Weather.combat_modifier(%{weather: :overcast, ground: :dry}) == 0
    end

    test "snow/frozen: -1 attacker penalty" do
      assert Weather.combat_modifier(%{weather: :snow, ground: :frozen}) == -1
    end

    test "blizzard/frozen: -2 attacker penalty" do
      assert Weather.combat_modifier(%{weather: :blizzard, ground: :frozen}) == -2
    end

    test "rasputitsa/deep_mud: -2 attacker penalty" do
      assert Weather.combat_modifier(%{weather: :rasputitsa, ground: :deep_mud}) == -2
    end
  end

  describe "air_support_level/1" do
    test "clear/dry: full air support" do
      assert Weather.air_support_level(%{weather: :clear, ground: :dry}) == :full
    end

    test "rain/mud: reduced air support" do
      assert Weather.air_support_level(%{weather: :rain, ground: :mud}) == :reduced
    end

    test "overcast/dry: no air support" do
      assert Weather.air_support_level(%{weather: :overcast, ground: :dry}) == :none
    end

    test "snow/frozen: reduced air support" do
      assert Weather.air_support_level(%{weather: :snow, ground: :frozen}) == :reduced
    end

    test "blizzard/frozen: no air support" do
      assert Weather.air_support_level(%{weather: :blizzard, ground: :frozen}) == :none
    end

    test "rasputitsa/deep_mud: reduced air support" do
      assert Weather.air_support_level(%{weather: :rasputitsa, ground: :deep_mud}) == :reduced
    end
  end

  describe "valid_weather/0" do
    test "returns all weather types" do
      weather = Weather.valid_weather()
      assert :clear in weather
      assert :rain in weather
      assert :overcast in weather
      assert :snow in weather
      assert :blizzard in weather
      assert :rasputitsa in weather
    end
  end

  describe "valid_ground/0" do
    test "returns all ground types" do
      ground = Weather.valid_ground()
      assert :dry in ground
      assert :mud in ground
      assert :frozen in ground
      assert :deep_mud in ground
    end
  end

  describe "validate_schedule/1" do
    test "valid schedule passes" do
      assert Weather.validate_schedule(@schedule) == :ok
    end

    test "empty schedule is valid" do
      assert Weather.validate_schedule([]) == :ok
    end

    test "invalid weather type fails" do
      bad = [%{turns: 1..3, weather: :tornado, ground: :dry}]
      assert {:error, _} = Weather.validate_schedule(bad)
    end

    test "invalid ground type fails" do
      bad = [%{turns: 1..3, weather: :clear, ground: :lava}]
      assert {:error, _} = Weather.validate_schedule(bad)
    end

    test "missing keys fails" do
      bad = [%{turns: 1..3, weather: :clear}]
      assert {:error, _} = Weather.validate_schedule(bad)
    end
  end
end
