defmodule WargameCore.Game.GameSupervisor do
  @moduledoc """
  DynamicSupervisor for managing active game processes.

  Each active game runs as a `GameServer` GenServer under this supervisor.
  """

  use DynamicSupervisor

  alias WargameCore.Game.GameServer

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new game from a scenario.

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  def start_game(supervisor \\ __MODULE__, scenario, opts \\ []) do
    game_id = Keyword.get(opts, :game_id, generate_id())

    child_spec = {GameServer, [
      scenario: scenario,
      game_id: game_id,
      name: via_tuple(game_id)
    ]}

    case DynamicSupervisor.start_child(supervisor, child_spec) do
      {:ok, pid} -> {:ok, pid, game_id}
      {:error, _} = error -> error
    end
  end

  @doc """
  Stops a running game.
  """
  def stop_game(supervisor \\ __MODULE__, game_id) do
    case Registry.lookup(WargameCore.Game.Registry, game_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(supervisor, pid)
      [] -> {:error, :game_not_found}
    end
  end

  @doc """
  Returns the PID for a game by ID, or nil if not running.
  """
  def game_pid(game_id) do
    case Registry.lookup(WargameCore.Game.Registry, game_id) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  defp via_tuple(game_id) do
    {:via, Registry, {WargameCore.Game.Registry, game_id}}
  end

  defp generate_id, do: :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
end
