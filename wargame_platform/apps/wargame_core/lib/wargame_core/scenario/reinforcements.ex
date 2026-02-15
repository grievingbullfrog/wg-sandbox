defmodule WargameCore.Scenario.Reinforcements do
  @moduledoc """
  Handles reinforcement deployment for wargame scenarios.

  Supports three reinforcement modes:
  - `:fixed` - Units arrive exactly on their scheduled turn (historical mode)
  - `:variable` - Probability-based arrival around the scheduled turn
  - `:conditional` - Units arrive when a condition function returns true

  ## Variable Mode Mechanics

  When mode is `:variable`:
  - `base_probability`: 80% chance of arriving on the scheduled turn
  - `earliest`: can arrive 1 turn early
  - `latest`: can arrive up to 3 turns late
  - `no_show_chance`: 10% chance of never arriving
  - Probability increases each turn past the scheduled arrival
  """

  alias WargameCore.Units.UnitInstance

  @default_base_probability 0.8
  @default_no_show_chance 0.1
  @default_early_offset 1
  @default_late_offset 3
  @probability_increase_per_turn 0.1

  @type reinforcement_mode :: :fixed | :variable | :conditional

  @doc """
  Deploys reinforcements for the given turn.

  Returns a list of units that should be deployed this turn.

  ## Parameters
  - current_turn: the current turn number
  - scenario_units: list of unit maps with `:arrives_turn`, `:deploy_hex`, etc.
  - mode: `:fixed`, `:variable`, or `:conditional`
  - opts: additional options (e.g., condition functions for conditional mode)

  ## Returns
  List of unit maps that should be placed on the map this turn.
  """
  @spec deploy_reinforcements(pos_integer(), [map()], reinforcement_mode(), keyword()) :: [map()]
  def deploy_reinforcements(current_turn, scenario_units, mode, opts \\ [])

  def deploy_reinforcements(current_turn, scenario_units, :fixed, _opts) do
    Enum.filter(scenario_units, fn unit ->
      unit.arrives_turn == current_turn
    end)
  end

  def deploy_reinforcements(current_turn, scenario_units, :variable, opts) do
    rand_fn = Keyword.get(opts, :rand_fn, fn -> :rand.uniform() end)

    Enum.filter(scenario_units, fn unit ->
      variable_arrival?(current_turn, unit, rand_fn)
    end)
  end

  def deploy_reinforcements(current_turn, scenario_units, :conditional, opts) do
    condition_fn = Keyword.get(opts, :condition_fn, fn _unit, _turn -> false end)
    game_state = Keyword.get(opts, :game_state, %{})

    Enum.filter(scenario_units, fn unit ->
      # Conditional units also have a scheduled turn as earliest possible
      current_turn >= (unit.arrives_turn || 1) &&
        condition_fn.(unit, game_state)
    end)
  end

  @doc """
  Creates a UnitInstance from a reinforcement unit definition and its template.

  The unit is placed at its deploy_hex position.
  """
  @spec instantiate_reinforcement(map(), map()) :: UnitInstance.t()
  def instantiate_reinforcement(unit_def, template) do
    UnitInstance.new(template, %{
      id: unit_def[:id],
      name: unit_def[:name] || template.name,
      side: unit_def[:side],
      force: unit_def[:force],
      position: unit_def[:deploy_hex],
      experience: unit_def[:experience] || 0,
      morale: unit_def[:morale] || 80
    })
  end

  @doc """
  Returns units that are still waiting to be deployed (not yet arrived).
  Useful for showing the reinforcement schedule to the player.
  """
  @spec pending_reinforcements(pos_integer(), [map()]) :: [map()]
  def pending_reinforcements(current_turn, scenario_units) do
    Enum.filter(scenario_units, fn unit ->
      (unit.arrives_turn || 0) > current_turn
    end)
  end

  @doc """
  Returns units that have been marked as no-show (variable mode only).
  """
  @spec check_no_shows([map()], pos_integer()) :: [map()]
  def check_no_shows(scenario_units, current_turn) do
    Enum.filter(scenario_units, fn unit ->
      latest = (unit.arrives_turn || 0) + Map.get(unit, :late_offset, @default_late_offset)
      current_turn > latest
    end)
  end

  # --- Private helpers ---

  defp variable_arrival?(current_turn, unit, rand_fn) do
    arrives = unit.arrives_turn || 0
    early_offset = Map.get(unit, :early_offset, @default_early_offset)
    late_offset = Map.get(unit, :late_offset, @default_late_offset)
    no_show = Map.get(unit, :no_show_chance, @default_no_show_chance)
    base_prob = Map.get(unit, :base_probability, @default_base_probability)

    earliest = arrives - early_offset
    latest = arrives + late_offset

    cond do
      # Too early
      current_turn < earliest ->
        false

      # Past the latest arrival - no show
      current_turn > latest ->
        false

      # Within the arrival window
      true ->
        roll = rand_fn.()

        # No-show check: high roll = no show (never arrives)
        if roll >= (1.0 - no_show) do
          false
        else
          # Calculate arrival probability based on timing
          turns_past = max(current_turn - arrives, 0)
          turns_early = max(arrives - current_turn, 0)

          probability = cond do
            turns_early > 0 ->
              # Early arrival: reduced probability
              base_prob * 0.3

            turns_past > 0 ->
              # Late arrival: increasing probability each turn
              min(base_prob + turns_past * @probability_increase_per_turn, 1.0 - no_show)

            true ->
              # On scheduled turn
              base_prob
          end

          roll < probability
        end
    end
  end
end
