defmodule WargameAi.Player do
  @moduledoc """
  Main AI player module. Orchestrates a complete turn by delegating
  to phase-specific tactics modules.

  ## Difficulty Levels

  - `:easy` - Makes random suboptimal choices ~40% of the time
  - `:normal` - Makes random suboptimal choices ~15% of the time
  - `:hard` - Always picks the best evaluated option

  ## Personality

  - `:balanced` - Default weights
  - `:aggressive` - Favors attacks, lower odds threshold
  - `:defensive` - Favors terrain, higher odds threshold
  """

  alias WargameAi.{Evaluator, Tactics}
  alias WargameCore.Turns.TurnState

  @type difficulty :: :easy | :normal | :hard
  @type personality :: :balanced | :aggressive | :defensive

  @type config :: %{
          difficulty: difficulty(),
          personality: personality(),
          side: atom()
        }

  @doc """
  Plays a complete turn for the AI, returning a list of actions to execute.

  Each action is a tuple like `{:move, unit_id, path}`, `{:attack, unit_ids, target}`,
  or `:end_phase`.
  """
  @spec play_turn(map(), config()) :: [tuple()]
  def play_turn(game_state, config) do
    side = config.side
    turn_state = game_state.turn_state

    if not TurnState.is_active_side?(turn_state, side) do
      []
    else
      play_phases(game_state, config, [])
    end
  end

  defp play_phases(game_state, config, acc_actions) do
    turn_state = game_state.turn_state
    phase = TurnState.current_phase(turn_state)

    if phase == nil do
      acc_actions
    else
      phase_actions = plan_phase_actions(game_state, config, phase)
      all_actions = acc_actions ++ phase_actions ++ [:end_phase]

      # Simulate advancing phase to see if we keep going
      case TurnState.advance_phase(turn_state) do
        {:ok, new_turn_state} ->
          if TurnState.is_active_side?(new_turn_state, config.side) do
            new_state = %{game_state | turn_state: new_turn_state}
            play_phases(new_state, config, all_actions)
          else
            all_actions
          end

        {:end_of_turn, _} ->
          all_actions

        {:end_of_game, _} ->
          all_actions
      end
    end
  end

  defp plan_phase_actions(game_state, config, phase) do
    cond do
      phase.allows_movement ->
        Tactics.Movement.plan_moves(game_state, config)

      phase.allows_combat ->
        Tactics.Combat.plan_attacks(game_state, config)

      true ->
        []
    end
  end

  @doc """
  Applies difficulty-based degradation to a sorted list of scored options.

  At lower difficulties, sometimes picks a suboptimal choice.
  Returns the selected option.
  """
  @spec apply_difficulty([{term(), float()}], difficulty()) :: term() | nil
  def apply_difficulty([], _difficulty), do: nil

  def apply_difficulty(scored_options, :hard) do
    {best, _score} = hd(scored_options)
    best
  end

  def apply_difficulty(scored_options, difficulty) do
    noise_chance = case difficulty do
      :easy -> 0.40
      :normal -> 0.15
      _ -> 0.0
    end

    if :rand.uniform() < noise_chance and length(scored_options) > 1 do
      # Pick randomly from top half
      top_half = Enum.take(scored_options, max(div(length(scored_options), 2), 2))
      {choice, _} = Enum.random(top_half)
      choice
    else
      {best, _} = hd(scored_options)
      best
    end
  end

  @doc """
  Returns evaluation weights adjusted for personality.
  """
  @spec personality_weights(personality()) :: map()
  def personality_weights(:aggressive) do
    Evaluator.default_weights()
    |> Map.merge(%{
      vp_control: 15.0,
      unit_strength: 4.0,
      territorial_depth: 0.5,
      enemy_disruption: 4.0
    })
  end

  def personality_weights(:defensive) do
    Evaluator.default_weights()
    |> Map.merge(%{
      vp_control: 8.0,
      unit_strength: 2.0,
      territorial_depth: 3.0,
      leader_survival: 12.0
    })
  end

  def personality_weights(:balanced), do: Evaluator.default_weights()
  def personality_weights(_), do: Evaluator.default_weights()
end
