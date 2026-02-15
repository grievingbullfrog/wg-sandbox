defmodule WargameCore.Game.GameServer do
  @moduledoc """
  GenServer managing a single game instance.

  Holds the complete game state and processes player actions through
  the rules engine. Broadcasts state changes via PubSub.

  ## State Shape

  The server state is the game state map produced by `Scenario.initial_game_state/1`,
  augmented with a `:game_id` key.

  ## Action Flow

  1. Player sends action via `perform_action/3`
  2. Server validates phase, side, and action-specific rules
  3. If valid, applies state changes
  4. Broadcasts updated state
  5. Returns result to caller
  """

  use GenServer

  alias WargameCore.Scenario.Scenario
  alias WargameCore.Turns.TurnState
  alias WargameCore.Game.Actions

  # --- Client API ---

  @doc """
  Starts a GameServer from a scenario struct.
  """
  def start_link(opts) do
    scenario = Keyword.fetch!(opts, :scenario)
    game_id = Keyword.get(opts, :game_id, generate_id())
    name = Keyword.get(opts, :name)

    GenServer.start_link(__MODULE__, {scenario, game_id}, name: name)
  end

  @doc """
  Returns the current game state.
  """
  def get_state(server) do
    GenServer.call(server, :get_state)
  end

  @doc """
  Performs a game action for the given side.

  Action types:
  - `{:move, unit_id, path}` - Move a unit along a path
  - `{:attack, attacker_ids, target_coord}` - Declare an attack
  - `{:hold, unit_id}` - Unit holds position (entrench)

  Returns `{:ok, updated_state}` or `{:error, reason}`.
  """
  def perform_action(server, side, action) do
    GenServer.call(server, {:action, side, action})
  end

  @doc """
  Ends the current phase for the given side, advancing to the next.
  """
  def end_phase(server, side) do
    GenServer.call(server, {:end_phase, side})
  end

  @doc """
  Returns the game ID.
  """
  def game_id(server) do
    GenServer.call(server, :game_id)
  end

  # --- Server Callbacks ---

  @impl true
  def init({scenario, game_id}) do
    state = Scenario.initial_game_state(scenario)
    state = Map.put(state, :game_id, game_id)

    # Run initial phase start
    rules = state.rules_module
    state = if function_exported?(rules, :on_phase_start, 2) do
      phase = TurnState.current_phase(state.turn_state)
      rules.on_phase_start(state, phase.id)
    else
      state
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:game_id, _from, state) do
    {:reply, state.game_id, state}
  end

  @impl true
  def handle_call({:action, side, action}, _from, state) do
    # Validate it's this side's turn
    case validate_side(state, side) do
      :ok ->
        case execute_action(state, side, action) do
          {:ok, new_state} ->
            new_state = log_action(new_state, side, action)
            broadcast(new_state)
            {:reply, {:ok, new_state}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:end_phase, side}, _from, state) do
    case validate_side(state, side) do
      :ok ->
        new_state = Actions.PhaseManagement.advance_phase(state)
        broadcast(new_state)
        {:reply, {:ok, new_state}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # --- Private helpers ---

  defp validate_side(state, side) do
    if TurnState.is_active_side?(state.turn_state, side) do
      :ok
    else
      {:error, :not_your_turn}
    end
  end

  defp execute_action(state, _side, {:move, unit_id, path}) do
    Actions.Move.execute(state, unit_id, path)
  end

  defp execute_action(state, _side, {:attack, attacker_ids, target_coord}) do
    Actions.Combat.execute(state, attacker_ids, target_coord)
  end

  defp execute_action(state, _side, {:hold, unit_id}) do
    Actions.Move.hold(state, unit_id)
  end

  defp execute_action(_state, _side, action) do
    {:error, {:unknown_action, action}}
  end

  defp log_action(state, side, action) do
    entry = %{
      turn: state.turn_state.turn_number,
      phase: TurnState.current_phase(state.turn_state).id,
      side: side,
      action: action,
      timestamp: DateTime.utc_now()
    }

    Map.update(state, :action_log, [entry], fn log -> [entry | log] end)
  end

  defp broadcast(state) do
    # Notify subscribers via optional callback module
    case Application.get_env(:wargame_core, :game_broadcaster) do
      nil -> :ok
      module -> module.broadcast(state.game_id, {:game_update, state})
    end
  end

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
end
