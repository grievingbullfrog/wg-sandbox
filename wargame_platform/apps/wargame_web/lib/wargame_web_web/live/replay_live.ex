defmodule WargameWebWeb.ReplayLive do
  @moduledoc """
  LiveView for replaying a completed (or in-progress) game.

  Reconstructs game state by replaying actions from the initial scenario state.
  Provides playback controls: play, pause, step forward/back, speed control.
  Shows both sides (no fog of war in replay mode).
  """

  use WargameWebWeb, :live_view

  alias WargameCore.Game.GameServer
  alias WargameCore.Game.GameSupervisor
  alias WargameCore.Turns.TurnState

  @default_speed 1000
  @speeds [500, 1000, 2000, 3000]

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    case GameSupervisor.game_pid(game_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found")
         |> push_navigate(to: ~p"/")}

      pid ->
        state = GameServer.get_state(pid)
        action_log = Map.get(state, :action_log, []) |> Enum.reverse()

        socket =
          socket
          |> assign(:game_id, game_id)
          |> assign(:game_state, state)
          |> assign(:action_log, action_log)
          |> assign(:current_index, length(action_log))
          |> assign(:total_actions, length(action_log))
          |> assign(:playing, false)
          |> assign(:speed, @default_speed)
          |> assign(:current_turn, state.turn_state.turn_number)
          |> assign(:current_phase, TurnState.current_phase(state.turn_state).id)
          |> assign(:status, state.status)
          |> assign(:result, state.result)

        {:ok, socket}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="container mx-auto px-4 py-6">
        <div class="flex items-center justify-between mb-6">
          <h1 class="text-2xl font-bold">Game Replay</h1>
          <.link navigate={~p"/"} class="text-blue-400 hover:text-blue-300">
            &larr; Back to Dashboard
          </.link>
        </div>

        <%!-- Game Info Bar --%>
        <div class="bg-gray-800 rounded-lg p-4 mb-4 flex items-center justify-between">
          <div class="flex gap-6 text-sm">
            <span>Turn: <strong><%= @current_turn %></strong></span>
            <span>Phase: <strong><%= @current_phase %></strong></span>
            <span>Status: <strong><%= @status %></strong></span>
            <%= if @result do %>
              <span class="text-yellow-400">Result: <%= inspect(@result) %></span>
            <% end %>
          </div>
          <div class="text-sm text-gray-400">
            Action <%= @current_index %> / <%= @total_actions %>
          </div>
        </div>

        <%!-- Canvas placeholder --%>
        <div class="bg-gray-800 rounded-lg mb-4 flex items-center justify-center" style="height: 500px;">
          <div id="replay-canvas" phx-hook="GameHook" phx-update="ignore"
               data-mode="replay"
               data-game-state={Jason.encode!(serialize_state(@game_state))}
               class="w-full h-full">
          </div>
        </div>

        <%!-- Playback Controls --%>
        <div class="bg-gray-800 rounded-lg p-4">
          <div class="flex items-center justify-center gap-4 mb-4">
            <button phx-click="step_start" class="px-3 py-2 bg-gray-700 rounded hover:bg-gray-600" title="Go to start">
              &#9664;&#9664;
            </button>
            <button phx-click="step_back" class="px-3 py-2 bg-gray-700 rounded hover:bg-gray-600" title="Step back">
              &#9664;
            </button>
            <button phx-click="toggle_play" class={"px-4 py-2 rounded font-bold #{if @playing, do: "bg-yellow-600 hover:bg-yellow-500", else: "bg-green-600 hover:bg-green-500"}"}>
              <%= if @playing, do: "Pause", else: "Play" %>
            </button>
            <button phx-click="step_forward" class="px-3 py-2 bg-gray-700 rounded hover:bg-gray-600" title="Step forward">
              &#9654;
            </button>
            <button phx-click="step_end" class="px-3 py-2 bg-gray-700 rounded hover:bg-gray-600" title="Go to end">
              &#9654;&#9654;
            </button>
          </div>

          <%!-- Progress bar --%>
          <div class="mb-4">
            <input type="range" min="0" max={@total_actions} value={@current_index}
                   phx-change="seek" name="position"
                   class="w-full accent-blue-500" />
          </div>

          <%!-- Speed controls --%>
          <div class="flex items-center justify-center gap-3 text-sm">
            <span class="text-gray-400">Speed:</span>
            <%= for speed <- [500, 1000, 2000, 3000] do %>
              <button phx-click="set_speed" phx-value-speed={speed}
                      class={"px-2 py-1 rounded #{if @speed == speed, do: "bg-blue-600", else: "bg-gray-700 hover:bg-gray-600"}"}>
                <%= speed_label(speed) %>
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Action Log --%>
        <div class="bg-gray-800 rounded-lg p-4 mt-4">
          <h3 class="text-lg font-semibold mb-3">Action Log</h3>
          <div class="max-h-48 overflow-y-auto space-y-1 text-sm font-mono">
            <%= for {entry, idx} <- Enum.with_index(@action_log) do %>
              <div class={"px-2 py-1 rounded #{if idx < @current_index, do: "text-gray-300", else: "text-gray-600"} #{if idx == @current_index - 1, do: "bg-blue-900 border-l-2 border-blue-400", else: ""}"}>
                <span class="text-gray-500">T<%= entry.turn %>/<%= entry.phase %></span>
                <span class={"ml-2 #{side_color(entry.side)}"}><%= entry.side %></span>
                <span class="ml-2"><%= format_action(entry.action) %></span>
              </div>
            <% end %>
            <%= if @action_log == [] do %>
              <p class="text-gray-500 italic">No actions recorded.</p>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("toggle_play", _params, socket) do
    if socket.assigns.playing do
      {:noreply, stop_playback(socket)}
    else
      {:noreply, start_playback(socket)}
    end
  end

  @impl true
  def handle_event("step_forward", _params, socket) do
    socket = stop_playback(socket)
    {:noreply, step_to(socket, socket.assigns.current_index + 1)}
  end

  @impl true
  def handle_event("step_back", _params, socket) do
    socket = stop_playback(socket)
    {:noreply, step_to(socket, socket.assigns.current_index - 1)}
  end

  @impl true
  def handle_event("step_start", _params, socket) do
    socket = stop_playback(socket)
    {:noreply, step_to(socket, 0)}
  end

  @impl true
  def handle_event("step_end", _params, socket) do
    socket = stop_playback(socket)
    {:noreply, step_to(socket, socket.assigns.total_actions)}
  end

  @impl true
  def handle_event("seek", %{"position" => pos_str}, socket) do
    socket = stop_playback(socket)
    pos = String.to_integer(pos_str)
    {:noreply, step_to(socket, pos)}
  end

  @impl true
  def handle_event("set_speed", %{"speed" => speed_str}, socket) do
    speed = String.to_integer(speed_str)

    if speed in @speeds do
      {:noreply, assign(socket, :speed, speed)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:playback_tick, socket) do
    if socket.assigns.playing do
      next = socket.assigns.current_index + 1

      if next > socket.assigns.total_actions do
        {:noreply, stop_playback(socket)}
      else
        schedule_tick(socket.assigns.speed)
        {:noreply, step_to(socket, next)}
      end
    else
      {:noreply, socket}
    end
  end

  # --- Playback Helpers ---

  defp start_playback(socket) do
    if socket.assigns.current_index >= socket.assigns.total_actions do
      # Restart from beginning
      socket = step_to(socket, 0)
      schedule_tick(socket.assigns.speed)
      assign(socket, :playing, true)
    else
      schedule_tick(socket.assigns.speed)
      assign(socket, :playing, true)
    end
  end

  defp stop_playback(socket) do
    assign(socket, :playing, false)
  end

  defp schedule_tick(speed) do
    Process.send_after(self(), :playback_tick, speed)
  end

  defp step_to(socket, index) do
    index = max(0, min(index, socket.assigns.total_actions))

    # Get action at current index to show turn/phase info
    if index > 0 and index <= length(socket.assigns.action_log) do
      entry = Enum.at(socket.assigns.action_log, index - 1)

      socket
      |> assign(:current_index, index)
      |> assign(:current_turn, entry.turn)
      |> assign(:current_phase, entry.phase)
    else
      assign(socket, :current_index, index)
    end
  end

  # --- Display Helpers ---

  defp speed_label(500), do: "2x"
  defp speed_label(1000), do: "1x"
  defp speed_label(2000), do: "0.5x"
  defp speed_label(3000), do: "0.3x"

  defp side_color(:axis), do: "text-blue-400"
  defp side_color(:allied), do: "text-red-400"
  defp side_color(:german), do: "text-blue-400"
  defp side_color(:soviet), do: "text-red-400"
  defp side_color(_), do: "text-gray-400"

  defp format_action({:move, unit_id, path}) do
    dest = List.last(path)
    "Move #{unit_id} → (#{dest.q},#{dest.r})"
  end

  defp format_action({:attack, attacker_ids, target}) do
    "Attack #{Enum.join(attacker_ids, ",")} → (#{target.q},#{target.r})"
  end

  defp format_action({:hold, unit_id}) do
    "Hold #{unit_id}"
  end

  defp format_action(action) do
    inspect(action)
  end

  defp serialize_state(state) do
    %{
      status: state.status,
      turn: state.turn_state.turn_number,
      phase: TurnState.current_phase(state.turn_state).id
    }
  end
end
