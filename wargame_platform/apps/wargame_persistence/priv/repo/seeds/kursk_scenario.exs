alias WargamePersistence.Repo
alias WargamePersistence.Schemas.ActionProfile
alias WargamePersistence.Schemas.Leader
alias WargamePersistence.Schemas.Scenario
alias WargamePersistence.Schemas.ScenarioUnit
alias WargamePersistence.Schemas.UnitTemplate
alias WargameCore.Hex.Coord

# Alias the Ecto Map schema with a distinct name
alias WargamePersistence.Schemas.Map, as: MapSchema

# =============================================================================
# Kursk Vignette - Summer 1943
# =============================================================================
#
# A small scenario demonstrating the full wargame system.
# 15x12 map with mixed terrain (open steppe, villages, a river).
# 6 units per side, 1 leader per side.
# 8-turn limit. VP hexes on key positions.
# Weather: clear first 4 turns, overcast last 4.

IO.puts("\n--- Seeding Kursk Vignette Scenario ---\n")

# --- Terrain helpers ---

apply_terrain = fn tiles, hex_list, terrain ->
  Enum.reduce(hex_list, tiles, fn {q, r}, acc ->
    coord = Coord.new(q, r)
    case Map.fetch(acc, coord) do
      {:ok, tile} -> Map.put(acc, coord, %{tile | terrain: terrain})
      :error -> acc
    end
  end)
end

apply_elevation = fn tiles, hex_list, elevation ->
  Enum.reduce(hex_list, tiles, fn {q, r}, acc ->
    coord = Coord.new(q, r)
    case Map.fetch(acc, coord) do
      {:ok, tile} -> Map.put(acc, coord, %{tile | elevation: elevation})
      :error -> acc
    end
  end)
end

apply_vp = fn tiles, vp_list ->
  Enum.reduce(vp_list, tiles, fn {{q, r}, vp}, acc ->
    coord = Coord.new(q, r)
    case Map.fetch(acc, coord) do
      {:ok, tile} -> Map.put(acc, coord, %{tile | victory_points: vp})
      :error -> acc
    end
  end)
end

# --- 1. Ensure action profile exists ---

action_profile =
  case Repo.get_by(ActionProfile, name: "WW2 Standard", era: "ww2") do
    nil ->
      IO.puts("ERROR: WW2 Standard action profile not found. Run base seeds first.")
      System.halt(1)

    profile ->
      IO.puts("Using action profile: #{profile.name} (#{profile.id})")
      profile
  end

# --- 2. Create the Kursk map ---

kursk_map =
  case Repo.get_by(MapSchema, name: "Kursk Southern Sector") do
    nil ->
      core_map = WargameCore.Map.new("kursk-south", 15, 12, 200)

      # River running N-S through columns 7-8
      river_hexes = [
        {7, 0}, {7, 1}, {7, 2}, {8, 3}, {8, 4}, {7, 5},
        {7, 6}, {8, 7}, {8, 8}, {7, 9}, {7, 10}, {7, 11}
      ]

      # Villages
      village_hexes = [{3, 3}, {5, 6}, {10, 4}, {12, 8}, {2, 9}]

      # Forest patches
      forest_hexes = [
        {4, 1}, {4, 2}, {5, 2}, {9, 7}, {9, 8}, {10, 8},
        {1, 5}, {1, 6}, {13, 2}, {13, 3}
      ]

      # Hills
      hill_hexes = [{6, 4}, {6, 5}, {11, 3}, {11, 4}, {3, 8}, {3, 9}]

      # VP objectives
      vp_hexes = [
        {{5, 6}, 5},   # Prokhorovka
        {{10, 4}, 5},  # Eastern heights
        {{3, 3}, 3},   # Western village
        {{12, 8}, 3}   # Southern village
      ]

      tiles =
        core_map.tiles
        |> apply_terrain.(river_hexes, :water)
        |> apply_terrain.(village_hexes, :town)
        |> apply_terrain.(forest_hexes, :forest)
        |> apply_terrain.(hill_hexes, :hill)
        |> apply_elevation.(hill_hexes, 100)
        |> apply_vp.(vp_hexes)

      core_map = %{core_map | tiles: tiles}
      tile_data = MapSchema.serialize_tile_data(core_map)

      %MapSchema{}
      |> MapSchema.changeset(%{
        name: "Kursk Southern Sector",
        description: "Southern sector of the Battle of Kursk, July 1943.",
        width: 15,
        height: 12,
        scale: 200,
        base_elevation: 0,
        default_terrain: "clear",
        tile_data: tile_data,
        metadata: %{
          "era" => "ww2",
          "location" => "Kursk, Russia",
          "date" => "July 1943"
        }
      })
      |> Repo.insert!()
      |> tap(fn m -> IO.puts("Created map: #{m.name} (#{m.id})") end)

    existing ->
      IO.puts("Map already exists: #{existing.name} (#{existing.id})")
      existing
  end

