defmodule WargamePersistence.Scenarios do
  @moduledoc "Context for scenario, action profile, and scenario unit persistence."

  import Ecto.Query
  alias WargamePersistence.Repo
  alias WargamePersistence.Schemas.{ActionProfile, Scenario, ScenarioUnit}

  # --- Action Profiles ---

  def list_action_profiles(opts \\ []) do
    ActionProfile
    |> maybe_filter_era(opts[:era])
    |> order_by([a], asc: a.era, asc: a.name)
    |> Repo.all()
  end

  def get_action_profile!(id), do: Repo.get!(ActionProfile, id)

  def create_action_profile(attrs) do
    %ActionProfile{}
    |> ActionProfile.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_action_profile(%ActionProfile{} = profile, attrs) do
    profile
    |> ActionProfile.changeset(attrs)
    |> Repo.update()
  end

  def delete_action_profile(%ActionProfile{} = profile) do
    Repo.delete(profile)
  end

  # --- Scenarios ---

  def list_scenarios(opts \\ []) do
    Scenario
    |> maybe_filter_era(opts[:era])
    |> maybe_filter_published(opts[:published])
    |> order_by([s], desc: s.updated_at)
    |> Repo.all()
  end

  def get_scenario!(id) do
    Repo.get!(Scenario, id)
  end

  def create_scenario(attrs) do
    %Scenario{}
    |> Scenario.create_changeset(attrs)
    |> Repo.insert()
  end

  def update_scenario(%Scenario{} = scenario, attrs) do
    scenario
    |> Scenario.changeset(attrs)
    |> Repo.update()
  end

  def delete_scenario(%Scenario{} = scenario) do
    Repo.delete(scenario)
  end

  @doc """
  Load a scenario with all associations preloaded.
  """
  def load_full_scenario(id) do
    Scenario
    |> Repo.get(id)
    |> case do
      nil ->
        nil

      scenario ->
        Repo.preload(scenario, [
          :map,
          :action_profile,
          scenario_units: [:unit_template, :leader]
        ])
    end
  end

  # --- Scenario Units ---

  def list_scenario_units(scenario_id) do
    from(su in ScenarioUnit,
      where: su.scenario_id == ^scenario_id,
      preload: [:unit_template, :leader],
      order_by: [asc: su.side, asc: su.arrives_turn, asc: su.name]
    )
    |> Repo.all()
  end

  def create_scenario_unit(attrs) do
    %ScenarioUnit{}
    |> ScenarioUnit.create_changeset(attrs)
    |> Repo.insert()
  end

  def batch_create_scenario_units(units_attrs) do
    Repo.transaction(fn ->
      Enum.map(units_attrs, fn attrs ->
        case create_scenario_unit(attrs) do
          {:ok, unit} -> unit
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  def update_scenario_unit(%ScenarioUnit{} = unit, attrs) do
    unit
    |> ScenarioUnit.changeset(attrs)
    |> Repo.update()
  end

  def delete_scenario_unit(%ScenarioUnit{} = unit) do
    Repo.delete(unit)
  end

  # --- Private ---

  defp maybe_filter_era(query, nil), do: query
  defp maybe_filter_era(query, era), do: where(query, [r], r.era == ^era)

  defp maybe_filter_published(query, nil), do: query
  defp maybe_filter_published(query, published), do: where(query, [r], r.published == ^published)
end
