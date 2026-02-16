defmodule WargameWebWeb.GameListLive do
  @moduledoc "Dashboard showing all active and completed games."

  use WargameWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    games =
      WargamePersistence.GameStore.list_games(
        preload: [scenario: [:game_product]]
      )

    active = Enum.filter(games, &(&1.status in ["setup", "playing", "paused"]))
    finished = Enum.filter(games, &(&1.status == "finished"))

    socket =
      socket
      |> assign(:active_games, active)
      |> assign(:finished_games, finished)
      |> assign(:page_title, "My Games")
      |> assign(:show_finished, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <%!-- Navigation Bar --%>
      <nav class="bg-gray-800 border-b border-gray-700">
        <div class="max-w-6xl mx-auto px-4 h-14 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.link navigate={~p"/"} class="text-sm text-gray-400 hover:text-white transition-colors">
              &larr; Home
            </.link>
            <span class="text-gray-600">|</span>
            <span class="text-lg font-bold text-white">My Games</span>
          </div>
          <.link navigate={~p"/games/new"} class="px-3 py-1.5 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium">
            New Game
          </.link>
        </div>
      </nav>

      <div class="max-w-4xl mx-auto px-4 py-8">
        <%!-- Active Games --%>
        <div class="mb-8">
          <h2 class="text-xl font-bold mb-4">
            Active Games
            <span class="text-sm font-normal text-gray-500 ml-2">{length(@active_games)}</span>
          </h2>

          <div :if={@active_games == []} class="bg-gray-800 rounded-lg border border-gray-700 p-8 text-center text-gray-500">
            <p class="mb-3">No active games</p>
            <.link navigate={~p"/"} class="text-blue-400 hover:text-blue-300 text-sm">
              Browse games to start playing
            </.link>
          </div>

          <div class="space-y-3">
            <.game_card :for={game <- @active_games} game={game} />
          </div>
        </div>

        <%!-- Finished Games --%>
        <div :if={@finished_games != []}>
          <button
            phx-click="toggle_finished"
            class="flex items-center gap-2 text-sm text-gray-400 hover:text-white mb-4"
          >
            <svg class={"w-4 h-4 transition-transform #{if @show_finished, do: "rotate-90"}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
            Finished Games
            <span class="text-gray-600">({length(@finished_games)})</span>
          </button>

          <div :if={@show_finished} class="space-y-3">
            <.game_card :for={game <- @finished_games} game={game} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :game, :map, required: true

  defp game_card(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-lg border border-gray-700 p-4 flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 mb-1">
          <span class={"w-2 h-2 rounded-full #{status_color(@game.status)}"}></span>
          <span class="font-medium">
            {scenario_name(@game)}
          </span>
          <span class="text-xs text-gray-500 px-1.5 py-0.5 bg-gray-700 rounded">
            {@game.status}
          </span>
        </div>
        <div class="flex gap-4 text-xs text-gray-500">
          <span :if={@game.current_turn > 0}>Turn {@game.current_turn}</span>
          <span :if={product_name(@game)}>
            {product_name(@game)}
          </span>
          <span>
            Updated {format_time(@game.updated_at)}
          </span>
        </div>
      </div>
      <div class="flex gap-2">
        <.link
          :if={@game.status in ["playing", "paused"]}
          navigate={~p"/game/#{@game.id}"}
          class="px-3 py-1.5 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium"
        >
          Resume
        </.link>
        <.link
          :if={@game.status == "finished"}
          navigate={~p"/game/#{@game.id}/replay"}
          class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 rounded text-sm text-gray-300"
        >
          Replay
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_finished", _params, socket) do
    {:noreply, update(socket, :show_finished, &(!&1))}
  end

  defp scenario_name(%{scenario: %{name: name}}) when is_binary(name), do: name
  defp scenario_name(_), do: "Unknown Scenario"

  defp product_name(%{scenario: %{game_product: %{name: name}}}) when is_binary(name), do: name
  defp product_name(_), do: nil

  defp status_color("playing"), do: "bg-green-500"
  defp status_color("paused"), do: "bg-yellow-500"
  defp status_color("setup"), do: "bg-blue-500"
  defp status_color("finished"), do: "bg-gray-500"
  defp status_color(_), do: "bg-gray-500"

  defp format_time(nil), do: "never"

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end
end
