defmodule WargamePersistence.GameStore do
  @moduledoc "Context for game and game action persistence."

  import Ecto.Query
  alias WargamePersistence.Repo
  alias WargamePersistence.Schemas.{Game, GameAction}

  # --- Games ---

  def list_games(opts \\ []) do
    Game
    |> maybe_filter_status(opts[:status])
    |> maybe_preload(opts[:preload])
    |> order_by([g], desc: g.updated_at)
    |> Repo.all()
  end

  def get_game!(id), do: Repo.get!(Game, id)

  def get_game(id), do: Repo.get(Game, id)

  def create_game(attrs) do
    %Game{}
    |> Game.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Serialize and save the current game state binary."
  def save_game_state(%Game{} = game, state) do
    binary = Game.serialize_game_state(state)

    game
    |> Game.changeset(%{game_state: binary})
    |> Repo.update()
  end

  @doc "Load and deserialize the game state."
  def load_game_state(game_id) do
    case get_game(game_id) do
      nil -> nil
      game -> Game.deserialize_game_state(game.game_state)
    end
  end

  @doc "Set the game result and finished_at timestamp."
  def finish_game(%Game{} = game, result) do
    game
    |> Game.changeset(%{
      status: "finished",
      result: result,
      finished_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  # --- Game Actions ---

  @doc "Log a game action."
  def log_action(game_id, action_attrs) do
    attrs = Map.put(action_attrs, :game_id, game_id)

    %GameAction{}
    |> GameAction.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc "Get all actions for a game, ordered for replay."
  def get_action_log(game_id) do
    from(a in GameAction,
      where: a.game_id == ^game_id,
      order_by: [asc: a.turn, asc: a.sequence]
    )
    |> Repo.all()
  end

  # --- Private ---

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [g], g.status == ^status)

  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)
end
