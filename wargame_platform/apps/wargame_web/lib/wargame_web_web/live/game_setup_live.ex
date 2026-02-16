defmodule WargameWebWeb.GameSetupLive do
  @moduledoc """
  Game setup / lobby page.

  Allows players to select a scenario, choose a side, configure settings,
  and start a new game.
  """

  use WargameWebWeb, :live_view

  alias WargameCore.Game.GameSupervisor
  alias WargameCore.Scenario.{Scenario, ActionProfile, ScenarioLoader}
  alias WargameCore.Units.UnitTemplate
  alias WargameCore.Hex.Coord
  alias WargameCore.Map, as: GameMap
  alias WargameCore.Map.Tile

  @impl true
  def mount(params, _session, socket) do
    # Load available scenarios from DB
    scenarios = WargamePersistence.Scenarios.list_scenarios()

    # Pre-select scenario if specified via query param
    selected =
      case params["scenario_id"] do
        nil -> nil
        id -> Enum.find(scenarios, &(&1.id == id))
      end

    product_slug = params["product_slug"]

    socket =
      socket
      |> assign(:scenarios, scenarios)
      |> assign(:selected_scenario, selected)
      |> assign(:player_side, :axis)
      |> assign(:fog_of_war, false)
      |> assign(:quick_start, false)
      |> assign(:product_slug, product_slug)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <div class="max-w-4xl mx-auto py-8 px-4">
        <h1 class="text-3xl font-bold mb-8">New Game</h1>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <%!-- Scenario Selection --%>
          <div class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold mb-4">Select Scenario</h2>

            <div :if={@scenarios == []} class="text-gray-400 text-sm mb-4">
              No scenarios in database yet. Use Quick Start to play a test game.
            </div>

            <ul class="space-y-2 mb-4">
              <li
                :for={scenario <- @scenarios}
                class={"p-3 rounded cursor-pointer border #{if @selected_scenario && @selected_scenario.id == scenario.id, do: "border-blue-500 bg-gray-700", else: "border-gray-700 hover:border-gray-500"}"}
                phx-click="select_scenario"
                phx-value-id={scenario.id}
              >
                <div class="font-medium">{scenario.name}</div>
                <div class="text-xs text-gray-400">
                  {scenario.era} | {scenario.max_turns} turns
                </div>
              </li>
            </ul>

            <div class="border-t border-gray-700 pt-4 mt-4">
              <button
                phx-click="quick_start"
                class="w-full px-4 py-2 bg-green-700 hover:bg-green-600 rounded text-sm font-medium"
              >
                Quick Start (Test Scenario)
              </button>
              <p class="text-xs text-gray-500 mt-2">
                Starts a small test game with preset units for testing.
              </p>
            </div>
          </div>

          <%!-- Game Settings --%>
          <div class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold mb-4">Settings</h2>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-1">Play As</label>
                <div class="flex gap-2">
                  <button
                    phx-click="set_side"
                    phx-value-side="axis"
                    class={"px-4 py-2 rounded text-sm #{if @player_side == :axis, do: "bg-blue-600", else: "bg-gray-700 hover:bg-gray-600"}"}
                  >
                    Axis
                  </button>
                  <button
                    phx-click="set_side"
                    phx-value-side="allied"
                    class={"px-4 py-2 rounded text-sm #{if @player_side == :allied, do: "bg-red-600", else: "bg-gray-700 hover:bg-gray-600"}"}
                  >
                    Allied
                  </button>
                </div>
              </div>

              <div>
                <label class="flex items-center gap-2 text-sm text-gray-300">
                  <input
                    type="checkbox"
                    checked={@fog_of_war}
                    phx-click="toggle_fog"
                    class="rounded bg-gray-700 border-gray-600"
                  />
                  Fog of War
                </label>
              </div>
            </div>

            <div class="mt-8">
              <button
                :if={@selected_scenario}
                phx-click="start_game"
                class="w-full px-4 py-3 bg-blue-600 hover:bg-blue-500 rounded font-bold text-lg"
              >
                Start Game
              </button>
              <div :if={!@selected_scenario && !@quick_start} class="text-gray-500 text-sm text-center">
                Select a scenario or use Quick Start
              </div>
            </div>
          </div>
        </div>

        <%!-- Back Link --%>
        <div class="mt-8 text-center">
          <.link :if={@product_slug} navigate={~p"/products/#{@product_slug}"} class="text-gray-400 hover:text-white text-sm">
            &larr; Back to Scenarios
          </.link>
          <.link :if={!@product_slug} navigate={~p"/"} class="text-gray-400 hover:text-white text-sm">
            &larr; Back to Home
          </.link>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_scenario", %{"id" => id}, socket) do
    scenario = Enum.find(socket.assigns.scenarios, &(&1.id == id))
    {:noreply, assign(socket, :selected_scenario, scenario)}
  end

  def handle_event("set_side", %{"side" => side}, socket) do
    {:noreply, assign(socket, :player_side, String.to_existing_atom(side))}
  end

  def handle_event("toggle_fog", _params, socket) do
    {:noreply, update(socket, :fog_of_war, &(!&1))}
  end

  def handle_event("start_game", _params, socket) do
    db_scenario = socket.assigns.selected_scenario

    case WargamePersistence.Scenarios.load_full_scenario(db_scenario.id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Scenario not found")}

      full_scenario ->
        core_scenario = ScenarioLoader.from_db_scenario(full_scenario)

        case GameSupervisor.start_game(core_scenario) do
          {:ok, _pid, game_id} ->
            {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
        end
    end
  end

  def handle_event("quick_start", _params, socket) do
    scenario = build_test_scenario()

    case GameSupervisor.start_game(scenario) do
      {:ok, _pid, game_id} ->
        {:noreply, push_navigate(socket, to: ~p"/game/#{game_id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start: #{inspect(reason)}")}
    end
  end

  # --- Test Scenario Builder ---

  defp build_test_scenario do
    infantry = %UnitTemplate{
      id: "inf", name: "Infantry", nationality: "german", era: "ww2",
      category: :infantry, unit_size: :platoon, icon_type: "infantry",
      attack_soft: 6, attack_hard: 2, defense: 5, armor: 0,
      movement_points: 4, movement_type: :foot, range: 1,
      spotting: 3, initiative: 3, max_strength: 10,
      max_ammo: 10, max_fuel: 0,
      can_bridge: false, can_entrench: true, is_organic_transport: false
    }

    armor = %UnitTemplate{
      id: "pz", name: "Panzer IV", nationality: "german", era: "ww2",
      category: :armor, unit_size: :company, icon_type: "armor",
      attack_soft: 4, attack_hard: 12, defense: 8, armor: 6,
      movement_points: 8, movement_type: :tracked, range: 2,
      spotting: 4, initiative: 5, max_strength: 10,
      max_ammo: 8, max_fuel: 12,
      can_bridge: false, can_entrench: false, is_organic_transport: false
    }

    soviet_inf = %UnitTemplate{
      id: "sov_inf", name: "Rifle", nationality: "soviet", era: "ww2",
      category: :infantry, unit_size: :platoon, icon_type: "infantry",
      attack_soft: 5, attack_hard: 2, defense: 4, armor: 0,
      movement_points: 4, movement_type: :foot, range: 1,
      spotting: 3, initiative: 2, max_strength: 10,
      max_ammo: 10, max_fuel: 0,
      can_bridge: false, can_entrench: true, is_organic_transport: false
    }

    # 10x8 map with mixed terrain
    tiles =
      for q <- 0..9, r <- 0..7, into: %{} do
        coord = Coord.new(q, r)
        terrain = test_terrain(q, r)
        vp = if (q == 5 && r == 4) || (q == 3 && r == 3), do: 10, else: 0
        {coord, Tile.new(coord, terrain, victory_points: vp)}
      end

    game_map = %GameMap{
      id: "test", name: "Test Battlefield", width: 10, height: 8, scale: "500m", tiles: tiles
    }

    Scenario.new(%{
      id: "quick-test",
      name: "Quick Test Battle",
      era: "ww2",
      map: game_map,
      action_profile: ActionProfile.ww2_standard(),
      sides: [
        %{id: :axis, name: "Axis", forces: [:german]},
        %{id: :allied, name: "Allied", forces: [:soviet]}
      ],
      first_move: :axis,
      max_turns: 6,
      templates: %{"inf" => infantry, "pz" => armor, "sov_inf" => soviet_inf},
      scenario_units: [
        # German forces (west)
        %{id: "g_inf1", name: "1st Grenadier", template_id: "inf",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 2)},
        %{id: "g_inf2", name: "2nd Grenadier", template_id: "inf",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 3)},
        %{id: "g_inf3", name: "3rd Grenadier", template_id: "inf",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 5)},
        %{id: "g_pz1", name: "1st Panzer", template_id: "pz",
          side: :axis, force: :german, arrives_turn: 1, deploy_hex: Coord.new(1, 4)},
        # Soviet forces (east)
        %{id: "s_inf1", name: "1st Rifle", template_id: "sov_inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(8, 2)},
        %{id: "s_inf2", name: "2nd Rifle", template_id: "sov_inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(8, 3)},
        %{id: "s_inf3", name: "3rd Rifle", template_id: "sov_inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(8, 5)},
        %{id: "s_inf4", name: "4th Rifle", template_id: "sov_inf",
          side: :allied, force: :soviet, arrives_turn: 1, deploy_hex: Coord.new(8, 4)}
      ],
      leaders: [
        %{id: "ger_co", name: "Hauptmann Mueller", nationality: "german", era: "ww2",
          rank: :major, command_radius: 3, attack_modifier: 1, defense_modifier: 1,
          morale_modifier: 10, initiative_modifier: 1, abilities: [],
          position: Coord.new(0, 3), side: :axis, force: :german}
      ],
      victory_conditions: %{
        type: :victory_points,
        sudden_death_vp: nil,
        vp_levels: %{decisive: 80, tactical: 60, marginal: 40},
        unit_kill_vp: %{armor: 3, infantry: 1, leader: 5}
      },
      weather_schedule: [
        %{turns: 1..4, weather: :clear, ground: :dry},
        %{turns: 5..6, weather: :rain, ground: :mud}
      ],
      supply_sources: [
        %{side: :axis, hex: Coord.new(0, 0)},
        %{side: :allied, hex: Coord.new(9, 7)}
      ],
      reinforcement_mode: :fixed
    })
  end

  defp test_terrain(q, r) do
    cond do
      q == 4 && r in [3, 4, 5] -> :forest_pine
      q == 5 && r in [2, 3] -> :forest_deciduous
      q == 6 && r == 6 -> :marsh
      q == 3 && r == 6 -> :light_urban
      q == 7 && r in [1, 2] -> :orchard
      true -> :clear
    end
  end
end
