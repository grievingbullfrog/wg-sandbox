defmodule WargamePersistence.Units do
  @moduledoc "Context for unit template and leader persistence operations."

  import Ecto.Query
  alias WargamePersistence.Repo
  alias WargamePersistence.Schemas.{UnitTemplate, Leader}

  # --- Unit Templates ---

  def list_unit_templates(opts \\ []) do
    UnitTemplate
    |> filter_templates(opts)
    |> order_by([t], asc: t.nationality, asc: t.category, asc: t.name)
    |> Repo.all()
  end

  def get_unit_template!(id), do: Repo.get!(UnitTemplate, id)

  def get_unit_template(id), do: Repo.get(UnitTemplate, id)

  def create_unit_template(attrs) do
    %UnitTemplate{}
    |> UnitTemplate.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_unit_template(%UnitTemplate{} = template, attrs) do
    template
    |> UnitTemplate.changeset(attrs)
    |> Repo.update()
  end

  def delete_unit_template(%UnitTemplate{} = template) do
    Repo.delete(template)
  end

  def list_unit_templates_for_scenario(scenario_id) do
    from(t in UnitTemplate,
      join: su in "scenario_units",
      on: su.unit_template_id == t.id,
      where: su.scenario_id == ^scenario_id,
      distinct: true,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  # --- Leaders ---

  def list_leaders(opts \\ []) do
    Leader
    |> filter_leaders(opts)
    |> order_by([l], asc: l.nationality, asc: l.rank, asc: l.name)
    |> Repo.all()
  end

  def get_leader!(id), do: Repo.get!(Leader, id)

  def get_leader(id), do: Repo.get(Leader, id)

  def create_leader(attrs) do
    %Leader{}
    |> Leader.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_leader(%Leader{} = leader, attrs) do
    leader
    |> Leader.changeset(attrs)
    |> Repo.update()
  end

  def delete_leader(%Leader{} = leader) do
    Repo.delete(leader)
  end

  # --- Private ---

  defp filter_templates(query, opts) do
    query
    |> maybe_filter(opts[:nationality], :nationality)
    |> maybe_filter(opts[:era], :era)
    |> maybe_filter(opts[:category], :category)
  end

  defp filter_leaders(query, opts) do
    query
    |> maybe_filter(opts[:nationality], :nationality)
    |> maybe_filter(opts[:era], :era)
    |> maybe_filter(opts[:rank], :rank)
    |> maybe_filter_historical(opts[:is_historical])
  end

  defp maybe_filter(query, nil, _field), do: query
  defp maybe_filter(query, value, field), do: where(query, [r], field(r, ^field) == ^value)

  defp maybe_filter_historical(query, nil), do: query

  defp maybe_filter_historical(query, is_historical),
    do: where(query, [l], l.is_historical == ^is_historical)
end