# --- 3. Look up unit templates ---

find_template = fn name, nationality ->
  Repo.get_by(UnitTemplate, name: name, nationality: nationality)
end

ger_infantry = find_template.("Infantry Platoon", "german")
ger_panzer = find_template.("Panzer IV Platoon", "german")
ger_panzergrenadier = find_template.("Panzergrenadier Platoon", "german")
ger_artillery = find_template.("105mm Artillery Battery", "german")

sov_infantry = find_template.("Rifle Platoon", "soviet")
sov_tank = find_template.("T-34/76 Platoon", "soviet")
sov_guards = find_template.("Guards Rifle Platoon", "soviet")
sov_artillery = find_template.("76mm Artillery Battery", "soviet")

all_german = [ger_infantry, ger_panzer, ger_panzergrenadier, ger_artillery] |> Enum.reject(&is_nil/1)
all_soviet = [sov_infantry, sov_tank, sov_guards, sov_artillery] |> Enum.reject(&is_nil/1)

if Enum.empty?(all_german) or Enum.empty?(all_soviet) do
  IO.puts("ERROR: Unit templates not found. Run ww2_eastern_front_units seed first.")
  IO.puts("Skipping scenario creation.")
else
  # --- 4. Look up leaders ---

  ger_leader = Repo.get_by(Leader, nationality: "german")
  sov_leader = Repo.get_by(Leader, nationality: "soviet")

  # --- 5. Create the scenario ---

  kursk_scenario =
    case Repo.get_by(Scenario, name: "Kursk Vignette - Prokhorovka") do
      nil ->
        %Scenario{}
        |> Scenario.changeset(%{
          name: "Kursk Vignette - Prokhorovka",
          description: "July 12, 1943. II SS-Panzer Corps pushes toward Prokhorovka against 5th Guards Tank Army.",
          era: "ww2",
          date_start: "1943-07-12",
          date_per_turn: "4 hours",
          max_turns: 8,
          first_move: "axis",
          map_id: kursk_map.id,
          action_profile_id: action_profile.id,
          sides: %{
            "sides" => [
              %{"id" => "axis", "name" => "Axis (Germany)", "forces" => ["german"]},
              %{"id" => "allied", "name" => "Allied (Soviet Union)", "forces" => ["soviet"]}
            ]
          },
          victory_conditions: %{
            "type" => "victory_points",
            "sudden_death_vp" => nil,
            "vp_levels" => %{"decisive" => 12, "tactical" => 8, "marginal" => 5},
            "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
          },
          weather_schedule: %{
            "schedule" => [
              %{"turns" => "1-4", "weather" => "clear", "ground" => "dry"},
              %{"turns" => "5-8", "weather" => "overcast", "ground" => "dry"}
            ]
          },
          supply_sources: %{
            "sources" => [
              %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
              %{"side" => "allied", "hex_q" => 14, "hex_r" => 6}
            ]
          },
          reinforcement_mode: "fixed",
          published: true
        })
        |> Repo.insert!()
        |> tap(fn s -> IO.puts("Created scenario: #{s.name} (#{s.id})") end)

      existing ->
        IO.puts("Scenario already exists: #{existing.name} (#{existing.id})")
        existing
    end

  # --- 6. Create scenario units ---

  existing_units = Repo.all(Ecto.assoc(kursk_scenario, :scenario_units))

  if Enum.empty?(existing_units) do
    pick = fn templates, preferred_name ->
      Enum.find(templates, hd(templates), &(&1.name == preferred_name))
    end

    unit_defs = [
      # German units (west side of map)
      %{name: "1/Das Reich PzGren", template: pick.(all_german, "Panzergrenadier Platoon"),
        side: "axis", force: "german", pq: 1, pr: 3, str: 10},
      %{name: "2/Das Reich PzGren", template: pick.(all_german, "Panzergrenadier Platoon"),
        side: "axis", force: "german", pq: 1, pr: 5, str: 10},
      %{name: "1/Das Reich Panzer", template: pick.(all_german, "Panzer IV Platoon"),
        side: "axis", force: "german", pq: 2, pr: 4, str: 10},
      %{name: "2/Totenkopf Panzer", template: pick.(all_german, "Panzer IV Platoon"),
        side: "axis", force: "german", pq: 2, pr: 6, str: 8},
      %{name: "SS Artillery Btry", template: pick.(all_german, "105mm Artillery Battery"),
        side: "axis", force: "german", pq: 0, pr: 5, str: 10},
      %{name: "Totenkopf Infantry", template: pick.(all_german, "Infantry Platoon"),
        side: "axis", force: "german", pq: 1, pr: 7, str: 10},

      # Soviet units (east side of map)
      %{name: "1/5th Gds Rifle", template: pick.(all_soviet, "Guards Rifle Platoon"),
        side: "allied", force: "soviet", pq: 9, pr: 4, str: 10},
      %{name: "2/5th Gds Rifle", template: pick.(all_soviet, "Guards Rifle Platoon"),
        side: "allied", force: "soviet", pq: 9, pr: 6, str: 10},
      %{name: "1/18th Tank Corps", template: pick.(all_soviet, "T-34/76 Platoon"),
        side: "allied", force: "soviet", pq: 11, pr: 5, str: 10},
      %{name: "2/29th Tank Corps", template: pick.(all_soviet, "T-34/76 Platoon"),
        side: "allied", force: "soviet", pq: 12, pr: 4, str: 8},
      %{name: "Gds Artillery Btry", template: pick.(all_soviet, "76mm Artillery Battery"),
        side: "allied", force: "soviet", pq: 13, pr: 6, str: 10},
      %{name: "3/5th Gds Rifle", template: pick.(all_soviet, "Rifle Platoon"),
        side: "allied", force: "soviet", pq: 10, pr: 7, str: 10}
    ]

    for u <- unit_defs do
      %ScenarioUnit{}
      |> ScenarioUnit.changeset(%{
        scenario_id: kursk_scenario.id,
        unit_template_id: u.template.id,
        name: u.name,
        side: u.side,
        force: u.force,
        position_q: u.pq,
        position_r: u.pr,
        arrives_turn: 1,
        strength: u.str,
        experience: 2,
        morale: 60
      })
      |> Repo.insert!()
    end

    IO.puts("Created #{length(unit_defs)} scenario units")

    # Assign leaders
    if ger_leader do
      Repo.all(Ecto.assoc(kursk_scenario, :scenario_units))
      |> Enum.find(&(&1.side == "axis"))
      |> case do
        nil -> :ok
        unit ->
          unit |> ScenarioUnit.changeset(%{leader_id: ger_leader.id}) |> Repo.update!()
          IO.puts("Assigned German leader: #{ger_leader.name}")
      end
    end

    if sov_leader do
      Repo.all(Ecto.assoc(kursk_scenario, :scenario_units))
      |> Enum.find(&(&1.side == "allied"))
      |> case do
        nil -> :ok
        unit ->
          unit |> ScenarioUnit.changeset(%{leader_id: sov_leader.id}) |> Repo.update!()
          IO.puts("Assigned Soviet leader: #{sov_leader.name}")
      end
    end
  else
    IO.puts("Scenario units already exist (#{length(existing_units)} units)")
  end
end

IO.puts("\n--- Kursk Vignette seeding complete ---\n")
