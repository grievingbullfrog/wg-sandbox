defmodule WargameWebWeb.LeaderEditorLive do
  @moduledoc """
  CRUD editor for leader characters.
  """

  use WargameWebWeb, :live_view

  alias WargamePersistence.Units
  alias WargamePersistence.Schemas.Leader

  @ranks Leader.valid_ranks()
  @abilities ~w(blitz defensive_genius logistics rapid_refit inspiration counter_battery)

  @impl true
  def mount(_params, _session, socket) do
    leaders = Units.list_leaders()

    socket =
      socket
      |> assign(:leaders, leaders)
      |> assign(:selected, nil)
      |> assign(:changeset, nil)
      |> assign(:filter_nationality, "")
      |> assign(:filter_era, "")
      |> assign(:filter_rank, "")
      |> assign(:search, "")
      |> assign(:ranks, @ranks)
      |> assign(:abilities, @abilities)
      |> assign(:save_status, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900 text-white">
      <header class="bg-gray-800 px-4 py-3 border-b border-gray-700 flex justify-between items-center">
        <h1 class="text-xl font-bold">Leader Editor</h1>
        <div class="flex gap-2">
          <button phx-click="new_leader" class="bg-green-600 hover:bg-green-500 px-3 py-1 rounded text-sm">
            New Leader
          </button>
          <span :if={@save_status} class="text-green-400 text-sm self-center">{@save_status}</span>
        </div>
      </header>

      <div class="flex-1 flex overflow-hidden">
        <%!-- Left Panel: Leader List --%>
        <aside class="w-72 bg-gray-800 border-r border-gray-700 flex flex-col">
          <div class="p-2 space-y-2 border-b border-gray-700">
            <input
              type="text"
              value={@search}
              phx-keyup="search"
              placeholder="Search by name..."
              class="w-full bg-gray-700 text-white text-sm px-2 py-1 rounded"
            />
            <div class="flex gap-1">
              <select phx-change="filter_era" class="bg-gray-700 text-white text-xs px-1 py-1 rounded flex-1">
                <option value="">All Eras</option>
                <option :for={era <- eras(@leaders)} value={era} selected={@filter_era == era}>{era}</option>
              </select>
              <select phx-change="filter_rank" class="bg-gray-700 text-white text-xs px-1 py-1 rounded flex-1">
                <option value="">All Ranks</option>
                <option :for={r <- @ranks} value={r} selected={@filter_rank == r}>{r}</option>
              </select>
            </div>
          </div>

          <div class="flex-1 overflow-y-auto">
            <ul class="divide-y divide-gray-700">
              <li
                :for={l <- filtered_leaders(assigns)}
                class={"px-3 py-2 cursor-pointer hover:bg-gray-700 #{if @selected && @selected.id == l.id, do: "bg-gray-600", else: ""}"}
                phx-click="select_leader"
                phx-value-id={l.id}
              >
                <div class="font-medium text-sm truncate">{l.name}</div>
                <div class="text-xs text-gray-400">
                  {l.nationality} | {l.rank}
                  {if l.is_historical, do: " (Historical)", else: ""}
                </div>
              </li>
            </ul>
          </div>
        </aside>

        <%!-- Right Panel: Detail Form --%>
        <main class="flex-1 overflow-y-auto p-6">
          <div :if={!@changeset} class="text-gray-500 text-center mt-20">
            Select a leader or create a new one
          </div>

          <form :if={@changeset} phx-submit="save_leader" phx-change="validate_leader" class="max-w-2xl space-y-4">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-lg font-bold">
                {if @selected, do: "Edit Leader", else: "New Leader"}
              </h2>
              <div class="flex gap-2">
                <button
                  :if={@selected}
                  type="button"
                  phx-click="delete_leader"
                  data-confirm="Delete this leader permanently?"
                  class="bg-red-600 hover:bg-red-500 px-3 py-1 rounded text-sm"
                >
                  Delete
                </button>
                <button type="submit" class="bg-blue-600 hover:bg-blue-500 px-4 py-1 rounded text-sm font-medium">
                  Save
                </button>
              </div>
            </div>

            <%!-- Identity --%>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-400 mb-1">Name</label>
                <input type="text" name="leader[name]" value={Ecto.Changeset.get_field(@changeset, :name)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Nationality</label>
                <input type="text" name="leader[nationality]" value={Ecto.Changeset.get_field(@changeset, :nationality)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Era</label>
                <input type="text" name="leader[era]" value={Ecto.Changeset.get_field(@changeset, :era)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Rank</label>
                <select name="leader[rank]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option :for={r <- @ranks} value={r} selected={Ecto.Changeset.get_field(@changeset, :rank) == r}>{r}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Command Radius</label>
                <input type="number" name="leader[command_radius]" value={Ecto.Changeset.get_field(@changeset, :command_radius)}
                  min="1" max="6" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div class="flex items-end pb-1">
                <label class="flex items-center gap-2 text-sm">
                  <input type="checkbox" name="leader[is_historical]" value="true"
                    checked={Ecto.Changeset.get_field(@changeset, :is_historical)} class="rounded bg-gray-700" />
                  Historical Leader
                </label>
              </div>
            </div>

            <%!-- Modifiers --%>
            <h3 class="text-sm font-bold text-gray-300 mt-4 border-b border-gray-700 pb-1">Modifiers</h3>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs text-gray-400 mb-1">Attack Modifier</label>
                <input type="number" name="leader[modifiers][attack_modifier]"
                  value={get_mod(@changeset, "attack_modifier")}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Defense Modifier</label>
                <input type="number" name="leader[modifiers][defense_modifier]"
                  value={get_mod(@changeset, "defense_modifier")}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Morale Modifier</label>
                <input type="number" name="leader[modifiers][morale_modifier]"
                  value={get_mod(@changeset, "morale_modifier")}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Initiative Modifier</label>
                <input type="number" name="leader[modifiers][initiative_modifier]"
                  value={get_mod(@changeset, "initiative_modifier")}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded" />
              </div>
            </div>

            <%!-- Abilities --%>
            <h3 class="text-sm font-bold text-gray-300 mt-4 border-b border-gray-700 pb-1">Abilities</h3>
            <div class="flex gap-3 flex-wrap">
              <label :for={ability <- @abilities} class="flex items-center gap-1 text-sm">
                <input type="checkbox" name="leader[modifiers][abilities][]" value={ability}
                  checked={ability in (get_mod(@changeset, "abilities") || [])} class="rounded bg-gray-700" />
                {Phoenix.Naming.humanize(ability)}
              </label>
            </div>

            <div :if={@changeset.action} class="mt-4">
              <div :for={{field, {msg, _}} <- @changeset.errors} class="text-red-400 text-sm">
                {Phoenix.Naming.humanize(field)}: {msg}
              </div>
            </div>
          </form>
        </main>
      </div>
    </div>
    """
  end

  # --- Event Handlers ---

  @impl true
  def handle_event("search", %{"value" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  def handle_event("filter_era", %{"value" => era}, socket) do
    {:noreply, assign(socket, :filter_era, era)}
  end

  def handle_event("filter_rank", %{"value" => rank}, socket) do
    {:noreply, assign(socket, :filter_rank, rank)}
  end

  def handle_event("select_leader", %{"id" => id}, socket) do
    leader = Enum.find(socket.assigns.leaders, &(&1.id == id))

    if leader do
      changeset = Leader.changeset(leader, %{})
      {:noreply, assign(socket, selected: leader, changeset: changeset)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("new_leader", _params, socket) do
    leader = %Leader{
      modifiers: %{
        "attack_modifier" => 0,
        "defense_modifier" => 0,
        "morale_modifier" => 5,
        "initiative_modifier" => 0,
        "abilities" => []
      }
    }

    changeset =
      Leader.changeset(leader, %{
        name: "New Leader",
        nationality: "german",
        era: "ww2",
        rank: "colonel",
        command_radius: 2
      })

    {:noreply, assign(socket, selected: nil, changeset: changeset)}
  end

  def handle_event("validate_leader", %{"leader" => params}, socket) do
    params = normalize_leader_params(params)

    changeset =
      (socket.assigns.selected || %Leader{})
      |> Leader.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save_leader", %{"leader" => params}, socket) do
    params = normalize_leader_params(params)

    result =
      case socket.assigns.selected do
        nil -> Units.create_leader(params)
        existing -> Units.update_leader(existing, params)
      end

    case result do
      {:ok, leader} ->
        leaders = Units.list_leaders()
        changeset = Leader.changeset(leader, %{})

        socket =
          socket
          |> assign(:leaders, leaders)
          |> assign(:selected, leader)
          |> assign(:changeset, changeset)
          |> assign(:save_status, "Saved!")

        Process.send_after(self(), :clear_save_status, 3000)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete_leader", _params, socket) do
    case socket.assigns.selected do
      nil ->
        {:noreply, socket}

      leader ->
        case Units.delete_leader(leader) do
          {:ok, _} ->
            leaders = Units.list_leaders()

            {:noreply,
             assign(socket,
               leaders: leaders,
               selected: nil,
               changeset: nil,
               save_status: "Deleted!"
             )}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete")}
        end
    end
  end

  @impl true
  def handle_info(:clear_save_status, socket) do
    {:noreply, assign(socket, :save_status, nil)}
  end

  # --- Helpers ---

  defp filtered_leaders(assigns) do
    assigns.leaders
    |> Enum.filter(fn l ->
      (assigns.search == "" || String.contains?(String.downcase(l.name), String.downcase(assigns.search))) &&
        (assigns.filter_era == "" || l.era == assigns.filter_era) &&
        (assigns.filter_rank == "" || l.rank == assigns.filter_rank)
    end)
  end

  defp eras(leaders) do
    leaders |> Enum.map(& &1.era) |> Enum.uniq() |> Enum.sort()
  end

  defp get_mod(changeset, key) do
    mods = Ecto.Changeset.get_field(changeset, :modifiers) || %{}
    Map.get(mods, key) || Map.get(mods, String.to_atom(key))
  end

  defp normalize_leader_params(params) do
    modifiers = Map.get(params, "modifiers", %{})

    modifiers =
      Enum.into(modifiers, %{}, fn
        {"abilities", v} when is_list(v) -> {"abilities", v}
        {k, v} when k in ~w(attack_modifier defense_modifier morale_modifier initiative_modifier) ->
          {k, parse_int(v)}
        {k, v} -> {k, v}
      end)

    # Ensure abilities key exists
    modifiers = Map.put_new(modifiers, "abilities", [])

    params
    |> Map.put("modifiers", modifiers)
    |> Map.put("command_radius", parse_int(Map.get(params, "command_radius", "2")))
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
