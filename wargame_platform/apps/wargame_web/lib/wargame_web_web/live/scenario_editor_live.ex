defmodule WargameWebWeb.ScenarioEditorLive do
  @moduledoc """
  Scenario editor with tabbed interface.

  Tabs: General, Deployment, Reinforcements, Victory & Weather.
  """

  use WargameWebWeb, :live_view

  alias WargamePersistence.{Maps, Scenarios, Units}
  alias WargamePersistence.Schemas.Scenario

  @tabs ~w(general deployment reinforcements victory)a

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scenario = Scenarios.get_scenario!(id)
    socket = init_socket(socket, scenario)
    {:ok, socket}
  end

  def mount(_params, _session, socket) do
    socket = init_socket(socket, nil)
    {:ok, socket}
  end

  defp init_socket(socket, scenario) do
    maps = Maps.list_maps()
    action_profiles = Scenarios.list_action_profiles()
    unit_templates = Units.list_unit_templates()
    leaders = Units.list_leaders()

    changeset =
      if scenario do
        Scenario.changeset(scenario, %{})
      else
        Scenario.changeset(%Scenario{sides: default_sides(), victory_conditions: default_vc()}, %{
          name: "New Scenario",
          era: "ww2",
          max_turns: 10,
          first_move: "axis",
          reinforcement_mode: "fixed"
        })
      end

    socket
    |> assign(:scenario, scenario)
    |> assign(:changeset, changeset)
    |> assign(:tab, :general)
    |> assign(:tabs, @tabs)
    |> assign(:maps, maps)
    |> assign(:action_profiles, action_profiles)
    |> assign(:unit_templates, unit_templates)
    |> assign(:leaders, leaders)
    |> assign(:scenario_units, if(scenario, do: Scenarios.list_scenario_units(scenario.id), else: []))
    |> assign(:selected_map_id, if(scenario, do: scenario.map_id, else: nil))
    |> assign(:selected_profile_id, if(scenario, do: scenario.action_profile_id, else: nil))
    |> assign(:weather_entries, parse_weather(scenario))
    |> assign(:save_status, nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900 text-white">
      <header class="bg-gray-800 px-4 py-3 border-b border-gray-700 flex justify-between items-center">
        <h1 class="text-xl font-bold">Scenario Editor</h1>
        <div class="flex gap-2">
          <button phx-click="save_scenario" class="bg-green-600 hover:bg-green-500 px-4 py-1 rounded text-sm font-medium">
            Save Scenario
          </button>
          <span :if={@save_status} class="text-green-400 text-sm self-center">{@save_status}</span>
        </div>
      </header>

      <%!-- Tab Bar --%>
      <nav class="bg-gray-800 border-b border-gray-700 px-4 flex gap-1">
        <button
          :for={tab <- @tabs}
          phx-click="switch_tab"
          phx-value-tab={tab}
          class={"px-4 py-2 text-sm font-medium border-b-2 #{if @tab == tab, do: "border-blue-500 text-blue-400", else: "border-transparent text-gray-400 hover:text-gray-300"}"}
        >
          {tab_label(tab)}
        </button>
      </nav>

      <main class="flex-1 overflow-y-auto p-6">
        <%!-- General Tab --%>
        <div :if={@tab == :general} class="max-w-2xl space-y-4">
          <form phx-change="validate_scenario" class="space-y-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-400 mb-1">Name</label>
                <input type="text" name="scenario[name]" value={Ecto.Changeset.get_field(@changeset, :name)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Era</label>
                <input type="text" name="scenario[era]" value={Ecto.Changeset.get_field(@changeset, :era)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Description</label>
                <textarea name="scenario[description]" rows="3"
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">{Ecto.Changeset.get_field(@changeset, :description)}</textarea>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Max Turns</label>
                <input type="number" name="scenario[max_turns]" value={Ecto.Changeset.get_field(@changeset, :max_turns)}
                  min="1" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">First Move</label>
                <select name="scenario[first_move]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option value="axis" selected={Ecto.Changeset.get_field(@changeset, :first_move) == "axis"}>Axis</option>
                  <option value="allied" selected={Ecto.Changeset.get_field(@changeset, :first_move) == "allied"}>Allied</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Reinforcement Mode</label>
                <select name="scenario[reinforcement_mode]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option :for={mode <- ~w(fixed variable conditional)} value={mode}
                    selected={Ecto.Changeset.get_field(@changeset, :reinforcement_mode) == mode}>{mode}</option>
                </select>
              </div>
            </div>

            <%!-- Map Selection --%>
            <div>
              <label class="block text-xs text-gray-400 mb-1">Map</label>
              <select name="scenario[map_id]" phx-change="select_map" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                <option value="">-- Select Map --</option>
                <option :for={m <- @maps} value={m.id} selected={@selected_map_id == m.id}>
                  {m.name} ({m.width}x{m.height})
                </option>
              </select>
            </div>

            <%!-- Action Profile --%>
            <div>
              <label class="block text-xs text-gray-400 mb-1">Action Profile</label>
              <select name="scenario[action_profile_id]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                <option value="">-- Select Profile --</option>
                <option :for={p <- @action_profiles} value={p.id} selected={@selected_profile_id == p.id}>
                  {p.name} ({p.era})
                </option>
              </select>
            </div>

            <%!-- Sides Configuration --%>
            <h3 class="text-sm font-bold text-gray-300 border-b border-gray-700 pb-1">Sides</h3>
            <div class="grid grid-cols-2 gap-4">
              <div class="bg-gray-800 p-3 rounded">
                <label class="block text-xs text-gray-400 mb-1">Side 1 Name</label>
                <input type="text" name="scenario[sides][side1_name]"
                  value={get_side_name(Ecto.Changeset.get_field(@changeset, :sides), 0)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1 rounded" />
              </div>
              <div class="bg-gray-800 p-3 rounded">
                <label class="block text-xs text-gray-400 mb-1">Side 2 Name</label>
                <input type="text" name="scenario[sides][side2_name]"
                  value={get_side_name(Ecto.Changeset.get_field(@changeset, :sides), 1)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1 rounded" />
              </div>
            </div>
          </form>
        </div>

        <%!-- Deployment Tab --%>
        <div :if={@tab == :deployment}>
          <div class="mb-4 flex justify-between items-center">
            <h2 class="text-lg font-bold">Unit Deployment</h2>
            <span class="text-sm text-gray-400">{length(@scenario_units)} units placed</span>
          </div>
          <div :if={!@selected_map_id} class="text-gray-500 text-center mt-10">
            Select a map in the General tab first
          </div>
          <div :if={@selected_map_id} class="text-gray-400 text-sm">
            <p class="mb-4">
              Unit deployment uses the map canvas. Select units from the palette and click hexes to place them.
            </p>
            <div class="bg-gray-800 rounded p-4">
              <h3 class="font-bold text-gray-300 mb-2">Deployed Units</h3>
              <table class="w-full text-sm">
                <thead class="text-gray-400 text-xs">
                  <tr>
                    <th class="text-left py-1">Name</th>
                    <th class="text-left py-1">Template</th>
                    <th class="text-left py-1">Side</th>
                    <th class="text-left py-1">Arrives</th>
                    <th class="text-left py-1">Hex</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-700">
                  <tr :for={su <- @scenario_units} class="text-gray-300">
                    <td class="py-1">{su.name}</td>
                    <td class="py-1">{if su.unit_template, do: su.unit_template.name, else: "?"}</td>
                    <td class="py-1">{su.side}</td>
                    <td class="py-1">Turn {su.arrives_turn}</td>
                    <td class="py-1">
                      {if su.position_q, do: "(#{su.position_q},#{su.position_r})", else: "-"}
                    </td>
                    <td class="py-1">
                      <button phx-click="remove_unit" phx-value-id={su.id} class="text-red-400 hover:text-red-300 text-xs">
                        Remove
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Reinforcements Tab --%>
        <div :if={@tab == :reinforcements}>
          <h2 class="text-lg font-bold mb-4">Reinforcement Schedule</h2>
          <p class="text-gray-400 text-sm mb-4">
            Configure units that arrive after turn 1. Set arrival turns and conditions in the deployment tab.
          </p>
          <div class="bg-gray-800 rounded p-4">
            <div :for={su <- Enum.filter(@scenario_units, & &1.arrives_turn > 1)} class="flex justify-between items-center py-2 border-b border-gray-700">
              <span>{su.name}</span>
              <span class="text-gray-400 text-sm">Arrives Turn {su.arrives_turn}</span>
            </div>
            <div :if={Enum.all?(@scenario_units, & &1.arrives_turn <= 1)} class="text-gray-500 text-sm">
              No reinforcements scheduled. Set arrival turns > 1 for units in the deployment tab.
            </div>
          </div>
        </div>

        <%!-- Victory & Weather Tab --%>
        <div :if={@tab == :victory} class="max-w-2xl space-y-6">
          <form phx-change="validate_scenario" class="space-y-6">
            <div>
              <h2 class="text-lg font-bold mb-4">Victory Conditions</h2>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Victory Type</label>
                  <select name="scenario[victory_conditions][type]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                    <option value="victory_points" selected={get_vc(@changeset, "type") == "victory_points"}>Victory Points</option>
                    <option value="elimination" selected={get_vc(@changeset, "type") == "elimination"}>Elimination</option>
                    <option value="territorial" selected={get_vc(@changeset, "type") == "territorial"}>Territorial</option>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Decisive VP</label>
                  <input type="number" name="scenario[victory_conditions][decisive]" value={get_vc_level(@changeset, "decisive")}
                    class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Tactical VP</label>
                  <input type="number" name="scenario[victory_conditions][tactical]" value={get_vc_level(@changeset, "tactical")}
                    class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Marginal VP</label>
                  <input type="number" name="scenario[victory_conditions][marginal]" value={get_vc_level(@changeset, "marginal")}
                    class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
                </div>
              </div>
            </div>

            <div>
              <h2 class="text-lg font-bold mb-4">Weather Schedule</h2>
              <div class="space-y-2">
                <div :for={{entry, idx} <- Enum.with_index(@weather_entries)} class="flex gap-2 items-center bg-gray-800 p-2 rounded">
                  <span class="text-xs text-gray-400 w-16">Turns {entry.from}-{entry.to}</span>
                  <select name={"weather[#{idx}][weather]"} class="bg-gray-700 text-white text-xs px-2 py-1 rounded">
                    <option :for={w <- ~w(clear rain overcast snow blizzard)} value={w} selected={entry.weather == w}>{w}</option>
                  </select>
                  <select name={"weather[#{idx}][ground]"} class="bg-gray-700 text-white text-xs px-2 py-1 rounded">
                    <option :for={g <- ~w(dry mud frozen deep_mud)} value={g} selected={entry.ground == g}>{g}</option>
                  </select>
                  <button type="button" phx-click="remove_weather" phx-value-idx={idx} class="text-red-400 text-xs">
                    Remove
                  </button>
                </div>
              </div>
              <button type="button" phx-click="add_weather" class="mt-2 text-blue-400 hover:text-blue-300 text-sm">
                + Add Weather Period
              </button>
            </div>
          </form>
        </div>
      </main>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, String.to_existing_atom(tab))}
  end

  def handle_event("validate_scenario", %{"scenario" => params}, socket) do
    params = normalize_scenario_params(params)

    changeset =
      (socket.assigns.scenario || %Scenario{})
      |> Scenario.changeset(params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:changeset, changeset)
      |> assign(:selected_map_id, params["map_id"])
      |> assign(:selected_profile_id, params["action_profile_id"])

    {:noreply, socket}
  end

  def handle_event("select_map", %{"scenario" => %{"map_id" => map_id}}, socket) do
    {:noreply, assign(socket, :selected_map_id, map_id)}
  end

  def handle_event("save_scenario", _params, socket) do
    changeset = socket.assigns.changeset
    params = Ecto.Changeset.apply_changes(changeset) |> Map.from_struct()

    result =
      case socket.assigns.scenario do
        nil -> Scenarios.create_scenario(params)
        existing -> Scenarios.update_scenario(existing, params)
      end

    case result do
      {:ok, scenario} ->
        changeset = Scenario.changeset(scenario, %{})

        socket =
          socket
          |> assign(:scenario, scenario)
          |> assign(:changeset, changeset)
          |> assign(:save_status, "Saved!")

        Process.send_after(self(), :clear_save_status, 3000)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("remove_unit", %{"id" => id}, socket) do
    su = Enum.find(socket.assigns.scenario_units, &(&1.id == id))

    if su do
      Scenarios.delete_scenario_unit(su)
      units = Enum.reject(socket.assigns.scenario_units, &(&1.id == id))
      {:noreply, assign(socket, :scenario_units, units)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_weather", _params, socket) do
    entries = socket.assigns.weather_entries
    last_to = if entries == [], do: 0, else: List.last(entries).to
    new_entry = %{from: last_to + 1, to: last_to + 3, weather: "clear", ground: "dry"}
    {:noreply, assign(socket, :weather_entries, entries ++ [new_entry])}
  end

  def handle_event("remove_weather", %{"idx" => idx}, socket) do
    idx = String.to_integer(idx)
    entries = List.delete_at(socket.assigns.weather_entries, idx)
    {:noreply, assign(socket, :weather_entries, entries)}
  end

  @impl true
  def handle_info(:clear_save_status, socket) do
    {:noreply, assign(socket, :save_status, nil)}
  end

  # --- Helpers ---

  defp tab_label(:general), do: "General"
  defp tab_label(:deployment), do: "Deployment"
  defp tab_label(:reinforcements), do: "Reinforcements"
  defp tab_label(:victory), do: "Victory & Weather"

  defp default_sides do
    %{
      "sides" => [
        %{"id" => "axis", "name" => "Axis", "forces" => ["german"]},
        %{"id" => "allied", "name" => "Allied", "forces" => ["soviet"]}
      ]
    }
  end

  defp default_vc do
    %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 80, "tactical" => 60, "marginal" => 40}
    }
  end

  defp get_side_name(sides, idx) when is_map(sides) do
    case Map.get(sides, "sides", []) do
      sides_list when is_list(sides_list) ->
        case Enum.at(sides_list, idx) do
          %{"name" => name} -> name
          _ -> if(idx == 0, do: "Axis", else: "Allied")
        end
      _ -> if(idx == 0, do: "Axis", else: "Allied")
    end
  end
  defp get_side_name(_, idx), do: if(idx == 0, do: "Axis", else: "Allied")

  defp get_vc(changeset, key) do
    vc = Ecto.Changeset.get_field(changeset, :victory_conditions) || %{}
    Map.get(vc, key) || Map.get(vc, String.to_atom(key))
  end

  defp get_vc_level(changeset, key) do
    vc = Ecto.Changeset.get_field(changeset, :victory_conditions) || %{}
    levels = Map.get(vc, "vp_levels", %{})
    Map.get(levels, key) || Map.get(levels, String.to_atom(key))
  end

  defp parse_weather(nil), do: [%{from: 1, to: 5, weather: "clear", ground: "dry"}]
  defp parse_weather(scenario) do
    schedule = scenario.weather_schedule

    case schedule do
      %{"schedule" => entries} when is_list(entries) ->
        Enum.map(entries, fn e ->
          %{
            from: Map.get(e, "from", 1),
            to: Map.get(e, "to", 5),
            weather: Map.get(e, "weather", "clear"),
            ground: Map.get(e, "ground", "dry")
          }
        end)

      _ ->
        [%{from: 1, to: 5, weather: "clear", ground: "dry"}]
    end
  end

  defp normalize_scenario_params(params) do
    # Build victory_conditions from form fields
    vc_params = Map.get(params, "victory_conditions", %{})

    victory_conditions = %{
      "type" => Map.get(vc_params, "type", "victory_points"),
      "vp_levels" => %{
        "decisive" => parse_int(Map.get(vc_params, "decisive", "80")),
        "tactical" => parse_int(Map.get(vc_params, "tactical", "60")),
        "marginal" => parse_int(Map.get(vc_params, "marginal", "40"))
      }
    }

    # Build sides from form fields
    side_params = Map.get(params, "sides", %{})

    sides = %{
      "sides" => [
        %{"id" => "axis", "name" => Map.get(side_params, "side1_name", "Axis"), "forces" => ["german"]},
        %{"id" => "allied", "name" => Map.get(side_params, "side2_name", "Allied"), "forces" => ["soviet"]}
      ]
    }

    params
    |> Map.put("victory_conditions", victory_conditions)
    |> Map.put("sides", sides)
    |> Map.put("max_turns", parse_int(Map.get(params, "max_turns", "10")))
  end

  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp parse_int(_), do: 0
end
