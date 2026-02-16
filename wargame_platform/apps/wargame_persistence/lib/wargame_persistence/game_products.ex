defmodule WargamePersistence.GameProducts do
  @moduledoc "Context for game product persistence and queries."

  import Ecto.Query
  alias WargamePersistence.Repo
  alias WargamePersistence.Schemas.{GameProduct, Scenario}

  def list_game_products(opts \\ []) do
    GameProduct
    |> maybe_filter_published(opts[:published])
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  def get_game_product!(id), do: Repo.get!(GameProduct, id)

  def get_game_product_by_slug!(slug) do
    Repo.get_by!(GameProduct, slug: slug)
  end

  def get_game_product_by_slug(slug) do
    Repo.get_by(GameProduct, slug: slug)
  end

  @doc "Load a product with scenario counts and summary stats."
  def get_product_with_stats(slug) do
    case get_game_product_by_slug(slug) do
      nil ->
        nil

      product ->
        scenario_count =
          from(s in Scenario, where: s.game_product_id == ^product.id, select: count())
          |> Repo.one()

        {product, %{scenario_count: scenario_count}}
    end
  end

  @doc "List published products with their scenario counts."
  def list_products_with_counts(opts \\ []) do
    products = list_game_products(opts)

    product_ids = Enum.map(products, & &1.id)

    counts =
      from(s in Scenario,
        where: s.game_product_id in ^product_ids,
        group_by: s.game_product_id,
        select: {s.game_product_id, count()}
      )
      |> Repo.all()
      |> Map.new()

    Enum.map(products, fn product ->
      {product, Map.get(counts, product.id, 0)}
    end)
  end

  def list_product_scenarios(product_id) do
    from(s in Scenario,
      where: s.game_product_id == ^product_id,
      preload: [:map],
      order_by: [asc: s.name]
    )
    |> Repo.all()
  end

  def create_game_product(attrs) do
    %GameProduct{}
    |> GameProduct.changeset(attrs)
    |> Repo.insert()
  end

  def update_game_product(%GameProduct{} = product, attrs) do
    product
    |> GameProduct.changeset(attrs)
    |> Repo.update()
  end

  defp maybe_filter_published(query, nil), do: query
  defp maybe_filter_published(query, published), do: where(query, [p], p.published == ^published)
end
