import Ecto.Query
alias WargamePersistence.Repo
alias WargamePersistence.Schemas.{ActionProfile, GameProduct, Leader, Scenario, ScenarioUnit, UnitTemplate}
alias WargamePersistence.Schemas.Map, as: MapSchema
alias WargameCore.Hex.Coord

# =============================================================================
# East Front 1941 - Game Product
# =============================================================================
#
# Operation Barbarossa and the first year of the Eastern Front.
# 10 scenarios covering June 1941 - January 1942.

IO.puts("\n--- Seeding East Front 1941 Product ---\n")

# --- 1. Create or find the game product ---

product =
  case Repo.get_by(GameProduct, slug: "east-front-1941") do
    nil ->
      {:ok, p} =
        %GameProduct{}
        |> GameProduct.changeset(%{
          name: "East Front 1941",
          slug: "east-front-1941",
          tagline: "Operation Barbarossa - the Eastern Front",
          description: "June 1941 to January 1942. Command German or Soviet forces through the largest military operation in history. From the border battles to the gates of Moscow.",
          era: "ww2",
          published: true,
          metadata: %{
            "theater" => "Eastern Front",
            "period" => "1941",
            "designer_notes" => "10 scenarios of increasing complexity covering the first year of the German-Soviet war."
          }
        })
        |> Repo.insert()

      IO.puts("Created product: #{p.name} (#{p.id})")
      p

    existing ->
      IO.puts("Product already exists: #{existing.name} (#{existing.id})")
      existing
  end

# --- 2. Find action profile ---

action_profile =
  case Repo.get_by(ActionProfile, name: "WW2 Standard", era: "ww2") do
    nil ->
      IO.puts("ERROR: WW2 Standard action profile not found. Run base seeds first.")
      System.halt(1)

    profile ->
      profile
  end

# --- 3. Associate existing unit templates and leaders with the product ---

# Update unit templates to belong to this product
from(t in UnitTemplate, where: t.era == "ww2" and is_nil(t.game_product_id))
|> Repo.update_all(set: [game_product_id: product.id])

from(l in Leader, where: l.era == "ww2" and is_nil(l.game_product_id))
|> Repo.update_all(set: [game_product_id: product.id])

# --- 4. Lookup unit templates ---

find_template = fn name, nationality ->
  Repo.get_by(UnitTemplate, name: name, nationality: nationality)
end

# German templates
ger_inf = find_template.("Infantry Platoon", "german")
ger_pzgren = find_template.("Panzergrenadier Platoon", "german")
ger_pz4 = find_template.("Panzer IV", "german")
ger_panther = find_template.("Panzer V Panther", "german")
ger_stug = find_template.("StuG III", "german")
ger_88 = find_template.("88mm AT Gun", "german")
ger_arty = find_template.("105mm Howitzer", "german")
ger_recon = find_template.("Recon Halftrack", "german")
ger_pioneer = find_template.("Pioneer Platoon", "german")

# Soviet templates
sov_rifle = find_template.("Rifle Platoon", "soviet")
sov_guards = find_template.("Guards Rifle Platoon", "soviet")
sov_t34_76 = find_template.("T-34/76", "soviet")
sov_kv1 = find_template.("KV-1", "soviet")
sov_su76 = find_template.("SU-76", "soviet")
sov_76at = find_template.("76mm AT Gun", "soviet")
sov_arty = find_template.("122mm Howitzer", "soviet")
sov_recon = find_template.("Recon Company", "soviet")
sov_eng = find_template.("Engineer Platoon", "soviet")

# Verify we have templates
all_ger = [ger_inf, ger_pzgren, ger_pz4, ger_stug, ger_arty, ger_recon] |> Enum.reject(&is_nil/1)
all_sov = [sov_rifle, sov_t34_76, sov_kv1, sov_arty, sov_recon] |> Enum.reject(&is_nil/1)

if Enum.empty?(all_ger) or Enum.empty?(all_sov) do
  IO.puts("ERROR: Unit templates not found. Run ww2_eastern_front_units seed first.")
  IO.puts("Skipping East Front 1941 scenario creation.")
