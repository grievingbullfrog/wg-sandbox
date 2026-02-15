defmodule WargameCore.Game.Actions.Move do
  @moduledoc """
  Handles movement actions in the game.

  Validates and executes unit movement using the game's rules module.
  """

  @doc """
  Validates and executes a move action.

  Returns `{:ok, new_state}` or `{:error, reason}`.
  """
  @spec execute(map(), String.t(), [map()]) :: {:ok, map()} | {:error, atom() | String.t()}
  def execute(state, unit_id, path) do
    rules = state.rules_module

    with :ok <- rules.validate_phase_action(state, :move),
         :ok <- rules.validate_movement(state, unit_id, path) do
      rules.execute_movement(state, unit_id, path)
    end
  end

  @doc """
  Unit holds position (used for entrench action).

  Marks the unit as having used its turn (can't move), and if the action
  allows entrenchment, increases entrenchment level.
  """
  @spec hold(map(), String.t()) :: {:ok, map()} | {:error, atom()}
  def hold(state, unit_id) do
    case Map.get(state.units, unit_id) do
      nil ->
        {:error, :unit_not_found}

      unit ->
        updated_unit = unit
          |> Map.put(:movement_remaining, 0)
          |> maybe_entrench()

        units = Map.put(state.units, unit_id, updated_unit)
        {:ok, %{state | units: units}}
    end
  end

  defp maybe_entrench(%{entrenchment: entrenchment} = unit) when is_integer(entrenchment) do
    can_entrench = case unit do
      %{template: %{can_entrench: true}} -> true
      %{can_entrench: true} -> true
      _ -> false
    end

    if can_entrench do
      %{unit | entrenchment: min(entrenchment + 1, 3)}
    else
      unit
    end
  end

  defp maybe_entrench(unit), do: unit
end
