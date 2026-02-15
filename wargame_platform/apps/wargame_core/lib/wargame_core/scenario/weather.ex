defmodule WargameCore.Scenario.Weather do
  @moduledoc """
  Weather and ground condition system for wargame scenarios.

  Weather affects movement costs, combat effectiveness, and air support availability.
  Ground conditions compound with weather (e.g., rain causes mud, snow freezes ground).

  ## Weather Schedule

  Scenarios define a weather schedule as a list of entries:

      [
        %{turns: 1..4, weather: :clear, ground: :dry},
        %{turns: 5..8, weather: :rain, ground: :mud},
        %{turns: 9..12, weather: :snow, ground: :frozen}
      ]

  ## Eastern Front Significance

  The rasputitsa (mud season) and winter freezes were decisive factors on the
  Eastern Front. This module models those effects on unit mobility and combat.
  """

  @type weather :: :clear | :rain | :overcast | :snow | :blizzard | :rasputitsa
  @type ground :: :dry | :mud | :frozen | :deep_mud
  @type weather_state :: %{weather: weather(), ground: ground()}

  @type schedule_entry :: %{
          turns: Range.t(),
          weather: weather(),
          ground: ground()
        }

  @valid_weather [:clear, :rain, :overcast, :snow, :blizzard, :rasputitsa]
  @valid_ground [:dry, :mud, :frozen, :deep_mud]

  # Movement modifiers by weather/ground and movement type
  # Format: {weather, ground} => %{movement_type => multiplier}
  @movement_modifiers %{
    {:clear, :dry} => %{foot: 1.0, wheeled: 1.0, tracked: 1.0, horse: 1.0},
    {:rain, :mud} => %{foot: 0.7, wheeled: 0.5, tracked: 0.7, horse: 0.6},
    {:overcast, :dry} => %{foot: 1.0, wheeled: 1.0, tracked: 1.0, horse: 1.0},
    {:snow, :frozen} => %{foot: 0.8, wheeled: 0.8, tracked: 0.8, horse: 0.8},
    {:blizzard, :frozen} => %{foot: 0.5, wheeled: 0.5, tracked: 0.5, horse: 0.5},
    {:rasputitsa, :deep_mud} => %{foot: 0.5, wheeled: 0.3, tracked: 0.5, horse: 0.4}
  }

  # Combat modifiers (penalty to attacker)
  @combat_modifiers %{
    {:clear, :dry} => 0,
    {:rain, :mud} => -1,
    {:overcast, :dry} => 0,
    {:snow, :frozen} => -1,
    {:blizzard, :frozen} => -2,
    {:rasputitsa, :deep_mud} => -2
  }

  # Air support levels
  @air_support_levels %{
    {:clear, :dry} => :full,
    {:rain, :mud} => :reduced,
    {:overcast, :dry} => :none,
    {:snow, :frozen} => :reduced,
    {:blizzard, :frozen} => :none,
    {:rasputitsa, :deep_mud} => :reduced
  }

  @doc """
  Returns the weather state for a given turn from the schedule.

  If the turn falls outside all defined ranges, returns clear/dry as default.
  """
  @spec current_weather([schedule_entry()], pos_integer()) :: weather_state()
  def current_weather(schedule, turn) when is_list(schedule) and is_integer(turn) and turn > 0 do
    entry = Enum.find(schedule, fn entry ->
      turn in entry.turns
    end)

    case entry do
      nil -> %{weather: :clear, ground: :dry}
      %{weather: weather, ground: ground} -> %{weather: weather, ground: ground}
    end
  end

  def current_weather(_, _), do: %{weather: :clear, ground: :dry}

  @doc """
  Returns the movement multiplier for a given movement type in current weather/ground.

  The multiplier is applied to the unit's base movement points.
  For example, 0.5 means the unit has half its normal movement.
  """
  @spec movement_modifier(weather_state(), atom()) :: float()
  def movement_modifier(%{weather: weather, ground: ground}, movement_type) do
    key = {weather, ground}
    type_modifiers = Map.get(@movement_modifiers, key, default_movement_modifiers())
    Map.get(type_modifiers, movement_type, 1.0)
  end

  @doc """
  Returns the combat modifier (attacker penalty) for current weather/ground.

  Negative values reduce the attacker's combat strength.
  """
  @spec combat_modifier(weather_state()) :: integer()
  def combat_modifier(%{weather: weather, ground: ground}) do
    Map.get(@combat_modifiers, {weather, ground}, 0)
  end

  @doc """
  Returns the air support level for current weather/ground.

  - :full - full air support available
  - :reduced - limited air support
  - :none - no air support
  """
  @spec air_support_level(weather_state()) :: :full | :reduced | :none
  def air_support_level(%{weather: weather, ground: ground}) do
    Map.get(@air_support_levels, {weather, ground}, :none)
  end

  @doc """
  Returns the list of valid weather atoms.
  """
  @spec valid_weather() :: [weather()]
  def valid_weather, do: @valid_weather

  @doc """
  Returns the list of valid ground condition atoms.
  """
  @spec valid_ground() :: [ground()]
  def valid_ground, do: @valid_ground

  @doc """
  Validates a weather schedule.
  Returns :ok if valid, {:error, reason} if not.
  """
  @spec validate_schedule([schedule_entry()]) :: :ok | {:error, String.t()}
  def validate_schedule(schedule) when is_list(schedule) do
    cond do
      Enum.empty?(schedule) ->
        :ok

      Enum.any?(schedule, fn entry ->
        not (Map.has_key?(entry, :turns) and Map.has_key?(entry, :weather) and Map.has_key?(entry, :ground))
      end) ->
        {:error, "each schedule entry must have :turns, :weather, and :ground keys"}

      Enum.any?(schedule, fn entry -> entry.weather not in @valid_weather end) ->
        {:error, "invalid weather type in schedule"}

      Enum.any?(schedule, fn entry -> entry.ground not in @valid_ground end) ->
        {:error, "invalid ground type in schedule"}

      true ->
        :ok
    end
  end

  def validate_schedule(_), do: {:error, "schedule must be a list"}

  defp default_movement_modifiers do
    %{foot: 1.0, wheeled: 1.0, tracked: 1.0, horse: 1.0}
  end
end