else
  # --- Helpers ---

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

  create_map = fn name, width, height, terrain_fn ->
    case Repo.get_by(MapSchema, name: name) do
      nil ->
        core_map = WargameCore.Map.new(name, width, height, 500)
        tiles = terrain_fn.(core_map.tiles)
        core_map = %{core_map | tiles: tiles}
        tile_data = MapSchema.serialize_tile_data(core_map)

        %MapSchema{}
        |> MapSchema.changeset(%{
          name: name,
          width: width,
          height: height,
          scale: 500,
          base_elevation: 0,
          default_terrain: "clear",
          tile_data: tile_data,
          game_product_id: product.id,
          metadata: %{"era" => "ww2", "theater" => "Eastern Front"}
        })
        |> Repo.insert!()
        |> tap(fn m -> IO.puts("  Created map: #{m.name}") end)

      existing ->
        existing
    end
  end

  create_scenario = fn attrs ->
    case Repo.get_by(Scenario, name: attrs.name) do
      nil ->
        %Scenario{}
        |> Scenario.changeset(attrs)
        |> Repo.insert!()
        |> tap(fn s -> IO.puts("  Created scenario: #{s.name}") end)

      existing ->
        IO.puts("  Scenario exists: #{existing.name}")
        existing
    end
  end

  create_units = fn scenario, unit_defs ->
    existing = Repo.all(Ecto.assoc(scenario, :scenario_units))
    if Enum.empty?(existing) do
      for u <- unit_defs do
        %ScenarioUnit{}
        |> ScenarioUnit.changeset(%{
          scenario_id: scenario.id,
          unit_template_id: u.template.id,
          name: u.name,
          side: u.side,
          force: u.force,
          position_q: u.pq,
          position_r: u.pr,
          arrives_turn: Map.get(u, :arrives, 1),
          strength: Map.get(u, :str, 10),
          experience: Map.get(u, :exp, 2),
          morale: Map.get(u, :morale, 60)
        })
        |> Repo.insert!()
      end
      IO.puts("    #{length(unit_defs)} units created")
    else
      IO.puts("    Units already exist (#{length(existing)})")
    end
  end

  # =========================================================================
  # SCENARIO 1: Border Clash
  # =========================================================================
  IO.puts("\n  [1/10] Border Clash")

  border_map = create_map.("Border Clash - Bug River", 10, 8, fn tiles ->
    tiles
    |> apply_terrain.([{4, 0}, {4, 1}, {5, 2}, {5, 3}, {4, 4}, {4, 5}, {5, 6}, {5, 7}], :water)
    |> apply_terrain.([{3, 2}, {6, 5}], :town)
    |> apply_terrain.([{1, 1}, {2, 1}, {7, 3}, {8, 4}], :forest)
    |> apply_vp.([{{3, 2}, 5}, {{6, 5}, 5}])
  end)

  border_scenario = create_scenario.(%{
    name: "Border Clash",
    description: "June 22, 1941. Dawn. German forces launch a surprise crossing of the Bug River against unprepared Soviet border guards.",
    era: "ww2",
    date_start: "1941-06-22",
    date_per_turn: "2 hours",
    max_turns: 6,
    first_move: "axis",
    map_id: border_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 8, "tactical" => 5, "marginal" => 3},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-6", "weather" => "clear", "ground" => "dry"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 4},
      %{"side" => "allied", "hex_q" => 9, "hex_r" => 4}
    ]}
  })

  create_units.(border_scenario, [
    %{name: "1/IR 45", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 2, str: 10},
    %{name: "2/IR 45", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 4, str: 10},
    %{name: "1/PR 18", template: ger_pz4, side: "axis", force: "german", pq: 0, pr: 3, str: 10},
    %{name: "Aufkl 3", template: ger_recon, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "87th Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 2, str: 8, morale: 40},
    %{name: "124th Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 7, pr: 4, str: 8, morale: 40},
    %{name: "41st Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 6, str: 8, morale: 40},
    %{name: "Border AT", template: sov_76at, side: "allied", force: "soviet", pq: 5, pr: 3, str: 5, morale: 45}
  ])

  # =========================================================================
  # SCENARIO 2: Fortress Brest
  # =========================================================================
  IO.puts("\n  [2/10] Fortress Brest")

  brest_map = create_map.("Fortress Brest", 8, 8, fn tiles ->
    tiles
    |> apply_terrain.([{3, 3}, {3, 4}, {4, 3}, {4, 4}], :town)
    |> apply_terrain.([{2, 2}, {2, 3}, {2, 4}, {2, 5}, {5, 2}, {5, 3}, {5, 4}, {5, 5}], :town)
    |> apply_terrain.([{0, 3}, {0, 4}, {1, 3}, {1, 4}], :forest)
    |> apply_terrain.([{6, 0}, {7, 1}, {6, 6}, {7, 7}], :forest)
    |> apply_vp.([{{3, 3}, 5}, {{4, 4}, 5}, {{3, 4}, 3}, {{4, 3}, 3}])
  end)

  brest_scenario = create_scenario.(%{
    name: "Fortress Brest",
    description: "June 22, 1941. The garrison of Brest Fortress fights a desperate defense against the German 45th Infantry Division.",
    era: "ww2",
    date_start: "1941-06-22",
    date_per_turn: "4 hours",
    max_turns: 6,
    first_move: "axis",
    map_id: brest_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 14, "tactical" => 10, "marginal" => 6},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-6", "weather" => "clear", "ground" => "dry"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 3},
      %{"side" => "allied", "hex_q" => 3, "hex_r" => 3}
    ]}
  })

  create_units.(brest_scenario, [
    %{name: "1/IR 130", template: ger_inf, side: "axis", force: "german", pq: 0, pr: 2, str: 10},
    %{name: "2/IR 130", template: ger_inf, side: "axis", force: "german", pq: 0, pr: 5, str: 10},
    %{name: "3/IR 135", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 1, str: 10},
    %{name: "Pio 81", template: ger_pioneer, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "Art 98", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 4, str: 5},
    %{name: "6th Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 3, pr: 3, str: 10, morale: 70},
    %{name: "42nd Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 4, pr: 4, str: 10, morale: 70},
    %{name: "44th Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 4, pr: 3, str: 8, morale: 65},
    %{name: "33rd Eng", template: sov_eng, side: "allied", force: "soviet", pq: 3, pr: 4, str: 8, morale: 65}
  ])

  # =========================================================================
  # SCENARIO 3: Tank Battle at Brody
  # =========================================================================
  IO.puts("\n  [3/10] Tank Battle at Brody")

  brody_map = create_map.("Brody Battlefield", 15, 10, fn tiles ->
    tiles
    |> apply_terrain.([{3, 2}, {3, 3}, {10, 5}, {11, 6}], :forest)
    |> apply_terrain.([{7, 4}, {7, 5}], :town)
    |> apply_terrain.([{12, 3}], :town)
    |> apply_elevation.([{5, 2}, {5, 3}, {6, 3}, {9, 6}, {10, 7}], 50)
    |> apply_vp.([{{7, 4}, 5}, {{7, 5}, 3}, {{12, 3}, 3}])
  end)

  brody_scenario = create_scenario.(%{
    name: "Tank Battle at Brody",
    description: "June 26-30, 1941. The largest tank battle of the early war as Soviet mechanized corps counterattack the German 1st Panzer Group near Brody.",
    era: "ww2",
    date_start: "1941-06-26",
    date_per_turn: "4 hours",
    max_turns: 8,
    first_move: "allied",
    map_id: brody_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 10, "tactical" => 7, "marginal" => 4},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-4", "weather" => "clear", "ground" => "dry"},
      %{"turns" => "5-8", "weather" => "overcast", "ground" => "dry"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 14, "hex_r" => 5}
    ]}
  })

  create_units.(brody_scenario, [
    %{name: "1/11th Pz", template: ger_pz4, side: "axis", force: "german", pq: 3, pr: 4, str: 10},
    %{name: "2/16th Pz", template: ger_pz4, side: "axis", force: "german", pq: 4, pr: 6, str: 10},
    %{name: "PzGren 11", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 5, str: 10},
    %{name: "PzGren 16", template: ger_pzgren, side: "axis", force: "german", pq: 3, pr: 7, str: 10},
    %{name: "Flak 88", template: ger_88, side: "axis", force: "german", pq: 5, pr: 5, str: 5},
    %{name: "Art Abt 119", template: ger_arty, side: "axis", force: "german", pq: 1, pr: 5, str: 5},
    %{name: "8th Mech T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 11, pr: 3, str: 10},
    %{name: "15th Mech T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 12, pr: 5, str: 10},
    %{name: "4th Mech KV-1", template: sov_kv1, side: "allied", force: "soviet", pq: 13, pr: 4, str: 8},
    %{name: "8th Mech Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 10, pr: 4, str: 10},
    %{name: "15th Mech Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 11, pr: 6, str: 10},
    %{name: "4th Mech Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 12, pr: 3, str: 10},
    %{name: "Arty 15th", template: sov_arty, side: "allied", force: "soviet", pq: 13, pr: 6, str: 5}
  ])

  # =========================================================================
  # SCENARIO 4: Road to Minsk
  # =========================================================================
  IO.puts("\n  [4/10] Road to Minsk")

  minsk_map = create_map.("Road to Minsk", 18, 10, fn tiles ->
    tiles
    |> apply_terrain.([{4, 3}, {4, 4}, {4, 5}, {12, 3}, {12, 4}, {12, 5}], :forest)
    |> apply_terrain.([{8, 4}, {8, 5}, {15, 4}], :town)
    |> apply_terrain.([{6, 2}, {6, 3}, {6, 7}, {6, 8}], :water)
    |> apply_elevation.([{9, 2}, {10, 2}, {10, 3}], 50)
    |> apply_vp.([{{8, 4}, 5}, {{15, 4}, 8}, {{8, 5}, 3}])
  end)

  minsk_scenario = create_scenario.(%{
    name: "Road to Minsk",
    description: "June 24-28, 1941. Guderian's 2nd Panzer Group races eastward toward Minsk, seeking to encircle the Soviet Western Front.",
    era: "ww2",
    date_start: "1941-06-24",
    date_per_turn: "4 hours",
    max_turns: 10,
    first_move: "axis",
    map_id: minsk_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 14, "tactical" => 10, "marginal" => 6},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-10", "weather" => "clear", "ground" => "dry"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 17, "hex_r" => 5}
    ]}
  })

  create_units.(minsk_scenario, [
    %{name: "3rd Panzer Div", template: ger_pz4, side: "axis", force: "german", pq: 1, pr: 4, str: 10},
    %{name: "4th Panzer Div", template: ger_pz4, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "PzGren 3", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 3, str: 10},
    %{name: "PzGren 4", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 5, str: 10},
    %{name: "Aufkl 3rd", template: ger_recon, side: "axis", force: "german", pq: 0, pr: 4, str: 5},
    %{name: "Art 3rd Pz", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "100th Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 9, pr: 3, str: 8, morale: 45},
    %{name: "161st Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 9, pr: 5, str: 8, morale: 45},
    %{name: "7th Tank KV-1", template: sov_kv1, side: "allied", force: "soviet", pq: 14, pr: 4, str: 8},
    %{name: "Minsk Garrison", template: sov_rifle, side: "allied", force: "soviet", pq: 15, pr: 4, str: 10, morale: 50},
    %{name: "Arty 100th", template: sov_arty, side: "allied", force: "soviet", pq: 10, pr: 4, str: 5}
  ])

  # =========================================================================
  # SCENARIO 5: Smolensk Pocket
  # =========================================================================
  IO.puts("\n  [5/10] Smolensk Pocket")

  smolensk_map = create_map.("Smolensk Region", 15, 12, fn tiles ->
    tiles
    |> apply_terrain.([{7, 0}, {7, 1}, {7, 2}, {8, 3}, {8, 4}, {7, 5}, {7, 6}, {8, 7}, {8, 8}, {7, 9}, {7, 10}, {7, 11}], :water)
    |> apply_terrain.([{10, 4}, {10, 5}, {11, 5}], :town)
    |> apply_terrain.([{3, 2}, {3, 3}, {4, 8}, {4, 9}, {12, 1}, {12, 2}, {13, 8}, {13, 9}], :forest)
    |> apply_elevation.([{5, 3}, {5, 4}, {6, 3}, {11, 7}, {11, 8}], 80)
    |> apply_vp.([{{10, 4}, 5}, {{10, 5}, 5}, {{5, 3}, 3}])
  end)

  smolensk_scenario = create_scenario.(%{
    name: "Smolensk Pocket",
    description: "July 10-Aug 5, 1941. German panzers attempt to encircle Soviet forces around Smolensk in a critical battle for the road to Moscow.",
    era: "ww2",
    date_start: "1941-07-10",
    date_per_turn: "1 day",
    max_turns: 8,
    first_move: "axis",
    map_id: smolensk_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 12, "tactical" => 8, "marginal" => 5},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-5", "weather" => "clear", "ground" => "dry"},
      %{"turns" => "6-8", "weather" => "rain", "ground" => "mud"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 14, "hex_r" => 6}
    ]}
  })

  create_units.(smolensk_scenario, [
    %{name: "29th Mot Div", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 3, str: 10},
    %{name: "7th Panzer", template: ger_pz4, side: "axis", force: "german", pq: 2, pr: 5, str: 10},
    %{name: "20th Panzer", template: ger_pz4, side: "axis", force: "german", pq: 3, pr: 7, str: 10},
    %{name: "IR 71", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 4, str: 10},
    %{name: "IR 78", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "StuG 192", template: ger_stug, side: "axis", force: "german", pq: 3, pr: 4, str: 8},
    %{name: "Art Abt 7", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "16th Army Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 9, pr: 4, str: 10},
    %{name: "20th Army Rifle", template: sov_rifle, side: "allied", force: "soviet", pq: 10, pr: 6, str: 10},
    %{name: "5th Mech T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 11, pr: 5, str: 8},
    %{name: "Gds Rifle", template: sov_guards, side: "allied", force: "soviet", pq: 10, pr: 4, str: 10, morale: 70},
    %{name: "AT Bn 16th", template: sov_76at, side: "allied", force: "soviet", pq: 9, pr: 5, str: 5},
    %{name: "Arty 20th Army", template: sov_arty, side: "allied", force: "soviet", pq: 12, pr: 5, str: 5}
  ])

  # =========================================================================
  # SCENARIO 6: Kiev Encirclement
  # =========================================================================
  IO.puts("\n  [6/10] Kiev Encirclement")

  kiev_map = create_map.("Kiev Region", 20, 15, fn tiles ->
    tiles
    |> apply_terrain.([{10, 0}, {10, 1}, {10, 2}, {10, 3}, {9, 4}, {9, 5}, {10, 6}, {10, 7}, {10, 8}, {9, 9}, {9, 10}, {10, 11}, {10, 12}, {10, 13}, {10, 14}], :water)
    |> apply_terrain.([{10, 4}, {10, 5}, {11, 4}, {11, 5}], :town)
    |> apply_terrain.([{5, 6}, {15, 8}], :town)
    |> apply_terrain.([{3, 2}, {3, 3}, {4, 2}, {7, 10}, {8, 10}, {16, 3}, {17, 3}, {16, 11}, {17, 12}], :forest)
    |> apply_elevation.([{8, 3}, {8, 4}, {12, 8}, {12, 9}, {13, 9}], 60)
    |> apply_vp.([{{10, 4}, 8}, {{10, 5}, 5}, {{5, 6}, 3}, {{15, 8}, 3}])
  end)

  kiev_scenario = create_scenario.(%{
    name: "Kiev Encirclement",
    description: "September 1941. The German pincers close around Kiev in the largest encirclement in military history. Can the Soviets escape the trap?",
    era: "ww2",
    date_start: "1941-09-15",
    date_per_turn: "1 day",
    max_turns: 12,
    first_move: "axis",
    map_id: kiev_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 16, "tactical" => 11, "marginal" => 7},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-8", "weather" => "clear", "ground" => "dry"},
      %{"turns" => "9-12", "weather" => "rain", "ground" => "mud"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 7},
      %{"side" => "allied", "hex_q" => 19, "hex_r" => 7}
    ]}
  })

  create_units.(kiev_scenario, [
    # German Northern Pincer
    %{name: "2nd Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 3, pr: 2, str: 10},
    %{name: "PzGren 2nd", template: ger_pzgren, side: "axis", force: "german", pq: 4, pr: 3, str: 10},
    %{name: "IR 2nd Army", template: ger_inf, side: "axis", force: "german", pq: 2, pr: 4, str: 10},
    # German Southern Pincer
    %{name: "1st Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 3, pr: 11, str: 10},
    %{name: "PzGren 1st", template: ger_pzgren, side: "axis", force: "german", pq: 4, pr: 10, str: 10},
    %{name: "IR 17th Army", template: ger_inf, side: "axis", force: "german", pq: 2, pr: 9, str: 10},
    # German support
    %{name: "Art 6th Army", template: ger_arty, side: "axis", force: "german", pq: 1, pr: 6, str: 5},
    %{name: "StuG 6th", template: ger_stug, side: "axis", force: "german", pq: 3, pr: 7, str: 8},
    # Soviet defenders
    %{name: "37th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 11, pr: 4, str: 10},
    %{name: "26th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 12, pr: 6, str: 10},
    %{name: "38th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 11, pr: 8, str: 10},
    %{name: "21st Army", template: sov_rifle, side: "allied", force: "soviet", pq: 13, pr: 10, str: 8},
    %{name: "5th Cav KV-1", template: sov_kv1, side: "allied", force: "soviet", pq: 12, pr: 5, str: 8},
    %{name: "Kiev T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 10, pr: 5, str: 8},
    %{name: "Arty Kiev", template: sov_arty, side: "allied", force: "soviet", pq: 11, pr: 5, str: 5},
    %{name: "AT Bn 37th", template: sov_76at, side: "allied", force: "soviet", pq: 9, pr: 5, str: 5}
  ])

  # =========================================================================
  # SCENARIO 7: Vyazma Defense
  # =========================================================================
  IO.puts("\n  [7/10] Vyazma Defense")

  vyazma_map = create_map.("Vyazma Approaches", 12, 10, fn tiles ->
    tiles
    |> apply_terrain.([{2, 3}, {3, 3}, {3, 4}, {8, 5}, {9, 5}, {9, 6}], :forest)
    |> apply_terrain.([{6, 4}, {6, 5}, {10, 3}], :town)
    |> apply_terrain.([{5, 0}, {5, 1}, {5, 8}, {5, 9}], :water)
    |> apply_elevation.([{4, 4}, {4, 5}, {7, 3}, {7, 4}], 60)
    |> apply_vp.([{{6, 4}, 5}, {{6, 5}, 5}, {{10, 3}, 3}])
  end)

  vyazma_scenario = create_scenario.(%{
    name: "Vyazma Defense",
    description: "October 2, 1941. Operation Typhoon begins. Soviet forces must delay the German drive on Moscow at Vyazma.",
    era: "ww2",
    date_start: "1941-10-02",
    date_per_turn: "1 day",
    max_turns: 8,
    first_move: "axis",
    map_id: vyazma_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 12, "tactical" => 8, "marginal" => 5},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-3", "weather" => "clear", "ground" => "dry"},
      %{"turns" => "4-6", "weather" => "rain", "ground" => "mud"},
      %{"turns" => "7-8", "weather" => "clear", "ground" => "dry"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 11, "hex_r" => 5}
    ]}
  })

  create_units.(vyazma_scenario, [
    %{name: "3rd Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 1, pr: 3, str: 10},
    %{name: "4th Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "PzGren 3rd", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 4, str: 10},
    %{name: "IR 9th Army", template: ger_inf, side: "axis", force: "german", pq: 2, pr: 5, str: 10},
    %{name: "Art Grp W", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "19th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 3, str: 10, morale: 50},
    %{name: "20th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 5, str: 10, morale: 50},
    %{name: "24th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 7, pr: 4, str: 8, morale: 50},
    %{name: "T-34 Reserve", template: sov_t34_76, side: "allied", force: "soviet", pq: 9, pr: 4, str: 8},
    %{name: "Gds AT Bn", template: sov_76at, side: "allied", force: "soviet", pq: 6, pr: 4, str: 5, morale: 65},
    %{name: "Arty 20th", template: sov_arty, side: "allied", force: "soviet", pq: 8, pr: 5, str: 5}
  ])

  # =========================================================================
  # SCENARIO 8: Gates of Moscow
  # =========================================================================
  IO.puts("\n  [8/10] Gates of Moscow")

  moscow_map = create_map.("Moscow Approaches", 15, 12, fn tiles ->
    tiles
    |> apply_terrain.([{2, 2}, {2, 3}, {3, 2}, {5, 7}, {5, 8}, {6, 8}, {9, 2}, {10, 2}, {12, 6}, {12, 7}, {13, 7}], :forest)
    |> apply_terrain.([{7, 5}, {7, 6}, {13, 4}], :town)
    |> apply_terrain.([{6, 0}, {6, 1}, {6, 10}, {6, 11}], :water)
    |> apply_elevation.([{4, 4}, {4, 5}, {5, 4}, {10, 6}, {10, 7}, {11, 7}], 50)
    |> apply_vp.([{{7, 5}, 5}, {{7, 6}, 5}, {{13, 4}, 5}])
  end)

  moscow_scenario = create_scenario.(%{
    name: "Gates of Moscow",
    description: "November 15-December 5, 1941. The final German push toward Moscow. Can the Wehrmacht break through the last Soviet defensive lines?",
    era: "ww2",
    date_start: "1941-11-15",
    date_per_turn: "1 day",
    max_turns: 10,
    first_move: "axis",
    map_id: moscow_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 14, "tactical" => 10, "marginal" => 6},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-3", "weather" => "overcast", "ground" => "frozen"},
      %{"turns" => "4-7", "weather" => "snow", "ground" => "frozen"},
      %{"turns" => "8-10", "weather" => "blizzard", "ground" => "frozen"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 14, "hex_r" => 6}
    ]}
  })

  create_units.(moscow_scenario, [
    %{name: "2nd Panzer", template: ger_pz4, side: "axis", force: "german", pq: 2, pr: 3, str: 8, morale: 55},
    %{name: "5th Panzer", template: ger_pz4, side: "axis", force: "german", pq: 2, pr: 7, str: 8, morale: 55},
    %{name: "PzGren SS DR", template: ger_pzgren, side: "axis", force: "german", pq: 3, pr: 5, str: 10, morale: 70},
    %{name: "IR 258th", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 4, str: 10},
    %{name: "IR 267th", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "StuG 185", template: ger_stug, side: "axis", force: "german", pq: 3, pr: 4, str: 8},
    %{name: "Art 4th Pz", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "16th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 7, pr: 4, str: 10, morale: 65},
    %{name: "5th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 8, pr: 6, str: 10, morale: 65},
    %{name: "33rd Army", template: sov_rifle, side: "allied", force: "soviet", pq: 9, pr: 5, str: 10, morale: 60},
    %{name: "1st Gds T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 10, pr: 5, str: 10, morale: 70},
    %{name: "Gds Rifle Res", template: sov_guards, side: "allied", force: "soviet", pq: 12, pr: 5, str: 10, morale: 75, arrives: 3},
    %{name: "Arty Moscow", template: sov_arty, side: "allied", force: "soviet", pq: 11, pr: 5, str: 5},
    %{name: "AT Bde 16th", template: sov_76at, side: "allied", force: "soviet", pq: 7, pr: 5, str: 5, morale: 65}
  ])

  # =========================================================================
  # SCENARIO 9: Tula Standoff
  # =========================================================================
  IO.puts("\n  [9/10] Tula Standoff")

  tula_map = create_map.("Tula Region", 12, 10, fn tiles ->
    tiles
    |> apply_terrain.([{3, 2}, {4, 2}, {4, 3}, {8, 5}, {8, 6}, {9, 6}], :forest)
    |> apply_terrain.([{6, 4}, {6, 5}, {7, 4}], :town)
    |> apply_terrain.([{5, 1}, {5, 2}, {5, 8}, {5, 9}], :water)
    |> apply_elevation.([{7, 3}, {8, 3}, {8, 4}], 50)
    |> apply_vp.([{{6, 4}, 8}, {{6, 5}, 5}])
  end)

  tula_scenario = create_scenario.(%{
    name: "Tula Standoff",
    description: "October-November 1941. Guderian's panzers attempt to take the industrial city of Tula, the last major obstacle south of Moscow.",
    era: "ww2",
    date_start: "1941-10-29",
    date_per_turn: "1 day",
    max_turns: 8,
    first_move: "axis",
    map_id: tula_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 12, "tactical" => 8, "marginal" => 5},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-3", "weather" => "overcast", "ground" => "mud"},
      %{"turns" => "4-8", "weather" => "snow", "ground" => "frozen"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 5},
      %{"side" => "allied", "hex_q" => 11, "hex_r" => 5}
    ]}
  })

  create_units.(tula_scenario, [
    %{name: "2nd Panzer Div", template: ger_pz4, side: "axis", force: "german", pq: 2, pr: 4, str: 8, morale: 55},
    %{name: "Grossdeutschland", template: ger_pzgren, side: "axis", force: "german", pq: 2, pr: 5, str: 10, morale: 70},
    %{name: "IR 296th", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 3, str: 10},
    %{name: "IR 167th", template: ger_inf, side: "axis", force: "german", pq: 1, pr: 6, str: 10},
    %{name: "StuG 2nd Pz", template: ger_stug, side: "axis", force: "german", pq: 3, pr: 5, str: 8},
    %{name: "Art 2nd Pz", template: ger_arty, side: "axis", force: "german", pq: 0, pr: 5, str: 5},
    %{name: "50th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 3, str: 10, morale: 65},
    %{name: "Tula Workers", template: sov_rifle, side: "allied", force: "soviet", pq: 6, pr: 5, str: 8, morale: 70},
    %{name: "Tula AT Bde", template: sov_76at, side: "allied", force: "soviet", pq: 6, pr: 4, str: 5, morale: 65},
    %{name: "T-34 Reserve", template: sov_t34_76, side: "allied", force: "soviet", pq: 8, pr: 4, str: 8, morale: 60},
    %{name: "1st Gds Cav", template: sov_guards, side: "allied", force: "soviet", pq: 9, pr: 5, str: 8, morale: 70, arrives: 3},
    %{name: "Arty 50th", template: sov_arty, side: "allied", force: "soviet", pq: 7, pr: 5, str: 5}
  ])

  # =========================================================================
  # SCENARIO 10: Moscow Counterattack
  # =========================================================================
  IO.puts("\n  [10/10] Moscow Counterattack")

  counter_map = create_map.("Moscow Counter-Offensive", 18, 12, fn tiles ->
    tiles
    |> apply_terrain.([{4, 3}, {4, 4}, {5, 3}, {8, 7}, {8, 8}, {9, 8}, {13, 2}, {14, 2}, {14, 3}, {15, 8}, {15, 9}], :forest)
    |> apply_terrain.([{9, 5}, {9, 6}, {10, 5}, {3, 3}, {15, 4}], :town)
    |> apply_terrain.([{7, 0}, {7, 1}, {7, 10}, {7, 11}], :water)
    |> apply_elevation.([{6, 4}, {6, 5}, {11, 6}, {11, 7}, {12, 7}], 40)
    |> apply_vp.([{{9, 5}, 5}, {{9, 6}, 5}, {{3, 3}, 3}, {{15, 4}, 3}])
  end)

  counter_scenario = create_scenario.(%{
    name: "Moscow Counterattack",
    description: "December 5, 1941 - January 7, 1942. Fresh Siberian divisions launch the Soviet winter counter-offensive, pushing the exhausted Germans back from Moscow.",
    era: "ww2",
    date_start: "1941-12-05",
    date_per_turn: "1 day",
    max_turns: 10,
    first_move: "allied",
    map_id: counter_map.id,
    action_profile_id: action_profile.id,
    game_product_id: product.id,
    published: true,
    sides: %{"sides" => [
      %{"id" => "axis", "name" => "Germany", "forces" => ["german"]},
      %{"id" => "allied", "name" => "Soviet Union", "forces" => ["soviet"]}
    ]},
    victory_conditions: %{
      "type" => "victory_points",
      "vp_levels" => %{"decisive" => 14, "tactical" => 10, "marginal" => 6},
      "unit_kill_vp" => %{"armor" => 3, "infantry" => 1, "leader" => 5}
    },
    weather_schedule: %{"schedule" => [
      %{"turns" => "1-4", "weather" => "snow", "ground" => "frozen"},
      %{"turns" => "5-7", "weather" => "blizzard", "ground" => "frozen"},
      %{"turns" => "8-10", "weather" => "snow", "ground" => "frozen"}
    ]},
    supply_sources: %{"sources" => [
      %{"side" => "axis", "hex_q" => 0, "hex_r" => 6},
      %{"side" => "allied", "hex_q" => 17, "hex_r" => 6}
    ]}
  })

  create_units.(counter_scenario, [
    # German forces (weakened, in defensive positions)
    %{name: "4th Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 7, pr: 4, str: 6, morale: 45},
    %{name: "3rd Panzer Grp", template: ger_pz4, side: "axis", force: "german", pq: 7, pr: 7, str: 6, morale: 45},
    %{name: "IR 4th Army", template: ger_inf, side: "axis", force: "german", pq: 8, pr: 5, str: 8, morale: 50},
    %{name: "IR 9th Army", template: ger_inf, side: "axis", force: "german", pq: 8, pr: 6, str: 8, morale: 50},
    %{name: "SS Reich PzGr", template: ger_pzgren, side: "axis", force: "german", pq: 9, pr: 5, str: 8, morale: 60},
    %{name: "Art 4th Army", template: ger_arty, side: "axis", force: "german", pq: 6, pr: 5, str: 5},
    # Soviet forces (fresh, strong)
    %{name: "1st Shock Army", template: sov_guards, side: "allied", force: "soviet", pq: 14, pr: 3, str: 10, morale: 75},
    %{name: "20th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 14, pr: 5, str: 10, morale: 70},
    %{name: "10th Army", template: sov_rifle, side: "allied", force: "soviet", pq: 14, pr: 7, str: 10, morale: 70},
    %{name: "Siberian T-34", template: sov_t34_76, side: "allied", force: "soviet", pq: 15, pr: 5, str: 10, morale: 75},
    %{name: "Siberian KV-1", template: sov_kv1, side: "allied", force: "soviet", pq: 15, pr: 6, str: 8, morale: 70},
    %{name: "Gds Cavalry", template: sov_guards, side: "allied", force: "soviet", pq: 16, pr: 4, str: 10, morale: 75},
    %{name: "Ski Battalion", template: sov_recon, side: "allied", force: "soviet", pq: 16, pr: 7, str: 5, morale: 75},
    %{name: "Arty Reserve", template: sov_arty, side: "allied", force: "soviet", pq: 16, pr: 6, str: 5}
  ])

  IO.puts("\n--- East Front 1941 seeding complete: 10 scenarios ---\n")
end
