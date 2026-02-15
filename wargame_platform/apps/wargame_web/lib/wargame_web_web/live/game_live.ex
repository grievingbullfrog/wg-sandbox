defmodule WargameWebWeb.GameLive do
  @moduledoc """
  LiveView for playing a wargame.

  Manages the game canvas, unit display, movement, combat, and phase transitions.
  Communicates with a GameServer process and pushes state updates to the PixiJS
  renderer via the GameHook.
  """

  use WargameWebWeb, :live_view

  alias WargameCore.Game.{GameServer, GameSupervisor}
  alias WargameCore.Hex.{Coord, Grid}
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Map.Tile
  alias WargameCore.Turns.TurnState

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    # Try to find a running game
    case GameSupervisor.game_pid(game_id) do
      nil ->
        {:ok, push_navigate(socket, to: ~p"/games/new")}

      pid ->
        if connected?(socket) do
          WargameWeb.GameBroadcaster.subscribe(game_id)
        end

        state = GameServer.get_state(pid)
        socket = init_assigns(socket, game_id, pid, state, :axis)
        {:ok, socket}
    end
  end

  def mount(%{"scenario_id" => scenario_id}, _session, socket) do
    # Start a new game from a scenario ID
    scenario = build_scenario_from_db(scenario_id)

    case scenario do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Scenario not found")
         |> push_navigate(to: ~p"/games/new")}

      scenario ->
        {:ok, _pid, game_id} = GameSupervisor.start_game(scenario)

        {:ok, push_navigate(socket, to: ~p"/game/#{game_id}")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: ~p"/games/new")}
  end

  defp init_assigns(socket, game_id, pid, state, player_side) do
    phase = TurnState.current_phase(state.turn_state)

    socket
    |> assign(:game_id, game_id)
    |> assign(:game_pid, pid)
    |> assign(:player_side, player_side)
    |> assign(:game_state, state)
    |> assign(:selected_unit, nil)
    |> assign(:action_mode, nil)
    |> assign(:current_turn, state.turn_state.turn_number)
    |> assign(:current_phase, phase.id)
    |> assign(:active_side, state.turn_state.active_side)
    |> assign(:weather, state.weather)
    |> assign(:status, state.status)
    |> assign(:result, state.result)
    |> assign(:hovered_hex, nil)
    |> assign(:combat_log, [])
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900 text-white">
      <%!-- Top Status Bar --%>
      <header class="bg-gray-800 px-4 py-2 flex justify-between items-center border-b border-gray-700">
        <div class="flex items-center gap-4">
          <h1 class="text-lg font-bold">Wargame</h1>
          <span class="text-sm px-2 py-0.5 bg-gray-700 rounded">
            Turn {@current_turn}
          </span>
          <span class={"text-sm px-2 py-0.5 rounded #{phase_color(@current_phase)}"}>
            {phase_label(@current_phase)}
          </span>
          <span class={"text-sm px-2 py-0.5 rounded #{side_color(@active_side)}"}>
            {side_label(@active_side)}
          </span>
          <span :if={@weather} class="text-sm text-gray-400">
            {weather_label(@weather)}
          </span>
        </div>
        <div class="flex items-center gap-2 text-sm">
          <span :if={@status == :finished} class="text-yellow-400 font-bold">
            Game Over
            <span :if={@result}>- {@result.winner} {victory_level(@result)}</span>
          </span>
          <span :if={@hovered_hex} class="text-gray-400">
            ({@hovered_hex.q}, {@hovered_hex.r})
          </span>
        </div>
      </header>

      <div class="flex-1 flex overflow-hidden">
        <%!-- Left Panel: Unit List --%>
        <aside class="w-56 bg-gray-800 border-r border-gray-700 overflow-y-auto flex-shrink-0">
          <div class="p-2 text-xs font-bold text-gray-400 uppercase border-b border-gray-700">
            Your Units
          </div>
          <ul class="divide-y divide-gray-700">
            <li
              :for={unit <- player_units(@game_state, @player_side)}
              class={"px-2 py-1.5 cursor-pointer hover:bg-gray-700 text-sm #{if @selected_unit == unit.id, do: "bg-gray-600", else: ""}"}
              phx-click="select_unit"
              phx-value-id={unit.id}
            >
              <div class="flex justify-between">
                <span class="font-medium truncate">{unit.name}</span>
                <span class="text-gray-400 text-xs">{unit.strength}/{unit.max_strength}</span>
              </div>
              <div class="text-xs text-gray-400">
                {unit_status_text(unit)}
              </div>
            </li>
          </ul>
        </aside>

        <%!-- Center: Game Canvas --%>
        <main class="flex-1 relative">
          <div id="game-canvas-wrapper" phx-hook="GameHook" phx-update="ignore" class="w-full h-full">
            <canvas
              id="game-canvas"
              class="w-full h-full"
              data-hex-size="40"
            />
          </div>
        </main>

        <%!-- Right Panel: Selected Unit Detail --%>
        <aside class="w-64 bg-gray-800 border-l border-gray-700 overflow-y-auto flex-shrink-0">
          <div :if={@selected_unit && get_unit(@game_state, @selected_unit)}>
            <% unit = get_unit(@game_state, @selected_unit) %>
            <div class="p-3 border-b border-gray-700">
              <h3 class="font-bold text-sm">{unit.name}</h3>
              <div class="text-xs text-gray-400 mt-1">
                {String.capitalize(to_string(unit.category))} - {String.capitalize(to_string(unit.unit_size))}
              </div>
            </div>
            <div class="p-3 grid grid-cols-2 gap-2 text-xs">
              <div>
                <span class="text-gray-400">Soft Atk:</span>
                <span class="font-mono ml-1">{unit.attack_soft}</span>
              </div>
              <div>
                <span class="text-gray-400">Hard Atk:</span>
                <span class="font-mono ml-1">{unit.attack_hard}</span>
              </div>
              <div>
                <span class="text-gray-400">Defense:</span>
                <span class="font-mono ml-1">{unit.defense}</span>
              </div>
              <div>
                <span class="text-gray-400">Armor:</span>
                <span class="font-mono ml-1">{unit.armor}</span>
              </div>
              <div>
                <span class="text-gray-400">Strength:</span>
                <span class="font-mono ml-1">{unit.strength}/{unit.max_strength}</span>
              </div>
              <div>
                <span class="text-gray-400">Morale:</span>
                <span class="font-mono ml-1">{unit.morale}</span>
              </div>
              <div>
                <span class="text-gray-400">Movement:</span>
                <span class="font-mono ml-1">{unit.movement_remaining}/{unit.movement_points}</span>
              </div>
              <div>
                <span class="text-gray-400">Range:</span>
                <span class="font-mono ml-1">{unit.range}</span>
              </div>
              <div>
                <span class="text-gray-400">Experience:</span>
                <span class="font-mono ml-1">{unit.experience}</span>
              </div>
              <div>
                <span class="text-gray-400">Entrench:</span>
                <span class="font-mono ml-1">{unit.entrenchment}</span>
              </div>
            </div>
            <div :if={unit_has_status?(unit)} class="px-3 pb-2 flex gap-1 flex-wrap">
              <span :if={unit.is_disrupted} class="text-xs px-1.5 py-0.5 bg-yellow-900 text-yellow-300 rounded">
                Disrupted
              </span>
              <span :if={unit.is_routed} class="text-xs px-1.5 py-0.5 bg-red-900 text-red-300 rounded">
                Routed
              </span>
              <span :if={Map.get(unit, :is_unsupplied, false)} class="text-xs px-1.5 py-0.5 bg-orange-900 text-orange-300 rounded">
                Unsupplied
              </span>
              <span :if={unit.has_attacked} class="text-xs px-1.5 py-0.5 bg-purple-900 text-purple-300 rounded">
                Attacked
              </span>
              <span :if={unit.has_moved} class="text-xs px-1.5 py-0.5 bg-blue-900 text-blue-300 rounded">
                Moved
              </span>
            </div>
          </div>

          <%!-- Combat Log --%>
          <div class="border-t border-gray-700">
            <div class="p-2 text-xs font-bold text-gray-400 uppercase">
              Combat Log
            </div>
            <div class="px-2 pb-2 text-xs text-gray-300 space-y-1 max-h-40 overflow-y-auto">
              <div :for={entry <- Enum.take(@combat_log, 10)} class="border-l-2 border-gray-600 pl-2">
                {entry}
              </div>
              <div :if={@combat_log == []} class="text-gray-500 italic">
                No combat yet
              </div>
            </div>
          </div>
        </aside>
      </div>

      <%!-- Bottom Action Bar --%>
      <footer class="bg-gray-800 border-t border-gray-700 px-4 py-2 flex justify-between items-center">
        <div class="flex gap-2">
          <button
            :if={is_my_turn?(assigns) && @current_phase == :movement}
            phx-click="set_mode"
            phx-value-mode="move"
            class={"px-3 py-1 text-sm rounded #{if @action_mode == :move, do: "bg-green-600", else: "bg-gray-600 hover:bg-gray-500"}"}
          >
            Move
          </button>
          <button
            :if={is_my_turn?(assigns) && @current_phase == :combat}
            phx-click="set_mode"
            phx-value-mode="attack"
            class={"px-3 py-1 text-sm rounded #{if @action_mode == :attack, do: "bg-red-600", else: "bg-gray-600 hover:bg-gray-500"}"}
          >
            Attack
          </button>
          <button
            :if={is_my_turn?(assigns) && @current_phase in [:movement, :exploitation]}
            phx-click="set_mode"
            phx-value-mode="hold"
            class={"px-3 py-1 text-sm rounded #{if @action_mode == :hold, do: "bg-yellow-600", else: "bg-gray-600 hover:bg-gray-500"}"}
          >
            Hold/Entrench
          </button>
        </div>

        <div class="flex gap-2">
          <button
            :if={is_my_turn?(assigns) && @status != :finished}
            phx-click="end_phase"
            class="px-4 py-1.5 text-sm bg-blue-600 hover:bg-blue-500 rounded font-medium"
          >
            End {phase_label(@current_phase)}
          </button>
        </div>
      </footer>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("game_canvas_ready", _params, socket) do
    {:noreply, push_game_state(socket)}
  end

  def handle_event("request_game_state", _params, socket) do
    {:noreply, push_game_state(socket)}
  end

  def handle_event("hex_selected", %{"q" => q, "r" => r} = params, socket) do
    coord = Coord.new(q, r)
    shift = Map.get(params, "shift", false)
    socket = handle_hex_click(socket, coord, shift)
    {:noreply, socket}
  end

  def handle_event("hex_hovered", %{"q" => q, "r" => r}, socket) do
    coord = Coord.new(q, r)
    socket = assign(socket, :hovered_hex, coord)

    # Show path preview for movement mode
    socket =
      if socket.assigns.action_mode == :move && socket.assigns.selected_unit do
        show_path_preview(socket, coord)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("select_unit", %{"id" => unit_id}, socket) do
    socket = select_unit(socket, unit_id)
    {:noreply, socket}
  end

  def handle_event("set_mode", %{"mode" => mode}, socket) do
    action_mode = String.to_existing_atom(mode)
    socket = assign(socket, :action_mode, action_mode)

    socket =
      if action_mode == :hold && socket.assigns.selected_unit do
        execute_hold(socket, socket.assigns.selected_unit)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("end_phase", _params, socket) do
    pid = socket.assigns.game_pid
    side = socket.assigns.player_side

    case GameServer.end_phase(pid, side) do
      {:ok, new_state} ->
        socket = update_game_state(socket, new_state)
        socket = assign(socket, :action_mode, nil)
        socket = assign(socket, :selected_unit, nil)
        {:noreply, push_event(socket, "clear_selection", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Cannot end phase: #{inspect(reason)}")}
    end
  end

  # --- PubSub Handler ---

  @impl true
  def handle_info({:game_update, new_state}, socket) do
    socket = update_game_state(socket, new_state)
    {:noreply, push_units_update(socket)}
  end

  # --- Private Helpers ---

  defp handle_hex_click(socket, coord, _shift) do
    state = socket.assigns.game_state

    case socket.assigns.action_mode do
      :move ->
        handle_move_click(socket, coord, state)

      :attack ->
        handle_attack_click(socket, coord, state)

      _ ->
        # Default: select unit at hex
        case units_at(state, coord) do
          [unit_id | _] -> select_unit(socket, unit_id)
          [] -> assign(socket, :selected_unit, nil)
        end
    end
  end

  defp handle_move_click(socket, coord, state) do
    case socket.assigns.selected_unit do
      nil ->
        # Select a unit first
        case units_at(state, coord) do
          [unit_id | _] -> select_unit(socket, unit_id)
          [] -> socket
        end

      unit_id ->
        unit = state.units[unit_id]

        if unit && unit.position != coord do
          # Build path and execute move
          path = build_path(unit.position, coord)
          execute_move(socket, unit_id, path)
        else
          # Clicked on same hex or no unit - deselect
          assign(socket, :selected_unit, nil)
        end
    end
  end

  defp handle_attack_click(socket, coord, state) do
    case socket.assigns.selected_unit do
      nil ->
        case units_at(state, coord) do
          [unit_id | _] -> select_unit(socket, unit_id)
          [] -> socket
        end

      unit_id ->
        # Check if target hex has enemy units
        enemy_side = other_side(socket.assigns.player_side)

        enemy_at_target =
          state.units
          |> Enum.any?(fn {_id, u} ->
            u.position == coord && u.side == enemy_side
          end)

        if enemy_at_target do
          execute_attack(socket, [unit_id], coord)
        else
          socket
        end
    end
  end

  defp select_unit(socket, unit_id) do
    state = socket.assigns.game_state
    unit = state.units[unit_id]

    socket = assign(socket, :selected_unit, unit_id)

    # Push selection highlight to canvas
    socket =
      if unit do
        socket
        |> push_event("clear_selection", %{})
        |> push_event("highlight_hexes", %{
          coords: [%{q: unit.position.q, r: unit.position.r}],
          mode: "selected"
        })
        |> maybe_show_reachable(unit)
      else
        socket
      end

    socket
  end

  defp maybe_show_reachable(socket, unit) do
    state = socket.assigns.game_state
    phase = TurnState.current_phase(state.turn_state)

    if phase.id in [:movement, :exploitation] &&
         unit.side == socket.assigns.player_side &&
         unit.movement_remaining > 0 &&
         !unit.has_moved do
      reachable = GameMap.reachable_hexes(state.map, unit.position, unit.movement_remaining, unit.category)

      hexes =
        Enum.map(reachable, fn {coord, cost} ->
          %{
            q: coord.q,
            r: coord.r,
            cost: cost,
            maxCost: unit.movement_remaining
          }
        end)

      push_event(socket, "show_reachable", %{hexes: hexes})
    else
      socket
    end
  end

  defp show_path_preview(socket, target_coord) do
    case socket.assigns.selected_unit do
      nil ->
        socket

      unit_id ->
        unit = socket.assigns.game_state.units[unit_id]

        if unit do
          path = build_path(unit.position, target_coord)

          path_data =
            Enum.map(path, fn coord -> %{q: coord.q, r: coord.r} end)

          push_event(socket, "show_path", %{path: path_data})
        else
          socket
        end
    end
  end

  defp execute_move(socket, unit_id, path) do
    pid = socket.assigns.game_pid
    side = socket.assigns.player_side

    case GameServer.perform_action(pid, side, {:move, unit_id, path}) do
      {:ok, new_state} ->
        socket
        |> update_game_state(new_state)
        |> push_units_update()
        |> push_event("clear_selection", %{})

      {:error, reason} ->
        put_flash(socket, :error, "Move failed: #{inspect(reason)}")
    end
  end

  defp execute_attack(socket, attacker_ids, target_coord) do
    pid = socket.assigns.game_pid
    side = socket.assigns.player_side

    case GameServer.perform_action(pid, side, {:attack, attacker_ids, target_coord}) do
      {:ok, new_state} ->
        # Add combat result to log
        combat_entry = format_combat_result(socket.assigns.game_state, new_state, attacker_ids, target_coord)

        socket
        |> update_game_state(new_state)
        |> update(:combat_log, fn log -> [combat_entry | log] end)
        |> push_units_update()
        |> push_event("combat_result", %{
          result: "combat",
          targetHex: %{q: target_coord.q, r: target_coord.r}
        })
        |> push_event("clear_selection", %{})

      {:error, reason} ->
        put_flash(socket, :error, "Attack failed: #{inspect(reason)}")
    end
  end

  defp execute_hold(socket, unit_id) do
    pid = socket.assigns.game_pid
    side = socket.assigns.player_side

    case GameServer.perform_action(pid, side, {:hold, unit_id}) do
      {:ok, new_state} ->
        socket
        |> update_game_state(new_state)
        |> push_units_update()

      {:error, reason} ->
        put_flash(socket, :error, "Hold failed: #{inspect(reason)}")
    end
  end

  defp update_game_state(socket, new_state) do
    phase = TurnState.current_phase(new_state.turn_state)

    socket
    |> assign(:game_state, new_state)
    |> assign(:current_turn, new_state.turn_state.turn_number)
    |> assign(:current_phase, phase.id)
    |> assign(:active_side, new_state.turn_state.active_side)
    |> assign(:weather, new_state.weather)
    |> assign(:status, new_state.status)
    |> assign(:result, new_state.result)
  end

  defp push_game_state(socket) do
    state = socket.assigns.game_state
    tiles = map_to_tiles(state.map)
    units = units_to_json(state)

    push_event(socket, "render_game", %{
      tiles: tiles,
      units: units,
      width: state.map.width,
      height: state.map.height
    })
  end

  defp push_units_update(socket) do
    state = socket.assigns.game_state
    units = units_to_json(state)
    push_event(socket, "update_units", %{units: units})
  end

  # --- Data Serialization ---

  defp map_to_tiles(map) do
    map
    |> GameMap.all_tiles()
    |> Enum.map(&tile_to_json/1)
  end

  defp tile_to_json(%Tile{} = tile) do
    %{
      coord: %{q: tile.coord.q, r: tile.coord.r},
      terrain: Atom.to_string(tile.terrain),
      elevation: tile.elevation,
      edges: edges_to_json(tile.edges),
      overlays: Enum.map(tile.overlays, &Atom.to_string/1),
      control: if(tile.control, do: Atom.to_string(tile.control), else: nil),
      victoryPoints: tile.victory_points,
      name: tile.name
    }
  end

  defp edges_to_json(edges) do
    edges
    |> Enum.map(fn {dir, features} ->
      {Integer.to_string(dir), Enum.map(features, &Atom.to_string/1)}
    end)
    |> Enum.into(%{})
  end

  defp units_to_json(state) do
    state.units
    |> Enum.map(fn {_id, unit} -> unit_to_json(unit) end)
  end

  defp unit_to_json(unit) do
    %{
      id: unit.id,
      name: unit.name,
      side: to_string(unit.side),
      force: to_string(unit.force),
      category: to_string(unit.category),
      unitSize: to_string(unit.unit_size),
      position: %{q: unit.position.q, r: unit.position.r},
      attackSoft: unit.attack_soft,
      attackHard: unit.attack_hard,
      defense: unit.defense,
      strength: unit.strength,
      maxStrength: unit.max_strength,
      movement: unit.movement_remaining,
      maxMovement: unit.movement_points,
      morale: unit.morale,
      experience: unit.experience,
      isDisrupted: unit.is_disrupted,
      isRouted: unit.is_routed,
      isEntrenched: unit.entrenchment > 0,
      isUnsupplied: Map.get(unit, :is_unsupplied, false),
      hasAttacked: unit.has_attacked,
      hasMoved: unit.has_moved,
      isSelected: false
    }
  end

  # --- View Helpers ---

  defp player_units(state, side) do
    state.units
    |> Enum.filter(fn {_id, u} -> u.side == side end)
    |> Enum.map(fn {_id, u} -> u end)
    |> Enum.sort_by(& &1.name)
  end

  defp get_unit(state, unit_id) do
    Map.get(state.units, unit_id)
  end

  defp units_at(state, coord) do
    state.units
    |> Enum.filter(fn {_id, u} -> u.position == coord end)
    |> Enum.map(fn {id, _u} -> id end)
  end

  defp build_path(from, to) do
    # Simple straight-line path for now - the rules engine validates
    Grid.line_draw(from, to)
  end

  defp other_side(:axis), do: :allied
  defp other_side(:allied), do: :axis

  defp is_my_turn?(assigns) do
    assigns.active_side == assigns.player_side && assigns.status != :finished
  end

  defp unit_status_text(unit) do
    parts =
      [
        if(unit.has_moved, do: "Moved"),
        if(unit.has_attacked, do: "Attacked"),
        if(unit.is_disrupted, do: "Disrupted"),
        if(unit.is_routed, do: "Routed"),
        if(unit.entrenchment > 0, do: "Entrenched(#{unit.entrenchment})")
      ]
      |> Enum.reject(&is_nil/1)

    if parts == [], do: "Ready", else: Enum.join(parts, " | ")
  end

  defp unit_has_status?(unit) do
    unit.is_disrupted || unit.is_routed || Map.get(unit, :is_unsupplied, false) ||
      unit.has_attacked || unit.has_moved
  end

  defp phase_label(:command), do: "Command"
  defp phase_label(:movement), do: "Movement"
  defp phase_label(:combat), do: "Combat"
  defp phase_label(:exploitation), do: "Exploitation"
  defp phase_label(:supply), do: "Supply"
  defp phase_label(:end_phase), do: "End Phase"
  defp phase_label(other), do: to_string(other)

  defp phase_color(:command), do: "bg-purple-700"
  defp phase_color(:movement), do: "bg-green-700"
  defp phase_color(:combat), do: "bg-red-700"
  defp phase_color(:exploitation), do: "bg-orange-700"
  defp phase_color(:supply), do: "bg-blue-700"
  defp phase_color(:end_phase), do: "bg-gray-700"
  defp phase_color(_), do: "bg-gray-700"

  defp side_label(:axis), do: "Axis"
  defp side_label(:allied), do: "Allied"
  defp side_label(other), do: to_string(other)

  defp side_color(:axis), do: "bg-blue-800"
  defp side_color(:allied), do: "bg-red-800"
  defp side_color(_), do: "bg-gray-700"

  defp weather_label(%{weather: w, ground: g}) do
    "#{String.capitalize(to_string(w))} / #{String.capitalize(to_string(g))}"
  end

  defp weather_label(_), do: ""

  defp victory_level(%{level: level}), do: "(#{level})"
  defp victory_level(_), do: ""

  defp format_combat_result(_old_state, _new_state, attacker_ids, target_coord) do
    "T#{DateTime.utc_now().minute}: #{length(attacker_ids)} unit(s) attack (#{target_coord.q},#{target_coord.r})"
  end

  defp build_scenario_from_db(scenario_id) do
    case WargamePersistence.Scenarios.load_full_scenario(scenario_id) do
      nil -> nil
      _db_scenario ->
        # TODO: Convert DB scenario to WargameCore.Scenario.Scenario struct
        # For now this is a placeholder - full conversion will come in Phase 6
        nil
    end
  end
end
