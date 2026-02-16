defmodule WargameWebWeb.ProductLive do
  @moduledoc "Product detail page with scenario browser and active games."

  use WargameWebWeb, :live_view

  alias WargamePersistence.GameProducts
  alias WargamePersistence.Scenarios

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    product = GameProducts.get_game_product_by_slug!(slug)
    scenarios = GameProducts.list_product_scenarios(product.id)

    # Load scenario unit counts for display
    scenarios_with_counts =
      Enum.map(scenarios, fn scenario ->
        units = Scenarios.list_scenario_units(scenario.id)
        axis_count = Enum.count(units, &(&1.side == "axis"))
        allied_count = Enum.count(units, &(&1.side == "allied"))
        {scenario, %{axis_units: axis_count, allied_units: allied_count, total_units: length(units)}}
      end)

    socket =
      socket
      |> assign(:product, product)
      |> assign(:scenarios, scenarios_with_counts)
      |> assign(:page_title, product.name)

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
              &larr; All Games
            </.link>
            <span class="text-gray-600">|</span>
            <span class="text-lg font-bold text-white">{@product.name}</span>
          </div>
          <div class="flex items-center gap-4 text-sm">
            <.link navigate={~p"/my-games"} class="text-gray-300 hover:text-white transition-colors">
              My Games
            </.link>
          </div>
        </div>
      </nav>

      <%!-- Product Header --%>
      <div class="bg-gradient-to-b from-gray-800 to-gray-900 border-b border-gray-700">
        <div class="max-w-6xl mx-auto px-4 py-8">
          <div class="flex items-start gap-6">
            <div class="w-24 h-24 bg-gray-700 rounded-lg flex items-center justify-center flex-shrink-0">
              <span class="text-4xl opacity-30"><%= era_icon(@product.era) %></span>
            </div>
            <div>
              <div class="flex items-center gap-3 mb-2">
                <h1 class="text-3xl font-bold">{@product.name}</h1>
                <span class="px-2 py-0.5 bg-gray-700 rounded text-xs text-gray-300 uppercase tracking-wider">
                  {@product.era}
                </span>
              </div>
              <p :if={@product.tagline} class="text-lg text-gray-400 mb-2">{@product.tagline}</p>
              <p :if={@product.description} class="text-sm text-gray-500 max-w-2xl">{@product.description}</p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Scenarios List --%>
      <div class="max-w-6xl mx-auto px-4 py-8">
        <h2 class="text-xl font-bold mb-6">
          Scenarios
          <span class="text-sm font-normal text-gray-500 ml-2">{length(@scenarios)} available</span>
        </h2>

        <div :if={@scenarios == []} class="text-center py-12 text-gray-500">
          <p>No scenarios available for this product yet.</p>
        </div>

        <div class="space-y-4">
          <div
            :for={{scenario, counts} <- @scenarios}
            class="bg-gray-800 rounded-lg border border-gray-700 hover:border-gray-600 transition-colors"
          >
            <div class="p-5">
              <div class="flex items-start justify-between">
                <div class="flex-1 min-w-0">
                  <h3 class="text-lg font-semibold mb-1">{scenario.name}</h3>
                  <p :if={scenario.description} class="text-sm text-gray-400 mb-3 line-clamp-2">
                    {scenario.description}
                  </p>
                  <div class="flex flex-wrap gap-4 text-xs text-gray-500">
                    <span :if={scenario.map}>
                      Map: {scenario.map.width}x{scenario.map.height}
                    </span>
                    <span>{scenario.max_turns} turns</span>
                    <span>Axis: {counts.axis_units} units</span>
                    <span>Allied: {counts.allied_units} units</span>
                    <span :if={scenario.date_start}>
                      {scenario.date_start}
                    </span>
                  </div>
                </div>
                <div class="flex-shrink-0 ml-4">
                  <.link
                    navigate={~p"/games/new?scenario_id=#{scenario.id}&product_slug=#{@product.slug}"}
                    class="px-4 py-2 bg-blue-600 hover:bg-blue-500 rounded text-sm font-medium whitespace-nowrap"
                  >
                    Start Game
                  </.link>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp era_icon("ww2"), do: raw("&#9876;")
  defp era_icon("modern"), do: raw("&#9881;")
  defp era_icon(_), do: raw("&#9813;")
end
