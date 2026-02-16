defmodule WargameWebWeb.HomeLive do
  @moduledoc "Platform landing page showing available game products."

  use WargameWebWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    products_with_counts =
      WargamePersistence.GameProducts.list_products_with_counts(published: true)

    {:ok, assign(socket, :products, products_with_counts)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-900 text-white">
      <%!-- Navigation Bar --%>
      <nav class="bg-gray-800 border-b border-gray-700">
        <div class="max-w-6xl mx-auto px-4 h-14 flex items-center justify-between">
          <.link navigate={~p"/"} class="text-lg font-bold tracking-tight text-white hover:text-gray-200">
            Wargame Platform
          </.link>
          <div class="flex items-center gap-6 text-sm">
            <.link navigate={~p"/my-games"} class="text-gray-300 hover:text-white transition-colors">
              My Games
            </.link>
            <div class="relative group">
              <button class="text-gray-400 hover:text-white transition-colors flex items-center gap-1">
                Design Tools
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>
              <div class="absolute right-0 top-full mt-1 w-48 bg-gray-800 border border-gray-700 rounded-lg shadow-xl opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-50">
                <.link navigate={~p"/map-editor"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white rounded-t-lg">
                  Map Editor
                </.link>
                <.link navigate={~p"/unit-editor"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white">
                  Unit Templates
                </.link>
                <.link navigate={~p"/leader-editor"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white">
                  Leaders
                </.link>
                <.link navigate={~p"/scenario-editor"} class="block px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 hover:text-white rounded-b-lg">
                  Scenario Editor
                </.link>
              </div>
            </div>
          </div>
        </div>
      </nav>

      <%!-- Hero Section --%>
      <div class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-br from-gray-900 via-gray-800 to-gray-900"></div>
        <div class="relative max-w-6xl mx-auto px-4 py-16 text-center">
          <h1 class="text-5xl font-bold tracking-tight mb-4">Wargame Platform</h1>
          <p class="text-xl text-gray-400 max-w-2xl mx-auto">
            Hex-based wargames with AI opponents. Choose a game to get started.
          </p>
        </div>
      </div>

      <%!-- Product Catalog --%>
      <div class="max-w-6xl mx-auto px-4 py-12">
        <div :if={@products == []} class="text-center py-16">
          <div class="text-gray-500 mb-4">
            <svg class="w-16 h-16 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
            </svg>
            <p class="text-lg">No games installed yet</p>
            <p class="text-sm mt-2">Run <code class="bg-gray-800 px-2 py-0.5 rounded text-gray-300">mix ecto.reset</code> to load seed data.</p>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          <.link
            :for={{product, scenario_count} <- @products}
            navigate={~p"/products/#{product.slug}"}
            class="group block bg-gray-800 rounded-xl border border-gray-700 hover:border-blue-500 transition-all overflow-hidden"
          >
            <%!-- Cover Image Area --%>
            <div class="h-48 bg-gradient-to-br from-gray-700 to-gray-800 flex items-center justify-center relative">
              <div class="text-6xl opacity-20 group-hover:opacity-30 transition-opacity">
                <%= era_icon(product.era) %>
              </div>
              <div class="absolute top-3 right-3">
                <span class="px-2 py-1 bg-gray-900/80 rounded text-xs text-gray-300 uppercase tracking-wider">
                  {product.era}
                </span>
              </div>
            </div>

            <%!-- Product Info --%>
            <div class="p-6">
              <h2 class="text-xl font-bold mb-1 group-hover:text-blue-400 transition-colors">
                {product.name}
              </h2>
              <p :if={product.tagline} class="text-sm text-gray-400 mb-3">
                {product.tagline}
              </p>
              <p :if={product.description} class="text-sm text-gray-500 mb-4 line-clamp-2">
                {product.description}
              </p>
              <div class="flex items-center justify-between">
                <span class="text-xs text-gray-500">
                  {scenario_count} <%= if scenario_count == 1, do: "scenario", else: "scenarios" %>
                </span>
                <span class="text-sm text-blue-400 group-hover:text-blue-300 font-medium">
                  Play &rarr;
                </span>
              </div>
            </div>
          </.link>
        </div>
      </div>

      <%!-- Quick Start Section --%>
      <div class="max-w-6xl mx-auto px-4 pb-16">
        <div class="border-t border-gray-700 pt-8">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-sm font-medium text-gray-400">Developer Tools</h3>
              <p class="text-xs text-gray-600 mt-1">Quick start, map demo, and editors</p>
            </div>
            <div class="flex gap-3">
              <.link navigate={~p"/games/new"} class="px-3 py-1.5 bg-green-700 hover:bg-green-600 rounded text-xs font-medium">
                Quick Start
              </.link>
              <.link navigate={~p"/map-demo"} class="px-3 py-1.5 bg-gray-700 hover:bg-gray-600 rounded text-xs text-gray-300">
                Map Demo
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp era_icon("ww2"), do: raw("&#9876;")
  defp era_icon("modern"), do: raw("&#9881;")
  defp era_icon("ancient"), do: raw("&#9876;")
  defp era_icon(_), do: raw("&#9813;")
end
