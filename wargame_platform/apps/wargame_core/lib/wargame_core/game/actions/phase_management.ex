defmodule WargameCore.Game.Actions.PhaseManagement do
  @moduledoc """
  Handles phase and turn transitions in the game.

  Orchestrates the lifecycle events:
  - Phase end → next phase (or next side, or next turn)
  - Turn start: weather, supply, reinforcements, reset units
  - Turn end: entrenchment, morale recovery, victory check
  """

  alias WargameCore.Turns.TurnState
  alias WargameCore.Scenario.{Weather, Supply, Reinforcements}
  alias WargameCore.Units.UnitInstance

  @doc """
  Advances the game to the next phase.

  Handles the full lifecycle: on_phase_end → advance → on_phase_start,
  and on_turn_end → on_turn_start when turns change.
  """
  @spec advance_phase(map()) :: map()
  def advance_phase(state) do
    rules = state.rules_module
    current_phase = TurnState.current_phase(state.turn_state)

    # Run phase end hooks
    state = if function_exported?(rules, :on_phase_end, 2) do
      rules.on_phase_end(state, current_phase.id)
    else
      state
    end

    # Advance the turn state
    case TurnState.advance_phase(state.turn_state) do
      {:ok, new_turn_state} ->
        state = %{state | turn_state: new_turn_state}
        new_phase = TurnState.current_phase(new_turn_state)

        # Run phase start hooks
        if function_exported?(rules, :on_phase_start, 2) do
          rules.on_phase_start(state, new_phase.id)
        else
          state
        end

      {:end_of_turn, new_turn_state} ->
        state = %{state | turn_state: new_turn_state}

        # Run turn end lifecycle
        state = on_turn_end(state)

        # Run turn start lifecycle for the new turn
        state = on_turn_start(state)

        # Run phase start for the first phase of new turn
        new_phase = TurnState.current_phase(state.turn_state)
        if function_exported?(rules, :on_phase_start, 2) do
          rules.on_phase_start(state, new_phase.id)
        else
          state
        end

      {:end_of_game, new_turn_state} ->
        state = %{state | turn_state: new_turn_state}
        state = on_turn_end(state)
        check_final_victory(state)
    end
  end

  @doc """
  Runs the turn-start lifecycle events.

  1. Advance weather
  2. Recalculate supply
  3. Apply attrition to unsupplied units
  4. Deploy reinforcements
  5. Reset unit turn state
  """
  @spec on_turn_start(map()) :: map()
  def on_turn_start(state) do
    turn = state.turn_state.turn_number
    rules = state.rules_module

    state
    |> advance_weather(turn)
    |> recalculate_supply()
    |> apply_supply_attrition()
    |> deploy_reinforcements(turn)
    |> reset_all_units(rules, turn)
  end

  @doc """
  Runs the turn-end lifecycle events.

  1. Entrenchment for stationary units
  2. Morale recovery for supplied units in command
  3. Victory check
  """
  @spec on_turn_end(map()) :: map()
  def on_turn_end(state) do
    rules = state.rules_module

    state = if function_exported?(rules, :on_turn_end, 2) do
      rules.on_turn_end(state, state.turn_state.turn_number)
    else
      state
    end

    state
    |> check_victory()
  end

  # --- Private lifecycle steps ---

  defp advance_weather(state, turn) do
    schedule = Map.get(state, :weather_schedule, [])
    weather = Weather.current_weather(schedule, turn)
    %{state | weather: weather}
  end

  defp recalculate_supply(state) do
    tiles = Map.get(state, :tiles, %{})
    sources = Map.get(state, :supply_sources, [])
    side_ids = state.turn_state.sides

    supply_cache = Enum.reduce(side_ids, %{}, fn side_id, acc ->
      side_supply = Supply.calculate_supply_status(tiles, state.units, sources, side_id)
      Map.merge(acc, side_supply)
    end)

    %{state | supply_cache: supply_cache}
  end

  defp apply_supply_attrition(state) do
    supply_cache = Map.get(state, :supply_cache, %{})
    updated_units = Supply.apply_attrition(state.units, supply_cache)
    %{state | units: updated_units}
  end

  defp deploy_reinforcements(state, turn) do
    pending = Map.get(state, :pending_reinforcements, [])
    mode = Map.get(state, :reinforcement_mode, :fixed)
    templates = Map.get(state, :templates, %{})

    arriving = Reinforcements.deploy_reinforcements(turn, pending, mode)

    if Enum.empty?(arriving) do
      state
    else
      # Instantiate and add to units map
      new_units = Enum.reduce(arriving, state.units, fn unit_def, acc ->
        template = Map.get(templates, unit_def.template_id) || Map.get(templates, unit_def[:unit_template_id])

        instance = if template do
          Reinforcements.instantiate_reinforcement(unit_def, template)
        else
          # Minimal fallback
          %UnitInstance{
            id: unit_def.id,
            name: unit_def[:name] || "Reinforcement",
            side: unit_def.side,
            force: unit_def[:force],
            position: unit_def[:deploy_hex],
            template: nil,
            current_strength: 10,
            current_ammo: 10,
            current_fuel: 0,
            experience: 0,
            morale: 80,
            entrenchment: 0,
            movement_remaining: 4,
            has_attacked: false,
            has_moved: false,
            is_disrupted: false,
            is_routed: false,
            attachments: []
          }
        end

        Map.put(acc, instance.id, instance)
      end)

      # Remove arrived units from pending
      arrived_ids = MapSet.new(Enum.map(arriving, & &1.id))
      remaining = Enum.reject(pending, fn u -> MapSet.member?(arrived_ids, u.id) end)

      %{state | units: new_units, pending_reinforcements: remaining}
    end
  end

  defp reset_all_units(state, rules, turn) do
    if function_exported?(rules, :on_turn_start, 2) do
      rules.on_turn_start(state, turn)
    else
      # Default: reset movement and attack flags
      units = Map.new(state.units, fn {id, unit} ->
        case unit do
          %UnitInstance{} -> {id, UnitInstance.reset_turn_state(unit)}
          _ -> {id, unit}
        end
      end)
      %{state | units: units}
    end
  end

  defp check_victory(state) do
    rules = state.rules_module

    case rules.check_victory(state) do
      {:victory, winner, reason} ->
        %{state | status: :finished, result: {:victory, winner, reason}}

      {:draw, reason} ->
        %{state | status: :finished, result: {:draw, reason}}

      {:ongoing, _scores} ->
        state
    end
  end

  defp check_final_victory(state) do
    # At end of game, determine winner
    rules = state.rules_module

    case rules.check_victory(state) do
      {:victory, winner, reason} ->
        %{state | status: :finished, result: {:victory, winner, reason}}

      {:draw, reason} ->
        %{state | status: :finished, result: {:draw, reason}}

      {:ongoing, scores} ->
        # Game over by turn limit - whoever has more VP wins
        case Enum.max_by(scores, fn {_side, vp} -> vp end, fn -> {nil, 0} end) do
          {nil, _} ->
            %{state | status: :finished, result: {:draw, "No victory points scored"}}

          {winner, _vp} ->
            %{state | status: :finished, result: {:victory, winner, "Most victory points at end of game"}}
        end
    end
  end
end
