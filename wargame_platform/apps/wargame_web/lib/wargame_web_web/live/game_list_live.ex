defmodule WargameWebWeb.GameListLive do
  @moduledoc """
  Lists active and completed games.
  """

  use WargameWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    # For now, show a simple list with link to create new game
    {:ok, assign(socket, :games, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="max-w-4xl mx-auto py-8 px-4">
        <div class="flex justify-between items-center mb-8">
          <h1 class="text-3xl font-bold">Games</h1>
          <.link navigate={~p"/games/new"} class="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium">
            New Game
          </.link>
        </div>

        <div :if={@games == []} class="text-center py-16 text-gray-400">
          <p class="text-lg mb-4">No games yet</p>
          <.link navigate={~p"/games/new"} class="text-blue-400 hover:text-blue-300">
            Start your first game
          </.link>
        </div>

        <div class="mt-8 text-center">
          <.link navigate={~p"/"} class="text-gray-400 hover:text-white text-sm">
            Back to Home
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
