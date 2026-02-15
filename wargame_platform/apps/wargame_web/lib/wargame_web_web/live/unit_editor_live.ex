defmodule WargameWebWeb.UnitEditorLive do
  @moduledoc """
  CRUD editor for unit templates.

  Left panel: searchable/filterable list of unit templates.
  Right panel: detail form for the selected template.
  """

  use WargameWebWeb, :live_view

  alias WargamePersistence.Units
  alias WargamePersistence.Schemas.UnitTemplate

  @categories UnitTemplate.valid_categories()
  @unit_sizes UnitTemplate.valid_unit_sizes()

  @impl true
  def mount(_params, _session, socket) do
    templates = Units.list_unit_templates()

    socket =
      socket
      |> assign(:templates, templates)
      |> assign(:selected, nil)
      |> assign(:changeset, nil)
      |> assign(:filter_nationality, "")
      |> assign(:filter_era, "")
      |> assign(:filter_category, "")
      |> assign(:search, "")
      |> assign(:categories, @categories)
      |> assign(:unit_sizes, @unit_sizes)
      |> assign(:save_status, nil)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-900 text-white">
      <header class="bg-gray-800 px-4 py-3 border-b border-gray-700 flex justify-between items-center">
        <h1 class="text-xl font-bold">Unit Template Editor</h1>
        <div class="flex gap-2">
          <button phx-click="new_template" class="bg-green-600 hover:bg-green-500 px-3 py-1 rounded text-sm">
            New Template
          </button>
          <span :if={@save_status} class="text-green-400 text-sm self-center">{@save_status}</span>
        </div>
      </header>

      <div class="flex-1 flex overflow-hidden">
        <%!-- Left Panel: Template List --%>
        <aside class="w-72 bg-gray-800 border-r border-gray-700 flex flex-col">
          <%!-- Filters --%>
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
                <option :for={era <- eras(@templates)} value={era} selected={@filter_era == era}>{era}</option>
              </select>
              <select phx-change="filter_category" class="bg-gray-700 text-white text-xs px-1 py-1 rounded flex-1">
                <option value="">All Types</option>
                <option :for={cat <- @categories} value={cat} selected={@filter_category == cat}>{cat}</option>
              </select>
            </div>
          </div>

          <%!-- Template List --%>
          <div class="flex-1 overflow-y-auto">
            <ul class="divide-y divide-gray-700">
              <li
                :for={t <- filtered_templates(assigns)}
                class={"px-3 py-2 cursor-pointer hover:bg-gray-700 #{if @selected && @selected.id == t.id, do: "bg-gray-600", else: ""}"}
                phx-click="select_template"
                phx-value-id={t.id}
              >
                <div class="font-medium text-sm truncate">{t.name}</div>
                <div class="text-xs text-gray-400">{t.nationality} | {t.era} | {t.category}</div>
              </li>
            </ul>
          </div>
        </aside>

        <%!-- Right Panel: Detail Form --%>
        <main class="flex-1 overflow-y-auto p-6">
          <div :if={!@changeset} class="text-gray-500 text-center mt-20">
            Select a template from the list or create a new one
          </div>

          <form :if={@changeset} phx-submit="save_template" phx-change="validate_template" class="max-w-2xl space-y-4">
            <div class="flex justify-between items-center mb-4">
              <h2 class="text-lg font-bold">
                {if @selected, do: "Edit Template", else: "New Template"}
              </h2>
              <div class="flex gap-2">
                <button
                  :if={@selected}
                  type="button"
                  phx-click="clone_template"
                  class="bg-purple-600 hover:bg-purple-500 px-3 py-1 rounded text-sm"
                >
                  Clone
                </button>
                <button
                  :if={@selected}
                  type="button"
                  phx-click="delete_template"
                  data-confirm="Delete this template permanently?"
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
                <input
                  type="text"
                  name="template[name]"
                  value={Ecto.Changeset.get_field(@changeset, :name)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Nationality</label>
                <input
                  type="text"
                  name="template[nationality]"
                  value={Ecto.Changeset.get_field(@changeset, :nationality)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Era</label>
                <input
                  type="text"
                  name="template[era]"
                  value={Ecto.Changeset.get_field(@changeset, :era)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Icon Type</label>
                <input
                  type="text"
                  name="template[icon_type]"
                  value={Ecto.Changeset.get_field(@changeset, :icon_type)}
                  class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Category</label>
                <select name="template[category]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option :for={cat <- @categories} value={cat} selected={Ecto.Changeset.get_field(@changeset, :category) == cat}>{cat}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Unit Size</label>
                <select name="template[unit_size]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option :for={size <- @unit_sizes} value={size} selected={Ecto.Changeset.get_field(@changeset, :unit_size) == size}>{size}</option>
                </select>
              </div>
            </div>

            <%!-- Combat Stats --%>
            <h3 class="text-sm font-bold text-gray-300 mt-4 border-b border-gray-700 pb-1">Combat Stats</h3>
            <div class="grid grid-cols-3 gap-3">
              <.stat_input label="Attack Soft" name="template[stats][attack_soft]" value={get_stat(@changeset, "attack_soft")} />
              <.stat_input label="Attack Hard" name="template[stats][attack_hard]" value={get_stat(@changeset, "attack_hard")} />
              <.stat_input label="Defense" name="template[stats][defense]" value={get_stat(@changeset, "defense")} />
              <.stat_input label="Armor" name="template[stats][armor]" value={get_stat(@changeset, "armor")} />
              <.stat_input label="Range" name="template[stats][range]" value={get_stat(@changeset, "range")} />
              <.stat_input label="Spotting" name="template[stats][spotting]" value={get_stat(@changeset, "spotting")} />
            </div>

            <%!-- Movement & Other --%>
            <h3 class="text-sm font-bold text-gray-300 mt-4 border-b border-gray-700 pb-1">Movement & Resources</h3>
            <div class="grid grid-cols-3 gap-3">
              <.stat_input label="Movement Points" name="template[stats][movement_points]" value={get_stat(@changeset, "movement_points")} />
              <div>
                <label class="block text-xs text-gray-400 mb-1">Movement Type</label>
                <select name="template[stats][movement_type]" class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded">
                  <option :for={mt <- ~w(foot wheeled tracked)} value={mt}
                    selected={get_stat(@changeset, "movement_type") == mt}>{mt}</option>
                </select>
              </div>
              <.stat_input label="Initiative" name="template[stats][initiative]" value={get_stat(@changeset, "initiative")} />
              <.stat_input label="Max Strength" name="template[stats][max_strength]" value={get_stat(@changeset, "max_strength")} />
              <.stat_input label="Max Ammo" name="template[stats][max_ammo]" value={get_stat(@changeset, "max_ammo")} />
              <.stat_input label="Max Fuel" name="template[stats][max_fuel]" value={get_stat(@changeset, "max_fuel")} />
            </div>

            <%!-- Flags --%>
            <h3 class="text-sm font-bold text-gray-300 mt-4 border-b border-gray-700 pb-1">Capabilities</h3>
            <div class="flex gap-4 flex-wrap">
              <label class="flex items-center gap-1 text-sm">
                <input type="checkbox" name="template[stats][can_bridge]" value="true"
                  checked={get_stat(@changeset, "can_bridge") == true || get_stat(@changeset, "can_bridge") == "true"} class="rounded bg-gray-700" />
                Can Bridge
              </label>
              <label class="flex items-center gap-1 text-sm">
                <input type="checkbox" name="template[stats][can_entrench]" value="true"
                  checked={get_stat(@changeset, "can_entrench") == true || get_stat(@changeset, "can_entrench") == "true"} class="rounded bg-gray-700" />
                Can Entrench
              </label>
              <label class="flex items-center gap-1 text-sm">
                <input type="checkbox" name="template[stats][is_organic_transport]" value="true"
                  checked={get_stat(@changeset, "is_organic_transport") == true || get_stat(@changeset, "is_organic_transport") == "true"} class="rounded bg-gray-700" />
                Organic Transport
              </label>
            </div>

            <%!-- Validation Errors --%>
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

  defp stat_input(assigns) do
    ~H"""
    <div>
      <label class="block text-xs text-gray-400 mb-1">{@label}</label>
      <input
        type="number"
        name={@name}
        value={@value}
        class="w-full bg-gray-700 text-white text-sm px-2 py-1.5 rounded"
      />
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

  def handle_event("filter_category", %{"value" => cat}, socket) do
    {:noreply, assign(socket, :filter_category, cat)}
  end

  def handle_event("select_template", %{"id" => id}, socket) do
    template = Enum.find(socket.assigns.templates, &(&1.id == id))

    if template do
      changeset = UnitTemplate.changeset(template, %{})
      {:noreply, assign(socket, selected: template, changeset: changeset)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("new_template", _params, socket) do
    template = %UnitTemplate{
      stats: %{
        "attack_soft" => 4, "attack_hard" => 2, "defense" => 4, "armor" => 0,
        "movement_points" => 4, "movement_type" => "foot", "range" => 1,
        "spotting" => 3, "initiative" => 3, "max_strength" => 10,
        "max_ammo" => 10, "max_fuel" => 0,
        "can_bridge" => false, "can_entrench" => true, "is_organic_transport" => false
      }
    }

    changeset =
      UnitTemplate.changeset(template, %{
        name: "New Unit",
        nationality: "german",
        era: "ww2",
        category: "infantry",
        unit_size: "platoon",
        icon_type: "infantry"
      })

    {:noreply, assign(socket, selected: nil, changeset: changeset)}
  end

  def handle_event("validate_template", %{"template" => params}, socket) do
    params = normalize_template_params(params)

    changeset =
      (socket.assigns.selected || %UnitTemplate{})
      |> UnitTemplate.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save_template", %{"template" => params}, socket) do
    params = normalize_template_params(params)

    result =
      case socket.assigns.selected do
        nil -> Units.create_unit_template(params)
        existing -> Units.update_unit_template(existing, params)
      end

    case result do
      {:ok, template} ->
        templates = Units.list_unit_templates()
        changeset = UnitTemplate.changeset(template, %{})

        socket =
          socket
          |> assign(:templates, templates)
          |> assign(:selected, template)
          |> assign(:changeset, changeset)
          |> assign(:save_status, "Saved!")

        Process.send_after(self(), :clear_save_status, 3000)
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("clone_template", _params, socket) do
    template = socket.assigns.selected

    if template do
      changeset =
        UnitTemplate.changeset(%UnitTemplate{stats: template.stats}, %{
          name: template.name <> " (Copy)",
          nationality: template.nationality,
          era: template.era,
          category: template.category,
          unit_size: template.unit_size,
          icon_type: template.icon_type
        })

      {:noreply, assign(socket, selected: nil, changeset: changeset)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_template", _params, socket) do
    case socket.assigns.selected do
      nil ->
        {:noreply, socket}

      template ->
        case Units.delete_unit_template(template) do
          {:ok, _} ->
            templates = Units.list_unit_templates()

            {:noreply,
             assign(socket,
               templates: templates,
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

  defp filtered_templates(assigns) do
    assigns.templates
    |> Enum.filter(fn t ->
      (assigns.search == "" || String.contains?(String.downcase(t.name), String.downcase(assigns.search))) &&
        (assigns.filter_era == "" || t.era == assigns.filter_era) &&
        (assigns.filter_category == "" || t.category == assigns.filter_category)
    end)
  end

  defp eras(templates) do
    templates |> Enum.map(& &1.era) |> Enum.uniq() |> Enum.sort()
  end

  defp get_stat(changeset, key) do
    stats = Ecto.Changeset.get_field(changeset, :stats) || %{}
    Map.get(stats, key) || Map.get(stats, String.to_atom(key))
  end

  defp normalize_template_params(params) do
    stats = Map.get(params, "stats", %{})

    # Convert numeric strings to integers
    stats =
      Enum.into(stats, %{}, fn
        {k, v} when k in ~w(attack_soft attack_hard defense armor movement_points range spotting initiative max_strength max_ammo max_fuel) ->
          {k, parse_int(v)}

        {k, v} ->
          {k, v}
      end)

    Map.put(params, "stats", stats)
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
