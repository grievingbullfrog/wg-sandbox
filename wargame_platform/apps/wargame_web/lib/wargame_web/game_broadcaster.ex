defmodule WargameWeb.GameBroadcaster do
  @moduledoc """
  Broadcasts game state updates via Phoenix PubSub.

  This module implements the broadcaster interface expected by
  WargameCore.Game.GameServer. It forwards game state updates
  to any subscribed LiveView processes.
  """

  @pubsub WargameWeb.PubSub

  @doc """
  Broadcast a game state update to all subscribers.
  """
  def broadcast(game_id, message) do
    Phoenix.PubSub.broadcast(@pubsub, topic(game_id), message)
  end

  @doc """
  Subscribe the current process to game updates.
  """
  def subscribe(game_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(game_id))
  end

  @doc """
  Unsubscribe the current process from game updates.
  """
  def unsubscribe(game_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(game_id))
  end

  defp topic(game_id), do: "game:#{game_id}"
end
