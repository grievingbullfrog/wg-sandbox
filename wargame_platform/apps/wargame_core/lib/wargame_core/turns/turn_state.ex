defmodule WargameCore.Turns.TurnState do
  @moduledoc """
  Manages the current turn state within a game.

  Tracks:
  - Current turn number
  - Current phase
  - Active player/side
  - Phase sequence for the current turn
  - Turn history

  ## Turn Flow

  A typical turn flows as:
  1. Start of turn (both sides)
  2. First player's phases (all phases in sequence)
  3. Second player's phases (all phases in sequence)
  4. End of turn, advance turn counter, repeat

  ## Player Order

  Player order can be:
  - Alternating by turn (IGOUGO)
  - Alternating by phase (each phase both players act)
  - Simultaneous (both plan, then resolve)
  """

  alias WargameCore.Turns.Phase

  @type player_order :: :igougo | :alternating_phase | :simultaneous

  @type t :: %__MODULE__{
          turn_number: pos_integer(),
          max_turns: pos_integer() | :unlimited,
          current_phase_index: non_neg_integer(),
          phases: [Phase.t()],
          active_side: atom(),
          sides: [atom()],
          side_index: non_neg_integer(),
          player_order: player_order(),
          turn_history: [map()],
          phase_complete: boolean()
        }

  @enforce_keys [:phases, :sides]
  defstruct [
    :phases,
    :sides,
    turn_number: 1,
    max_turns: :unlimited,
    current_phase_index: 0,
    active_side: nil,
    side_index: 0,
    player_order: :igougo,
    turn_history: [],
    phase_complete: false
  ]

  @doc """
  Creates a new turn state with the given phases and sides.

  ## Options

  - :max_turns - Maximum number of turns (default: :unlimited)
  - :player_order - How players alternate (default: :igougo)

  ## Examples

      iex> phases = WargameCore.Turns.Phase.standard_phases()
      iex> state = WargameCore.Turns.TurnState.new(phases, [:german, :soviet])
      iex> state.turn_number
      1
  """
  @spec new([Phase.t()], [atom()], keyword()) :: t()
  def new(phases, sides, opts \\ []) when is_list(phases) and is_list(sides) and length(sides) >= 1 do
    sorted_phases = Enum.sort_by(phases, & &1.order)
    [first_side | _] = sides

    %__MODULE__{
      phases: sorted_phases,
      sides: sides,
      active_side: first_side,
      max_turns: Keyword.get(opts, :max_turns, :unlimited),
      player_order: Keyword.get(opts, :player_order, :igougo)
    }
  end

  @doc """
  Returns the current phase.
  """
  @spec current_phase(t()) :: Phase.t()
  def current_phase(%__MODULE__{phases: phases, current_phase_index: index}) do
    Enum.at(phases, index)
  end

  @doc """
  Returns the active side (player) for the current phase.
  """
  @spec active_side(t()) :: atom()
  def active_side(%__MODULE__{active_side: side}), do: side

  @doc """
  Checks if the given side is the active side.
  """
  @spec is_active_side?(t(), atom()) :: boolean()
  def is_active_side?(%__MODULE__{active_side: active}, side), do: active == side

  @doc """
  Advances to the next phase.

  Returns {:ok, updated_state} or {:end_of_game, final_state} if max turns reached.
  """
  @spec advance_phase(t()) :: {:ok, t()} | {:end_of_turn, t()} | {:end_of_game, t()}
  def advance_phase(%__MODULE__{} = state) do
    case state.player_order do
      :igougo -> advance_igougo(state)
      :alternating_phase -> advance_alternating(state)
      :simultaneous -> advance_simultaneous(state)
    end
  end

  # I-Go-U-Go: One player completes all phases, then the other
  defp advance_igougo(%__MODULE__{} = state) do
    next_phase_index = state.current_phase_index + 1

    cond do
      # More phases for current player
      next_phase_index < length(state.phases) ->
        {:ok, %{state | current_phase_index: next_phase_index, phase_complete: false}}

      # Switch to next player
      state.side_index + 1 < length(state.sides) ->
        next_side_index = state.side_index + 1
        next_side = Enum.at(state.sides, next_side_index)

        {:ok,
         %{
           state
           | current_phase_index: 0,
             side_index: next_side_index,
             active_side: next_side,
             phase_complete: false
         }}

      # End of turn - advance to next turn
      true ->
        advance_turn(state)
    end
  end

  # Alternating: Both players act in each phase before advancing
  defp advance_alternating(%__MODULE__{} = state) do
    cond do
      # More players need to act in current phase
      state.side_index + 1 < length(state.sides) ->
        next_side_index = state.side_index + 1
        next_side = Enum.at(state.sides, next_side_index)

        {:ok,
         %{
           state
           | side_index: next_side_index,
             active_side: next_side,
             phase_complete: false
         }}

      # Advance to next phase, reset to first player
      state.current_phase_index + 1 < length(state.phases) ->
        [first_side | _] = state.sides

        {:ok,
         %{
           state
           | current_phase_index: state.current_phase_index + 1,
             side_index: 0,
             active_side: first_side,
             phase_complete: false
         }}

      # End of turn
      true ->
        advance_turn(state)
    end
  end

  # Simultaneous: Both players act together (simplified as sequential for now)
  defp advance_simultaneous(%__MODULE__{} = state) do
    advance_alternating(state)
  end

  defp advance_turn(%__MODULE__{turn_number: turn, max_turns: max} = state) do
    next_turn = turn + 1
    [first_side | _] = state.sides

    # Record turn in history
    history_entry = %{
      turn: turn,
      completed_at: DateTime.utc_now()
    }

    new_state = %{
      state
      | turn_number: next_turn,
        current_phase_index: 0,
        side_index: 0,
        active_side: first_side,
        phase_complete: false,
        turn_history: [history_entry | state.turn_history]
    }

    if max != :unlimited and next_turn > max do
      {:end_of_game, new_state}
    else
      {:end_of_turn, new_state}
    end
  end

  @doc """
  Marks the current phase as complete for the active player.
  """
  @spec complete_phase(t()) :: t()
  def complete_phase(%__MODULE__{} = state) do
    %{state | phase_complete: true}
  end

  @doc """
  Skips an optional phase.

  Returns {:error, :not_optional} if the phase is not optional.
  """
  @spec skip_phase(t()) :: {:ok, t()} | {:error, :not_optional}
  def skip_phase(%__MODULE__{} = state) do
    phase = current_phase(state)

    if Phase.optional?(phase) do
      advance_phase(state)
    else
      {:error, :not_optional}
    end
  end

  @doc """
  Checks if movement is currently allowed.
  """
  @spec can_move?(t()) :: boolean()
  def can_move?(%__MODULE__{} = state) do
    state
    |> current_phase()
    |> Phase.allows_movement?()
  end

  @doc """
  Checks if combat is currently allowed.
  """
  @spec can_attack?(t()) :: boolean()
  def can_attack?(%__MODULE__{} = state) do
    state
    |> current_phase()
    |> Phase.allows_combat?()
  end

  @doc """
  Checks if orders can be issued.
  """
  @spec can_order?(t()) :: boolean()
  def can_order?(%__MODULE__{} = state) do
    state
    |> current_phase()
    |> Phase.allows_orders?()
  end

  @doc """
  Returns a summary of the current turn state.
  """
  @spec summary(t()) :: map()
  def summary(%__MODULE__{} = state) do
    phase = current_phase(state)

    %{
      turn: state.turn_number,
      max_turns: state.max_turns,
      phase: phase.name,
      phase_id: phase.id,
      active_side: state.active_side,
      can_move: Phase.allows_movement?(phase),
      can_attack: Phase.allows_combat?(phase),
      can_order: Phase.allows_orders?(phase)
    }
  end

  @doc """
  Checks if the game has ended (max turns reached).
  """
  @spec game_over?(t()) :: boolean()
  def game_over?(%__MODULE__{max_turns: :unlimited}), do: false
  def game_over?(%__MODULE__{turn_number: turn, max_turns: max}), do: turn > max
end
