# Wargame Designer System - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a complete browser-based wargame design and play system, from database schemas through a playable game with AI opponent.

**Architecture:** Elixir umbrella app with 6 apps. Pure-functional game core (`wargame_core`), Ecto persistence (`wargame_persistence`), Phoenix LiveView + PixiJS frontend (`wargame_web`), AI opponent (`wargame_ai`). Game runtime uses GenServer per active game with PubSub for real-time updates.

**Tech Stack:** Elixir 1.18, Phoenix 1.8, LiveView 1.1, Ecto 3.12, Postgres 16 (pgvector), PixiJS (2D rendering), TypeScript, Tailwind CSS 4.

**Design Doc:** `documents/development/2026-02-15-wargame-system-design.md`

---

## Implementation Phases

The plan is organized into 8 phases. Each phase produces working, tested, committed code. Phases build on each other but each phase is independently valuable.

**Steel thread strategy:** Phase 4 produces a minimal playable game. Everything before it is foundation; everything after enhances it.

| Phase | Name | Depends On | Deliverable |
|-------|------|-----------|-------------|
| 1 | Database Foundation | nothing | Ecto schemas, migrations, context modules |
| 2 | Unit System Core | Phase 1 | Unit/leader modules in wargame_core, unit templates in DB |
| 3 | Scenario System Core | Phase 1, 2 | Scenario module, action profiles, weather, supply |
| 4 | Game Runtime (Steel Thread) | Phase 1, 2, 3 | Playable game loop: place units, move, fight, win/lose |
| 5 | Game Frontend | Phase 4 | Unit rendering, game UI, interactive play |
| 6 | Editor UIs | Phase 1, 2, 3 | Unit template editor, scenario editor, map persistence |
| 7 | AI System | Phase 4 | AI opponent with difficulty levels |
| 8 | Polish & Enhancement | Phase 5, 6, 7 | Fog of war, replays, campaign mode prep |

---

## Phase 1: Database Foundation

**Goal:** Create all Ecto schemas, migrations, and context modules so every other phase has persistence available.

### Task 1.1: Create migrations for all tables

**Files:**
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_users.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_maps.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_unit_templates.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_leaders.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_action_profiles.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_scenarios.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_scenario_units.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_games.exs`
- Create: `apps/wargame_persistence/priv/repo/migrations/TIMESTAMP_create_game_actions.exs`

**Step 1:** Generate migrations using `mix ecto.gen.migration` from the `wargame_platform` root. Create them in dependency order (users first, then maps, then unit_templates, etc.) since later tables reference earlier ones.

**Step 2:** Implement each migration per the schema design in the design doc (Section 7). Key details:
- All primary keys are `:binary_id` (UUID)
- `maps.tile_data` and `games.game_state` are `:binary` columns
- `unit_templates.stats`, `leaders.modifiers`, `scenarios.sides`, `scenarios.victory_conditions`, `scenarios.weather_schedule`, `scenarios.supply_sources`, `scenarios.special_rules`, `games.players`, `games.settings`, `games.result`, `game_actions.action`, `action_profiles.actions`, `action_profiles.phase_sequence`, `scenario_units.attachment_ids`, `scenario_units.reinforcement_config` are all `:map` (JSONB)
- Foreign keys: `scenarios.map_id -> maps.id`, `scenarios.action_profile_id -> action_profiles.id`, `scenario_units.scenario_id -> scenarios.id`, `scenario_units.unit_template_id -> unit_templates.id`, `scenario_units.leader_id -> leaders.id`, `games.scenario_id -> scenarios.id`, `game_actions.game_id -> games.id`
- Add indexes on foreign keys and commonly queried fields (`unit_templates.nationality`, `unit_templates.era`, `scenarios.era`, `games.status`)

**Step 3:** Run migrations against dev and test databases:
```bash
mix ecto.create
mix ecto.migrate
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
```

**Step 4:** Commit.

### Task 1.2: Create Ecto schemas

**Files:**
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/user.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/map.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/unit_template.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/leader.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/action_profile.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/scenario.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/scenario_unit.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/game.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/schemas/game_action.ex`

**Step 1:** Create each schema module with `use Ecto.Schema`, `@primary_key {:id, :binary_id, autogenerate: true}`, `@foreign_key_type :binary_id`. Define all fields matching the migrations. Add `belongs_to`/`has_many` associations.

**Step 2:** Add changesets to each schema. Every schema gets at minimum:
- `changeset/2` - standard create/update
- `create_changeset/2` - for inserts with required field validation
- Validate required fields, string lengths, inclusion of enum-like fields

**Step 3:** For `Map` schema specifically, add custom serialization functions:
- `serialize_tile_data/1` - takes a `%WargameCore.Map{}` struct, returns `:erlang.term_to_binary(tiles, [:compressed])`
- `deserialize_tile_data/1` - takes binary, returns tiles map via `:erlang.binary_to_term/1`

**Step 4:** Write tests for each schema's changeset validations.
- Test file pattern: `apps/wargame_persistence/test/wargame_persistence/schemas/<name>_test.exs`
- Test valid changesets, required field validation, enum validation

**Step 5:** Run tests, verify zero warnings, commit.

### Task 1.3: Create context modules

**Files:**
- Create: `apps/wargame_persistence/lib/wargame_persistence/maps.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/units.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/scenarios.ex`
- Create: `apps/wargame_persistence/lib/wargame_persistence/game_store.ex`

**Step 1:** Create `WargamePersistence.Maps` context:
- `list_maps/1` - list maps with optional filters (published, author)
- `get_map!/1` - get by ID, raises on not found
- `get_map/1` - get by ID, returns nil
- `create_map/1` - insert with changeset
- `update_map/2` - update with changeset
- `delete_map/1` - delete
- `save_game_map/2` - takes a `%WargameCore.Map{}` struct + metadata, serializes tile_data, saves to DB
- `load_game_map/1` - loads from DB, deserializes tile_data back to `%WargameCore.Map{}`

**Step 2:** Create `WargamePersistence.Units` context:
- CRUD for `UnitTemplate` (list with filters by nationality/era/category, get, create, update, delete)
- CRUD for `Leader` (list with filters, get, create, update, delete)
- `list_unit_templates_for_scenario/1` - list templates used by a scenario

**Step 3:** Create `WargamePersistence.Scenarios` context:
- CRUD for `ActionProfile`
- CRUD for `Scenario` (preloads map, action_profile, scenario_units)
- CRUD for `ScenarioUnit` (batch create for initial deployment)
- `load_full_scenario/1` - loads scenario with all associations preloaded, converts to core structs

**Step 4:** Create `WargamePersistence.GameStore` context:
- `create_game/1` - create game record from scenario
- `save_game_state/2` - serialize and save current state (called each turn end)
- `load_game_state/1` - deserialize and restore state
- `log_action/2` - insert a `GameAction` row
- `get_action_log/1` - get all actions for a game (for replay)
- `list_games/1` - list with filters (status, player)
- `finish_game/2` - set result and finished_at

**Step 5:** Write tests for each context module. Use `DataCase` for database tests.
- Test file pattern: `apps/wargame_persistence/test/wargame_persistence/<context>_test.exs`
- Focus on: CRUD operations work, serialization/deserialization round-trips correctly, filters work

**Step 6:** Run full test suite, verify zero warnings, commit.

### Task 1.4: Seed data - WW2 action profile

**Files:**
- Create: `apps/wargame_persistence/priv/repo/seeds.exs`

**Step 1:** Create a seed script that inserts the default WW2 action profile:
- Name: "WW2 Standard"
- Era: "ww2"
- Actions: move_and_fire, fire_only, move_only, hold, assault
- Phase sequence: command, movement, combat, exploitation, supply, end_phase
- Rules module: "Elixir.WargameCore.Rules.StandardRules"

**Step 2:** Run `mix run apps/wargame_persistence/priv/repo/seeds.exs` and verify data exists.

**Step 3:** Commit.

---

## Phase 2: Unit System Core

**Goal:** Build the unit and leader domain modules in `wargame_core` and populate the DB with Eastern Front OOB.

### Task 2.1: Unit template module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/units/unit_template.ex`
- Create: `apps/wargame_core/test/wargame_core/units/unit_template_test.exs`

**Step 1:** Write tests for `WargameCore.Units.UnitTemplate`:
- `new/1` creates a template from a keyword list/map of attributes
- `movement_cost_modifier/2` returns how road/terrain affects this unit's movement type
- `combat_effectiveness/2` returns attack value scaled by current strength ratio
- `valid_categories/0` returns the list of valid category atoms
- `valid_movement_types/0` returns valid movement type atoms
- `valid_unit_sizes/0` returns valid size atoms

**Step 2:** Implement the module. This is a pure struct (no Ecto, no GenServer):
```elixir
defstruct [:id, :name, :nationality, :era, :category, :unit_size, :icon_type,
           :attack_soft, :attack_hard, :defense, :armor,
           :movement_points, :movement_type, :range, :spotting, :initiative,
           :max_strength, :max_ammo, :max_fuel,
           :can_bridge, :can_entrench, :is_organic_transport]
```

**Step 3:** Run tests, commit.

### Task 2.2: Unit instance module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/units/unit_instance.ex`
- Create: `apps/wargame_core/test/wargame_core/units/unit_instance_test.exs`

**Step 1:** Write tests:
- `new/2` creates an instance from a template + deployment options
- `effective_attack_soft/1` and `effective_attack_hard/1` scale by strength ratio and experience
- `effective_defense/1` scales by strength ratio + entrenchment
- `apply_damage/2` reduces strength, may cause disruption/rout based on morale
- `resupply/1` restores ammo/fuel if in supply
- `rally/1` attempts to recover from disruption/rout (morale check)
- `entrench/1` increases entrenchment level (max 3)
- `reset_turn_state/1` resets movement_remaining, has_attacked, has_moved
- `spend_movement/2` reduces movement_remaining
- `can_move?/1`, `can_attack?/1` check turn state flags
- Attachment functions: `attach/2`, `detach/2`, `attachment_bonus/2`

**Step 2:** Implement. Pure struct:
```elixir
defstruct [:id, :unit_template_id, :template, :name, :side, :force,
           :position, :current_strength, :current_ammo, :current_fuel,
           :experience, :morale, :entrenchment,
           :movement_remaining, :has_attacked, :has_moved,
           :is_disrupted, :is_routed,
           :attachments, :arrives_turn, :deploy_hex]
```
Key: the `:template` field holds the resolved `UnitTemplate` struct for fast access to stats.

**Step 3:** Run tests, commit.

### Task 2.3: Leader module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/units/leader.ex`
- Create: `apps/wargame_core/test/wargame_core/units/leader_test.exs`

**Step 1:** Write tests:
- `new/1` creates a leader from attributes
- `in_command_radius?/2` checks if a coord is within the leader's radius
- `apply_modifiers/2` returns a map of stat bonuses for a unit
- `has_ability?/2` checks for a specific ability
- `generate_replacement/1` creates a generic leader of same rank with weaker stats
- `death_check/1` rolls for leader casualty (returns `:survives` or `:killed`)
- `rank_to_default_radius/1` maps rank atom to default radius integer

**Step 2:** Implement. Pure struct:
```elixir
defstruct [:id, :name, :nationality, :era, :is_historical, :rank,
           :command_radius, :attack_modifier, :defense_modifier,
           :morale_modifier, :initiative_modifier, :abilities,
           :position, :side, :force]
```

**Step 3:** Run tests, commit.

### Task 2.4: Seed Eastern Front unit templates

**Files:**
- Create: `apps/wargame_persistence/priv/repo/seeds/ww2_eastern_front_units.exs`
- Modify: `apps/wargame_persistence/priv/repo/seeds.exs` (call the unit seeds)

**Step 1:** Create unit template seed data for core Eastern Front units. At minimum:

**German:**
- Infantry platoon, Panzergrenadier platoon, Panzer IV, Panzer V Panther, Tiger I, StuG III, 88mm AT gun, 105mm howitzer, recon halftrack, pioneer (engineer) platoon

**Soviet:**
- Rifle platoon, Guards rifle platoon, T-34/76, T-34/85, KV-1, IS-2, SU-76, SU-152, 76mm AT gun, 122mm howitzer, recon company, engineer platoon

**Step 2:** Create leader seed data:
- Historical: Guderian, Manstein, Model, Zhukov, Konev, Rokossovsky, Vatutin (with appropriate stats)
- Generic templates per rank for replacements

**Step 3:** Run seeds, verify data in DB, commit.

### Task 2.5: Update StandardRules to use new unit system

**Files:**
- Modify: `apps/wargame_core/lib/wargame_core/rules/standard_rules.ex`
- Modify: `apps/wargame_core/test/wargame_core/rules/standard_rules_test.exs` (create if needed)

**Step 1:** Update `StandardRules` private helpers to work with `UnitInstance` structs:
- `get_attack_strength/1` → use `UnitInstance.effective_attack_soft/1` or `effective_attack_hard/1` based on defender's armor
- `get_defense_strength/1` → use `UnitInstance.effective_defense/1`
- Add leader modifier integration in combat odds calculation
- Add combined arms bonus when attack includes both infantry and armor categories

**Step 2:** Write/update tests for combat resolution with the new unit stat model. Test:
- Pure infantry vs infantry combat
- Combined arms attack (infantry + armor vs infantry)
- Leader modifier applied to attack
- Terrain defense bonus
- Strength-scaled effectiveness (half-strength unit is weaker)

**Step 3:** Run full test suite, verify zero warnings, commit.

---

## Phase 3: Scenario System Core

**Goal:** Build scenario, weather, supply, and action profile modules.

### Task 3.1: Action profile module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/scenario/action_profile.ex`
- Create: `apps/wargame_core/test/wargame_core/scenario/action_profile_test.exs`

**Step 1:** Write tests:
- `available_actions/2` returns valid actions for a unit in current phase
- `action_allows_movement?/1`, `action_allows_fire?/1`, `action_allows_melee?/1`
- `movement_penalty_for/1` returns movement modifier for a given action choice
- Default WW2 profile works correctly

**Step 2:** Implement. Pure struct:
```elixir
defstruct [:id, :name, :era, :action_options, :phase_sequence, :rules_module]
```
`action_options` is a list of `%ActionOption{}` structs. `phase_sequence` reuses existing `Phase` structs.

**Step 3:** Run tests, commit.

### Task 3.2: Weather module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/scenario/weather.ex`
- Create: `apps/wargame_core/test/wargame_core/scenario/weather_test.exs`

**Step 1:** Write tests:
- `current_weather/2` returns weather for a given turn from the schedule
- `movement_modifier/2` returns modifier for movement type in current weather/ground
- `combat_modifier/1` returns attacker combat penalty for current weather
- `air_support_level/1` returns air support availability
- All weather/ground combinations from the design doc table

**Step 2:** Implement. Pure module with functions operating on weather schedule data:
```elixir
@type weather :: :clear | :rain | :overcast | :snow | :blizzard | :rasputitsa
@type ground :: :dry | :mud | :frozen | :deep_mud
@type weather_state :: %{weather: weather(), ground: ground()}
```

**Step 3:** Run tests, commit.

### Task 3.3: Supply module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/scenario/supply.ex`
- Create: `apps/wargame_core/test/wargame_core/scenario/supply_test.exs`

**Step 1:** Write tests:
- `calculate_supply_status/3` (map, units, supply_sources) returns `%{unit_id => :supplied | :unsupplied}`
- Supply path must not cross enemy ZOC
- Supply path must not cross impassable terrain
- Units adjacent to supply source are always supplied
- Units with no valid path to any supply source are unsupplied
- `apply_attrition/1` reduces strength/morale for unsupplied units

**Step 2:** Implement supply tracing as BFS from supply sources, blocked by enemy ZOC and impassable terrain. Uses existing `Coord.neighbors/1` and `Tile.movement_cost/3`.

**Step 3:** Run tests, commit.

### Task 3.4: Reinforcement module

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/scenario/reinforcements.ex`
- Create: `apps/wargame_core/test/wargame_core/scenario/reinforcements_test.exs`

**Step 1:** Write tests:
- `deploy_reinforcements/3` (turn, scenario_units, mode) returns list of units to place
- `:fixed` mode: returns units where `arrives_turn == current_turn`
- `:variable` mode: rolls probability, respects earliest/latest/no_show_chance
- `:conditional` mode: checks condition function
- Units are placed at their `deploy_hex` or assigned to a map edge zone

**Step 2:** Implement.

**Step 3:** Run tests, commit.

### Task 3.5: Scenario struct and loader

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/scenario/scenario.ex`
- Create: `apps/wargame_core/test/wargame_core/scenario/scenario_test.exs`

**Step 1:** Write tests:
- `new/1` creates a scenario struct from attributes
- `initial_game_state/1` converts a scenario into a complete initial game state map
- `get_side/2` returns side config by id
- `forces_for_side/2` returns list of forces for a side

**Step 2:** Implement. The `initial_game_state/1` function is critical - it:
1. Loads the map
2. Instantiates all `scenario_units` where `arrives_turn == 1` into `UnitInstance` structs
3. Places leaders
4. Creates the `TurnState` from the action profile's phase sequence
5. Sets initial weather from schedule
6. Calculates initial supply
7. Returns the complete game state map that `GameServer` will manage

**Step 3:** Run tests, commit.

---

## Phase 4: Game Runtime (Steel Thread)

**Goal:** A working game loop. Two players (or player + AI stub) can start a scenario, take turns moving and fighting, and reach a victory condition. No fancy UI yet - this is the backend engine.

### Task 4.1: GameServer GenServer

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/game/game_server.ex`
- Create: `apps/wargame_core/lib/wargame_core/game/game_supervisor.ex`
- Create: `apps/wargame_core/test/wargame_core/game/game_server_test.exs`

**Step 1:** Write tests:
- `start_link/1` starts a game from a scenario
- `get_state/1` returns the current game state
- `perform_action/3` (game_pid, side, action) validates and executes an action
- `end_phase/2` advances to the next phase
- `end_turn/1` triggers turn-end lifecycle
- Turn lifecycle: weather advances, reinforcements deploy, supply recalculates
- Invalid actions are rejected with `{:error, reason}`
- Only the active side can act

**Step 2:** Implement `GameServer` as a `GenServer`:
- `init/1` calls `Scenario.initial_game_state/1` to set up state
- `handle_call({:action, side, action}, ...)` runs the validation/execution pipeline
- `handle_call(:end_phase, ...)` calls `TurnState.advance_phase/1`
- Turn-end triggers: weather, supply, reinforcements, victory check
- Broadcasts via `Phoenix.PubSub` after each state change (topic: `"game:#{game_id}"`)

**Step 3:** Implement `GameSupervisor` as a `DynamicSupervisor` for managing game processes.

**Step 4:** Run tests, commit.

### Task 4.2: Movement action handler

**Files:**
- Modify: `apps/wargame_core/lib/wargame_core/game/game_server.ex`
- Create: `apps/wargame_core/lib/wargame_core/game/actions/move.ex`
- Create: `apps/wargame_core/test/wargame_core/game/actions/move_test.exs`

**Step 1:** Write tests:
- Valid move: unit moves to adjacent hex, movement points deducted
- Invalid: not movement phase
- Invalid: not your turn
- Invalid: unit has no movement remaining
- Invalid: destination is impassable
- Invalid: destination exceeds stacking limit
- Road movement bonus: units on roads spend fewer movement points
- Leader command check: log whether unit is in/out of command radius

**Step 2:** Implement `WargameCore.Game.Actions.Move`:
- `validate/2` and `execute/2` functions
- Uses existing `StandardRules.validate_movement/3` and `StandardRules.execute_movement/3`
- Returns `{:ok, new_state}` or `{:error, reason}`

**Step 3:** Run tests, commit.

### Task 4.3: Combat action handler

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/game/actions/combat.ex`
- Create: `apps/wargame_core/test/wargame_core/game/actions/combat_test.exs`

**Step 1:** Write tests:
- Valid attack: attackers adjacent to target, combat phase, odds calculated, CRT rolled, result applied
- Combined arms bonus: attack with infantry + armor gets bonus
- Leader modifier applied to attacking units in command radius
- Terrain defense modifier applied
- Strength-scaled attack values
- Combat results: attacker eliminated, attacker retreat, exchange, defender retreat, defender eliminated
- Retreat mechanics: units pushed back 1 hex away from attacker
- Disruption: units that take heavy losses may become disrupted

**Step 2:** Implement `WargameCore.Game.Actions.Combat`:
- `declare_attack/2` - registers an attack (attacker_ids + target_coord)
- `resolve_attacks/1` - resolves all declared attacks for the phase
- Extends existing `StandardRules.resolve_attack/3` with:
  - Leader modifier lookup (find leader in command radius of attackers/defenders)
  - Combined arms detection
  - Soft/hard attack selection based on primary defender type
  - Damage application via `UnitInstance.apply_damage/2`
  - Retreat pathfinding (push away from attacker)
  - Disruption/rout checks

**Step 3:** Run tests, commit.

### Task 4.4: End-phase and end-turn handlers

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/game/actions/phase_management.ex`
- Create: `apps/wargame_core/test/wargame_core/game/actions/phase_management_test.exs`

**Step 1:** Write tests:
- End movement phase → advances to combat phase
- End combat phase → advances to exploitation (if applicable) or supply/end
- End of all phases for side → switches to next side (IGOUGO)
- End of all sides → advances turn counter
- Turn start lifecycle fires (reset units, deploy reinforcements, weather)
- Turn end lifecycle fires (entrenchment, morale recovery, victory check)
- Victory condition: side reaches VP threshold → game ends
- Victory condition: max turns reached → compare VPs → winner declared

**Step 2:** Implement. Wires together existing `TurnState.advance_phase/1` with:
- Weather advancement (`Weather.current_weather/2`)
- Supply recalculation (`Supply.calculate_supply_status/3`)
- Reinforcement deployment (`Reinforcements.deploy_reinforcements/3`)
- Victory checking (`StandardRules.check_victory/1`)

**Step 3:** Run tests, commit.

### Task 4.5: Integration test - full game loop

**Files:**
- Create: `apps/wargame_core/test/wargame_core/game/integration_test.exs`

**Step 1:** Write an integration test that plays a complete mini-game:
1. Create a small 5x5 map with mixed terrain
2. Place 3 German units and 3 Soviet units
3. Place 1 leader per side
4. Set up a 3-turn scenario with VP hexes
5. Play through: movement phase (move units), combat phase (attack), end turn
6. Play through Soviet turn similarly
7. Continue until victory condition or turn limit
8. Assert game ends with a result

This test validates the entire pipeline works end-to-end.

**Step 2:** Run it, fix any integration issues.

**Step 3:** Commit.

### Task 4.6: Game persistence integration

**Files:**
- Modify: `apps/wargame_core/lib/wargame_core/game/game_server.ex`
- Create: `apps/wargame_core/test/wargame_core/game/game_persistence_test.exs`

**Step 1:** Write tests:
- Starting a game creates a `Game` record in DB
- Each action logs a `GameAction` row
- Turn end saves a state snapshot
- Game can be loaded from a snapshot and resumed
- Finished game has result persisted

**Step 2:** Add persistence calls to `GameServer`:
- On init: `GameStore.create_game/1`
- On action: `GameStore.log_action/2`
- On turn end: `GameStore.save_game_state/2`
- On game over: `GameStore.finish_game/2`

**Step 3:** Run tests (these need the database - use `DataCase`), commit.

---

## Phase 5: Game Frontend

**Goal:** Render units on the map, build the game UI, let players interact with the game through the browser.

### Task 5.1: Unit counter rendering in PixiJS

**Files:**
- Create: `apps/wargame_web/assets/ts/engine/UnitRenderer.ts`
- Create: `apps/wargame_web/assets/ts/engine/NATOSymbols.ts`
- Modify: `apps/wargame_web/assets/ts/engine/Pixi2DRenderer.ts` (add unit layer)

**Step 1:** Create `NATOSymbols.ts`:
- Define NATO APP-6 symbol drawing functions using PixiJS Graphics
- Symbols needed: infantry (X), armor (oval), artillery (dot), recon (diagonal), engineer (E), anti-tank, anti-air, leader (star), cavalry
- Each symbol is a function that draws to a `Graphics` object at a given size

**Step 2:** Create `UnitRenderer.ts`:
- `UnitCounter` class extending `Container`
- Constructor takes: `{side, category, name, attackSoft, attackHard, defense, strength, maxStrength, experience, movement, maxMovement, isDisrupted, isRouted, isEntrenched, isUnsupplied, isSelected}`
- Renders: border (side color), NATO symbol, name text, stat numbers, strength bar, status icons
- `update(data)` method to update all fields without recreating
- Side colors: blue for axis, red for soviet (configurable)

**Step 3:** Add unit layer to `Pixi2DRenderer`:
- `renderUnits(units: UnitData[])` method
- `updateUnit(unit: UnitData)` method
- `clearUnits()` method
- Units render on top of hex terrain
- Handle stacking: offset stacked units vertically, click to expand

**Step 4:** Write vitest tests for `UnitRenderer` (construction, update).

**Step 5:** Commit.

### Task 5.2: Movement preview and reachable hexes

**Files:**
- Modify: `apps/wargame_web/assets/ts/engine/Pixi2DRenderer.ts`
- Create: `apps/wargame_web/assets/ts/engine/MovementOverlay.ts`

**Step 1:** Create `MovementOverlay.ts`:
- `showReachableHexes(hexes: {q: number, r: number, cost: number}[])` - highlights hexes the selected unit can reach, with color gradient by remaining movement
- `showMovementPath(path: {q: number, r: number}[])` - draws dotted line along proposed path
- `clear()` - removes all overlays

**Step 2:** Integrate with renderer:
- When a unit is selected and it's the movement phase, the backend calculates reachable hexes and sends them to the frontend
- Hovering over a reachable hex shows the path preview
- Clicking confirms the move

**Step 3:** Commit.

### Task 5.3: GameLive LiveView

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/game_live.ex`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex` (add route)

**Step 1:** Create `GameLive` with:
- `mount/3`: loads game from DB or starts new from scenario, subscribes to PubSub topic
- Assigns: `game_id`, `game_pid` (GameServer), `side` (which side this player controls), `game_state` (fog-filtered), `selected_unit`, `phase_info`
- `handle_info({:game_update, state}, socket)` - receives broadcasts from GameServer, updates assigns

**Step 2:** Implement the render template with the game layout:
- Top status bar: turn counter, current phase, active side, weather
- Left panel: unit list for the player's side (clickable to select)
- Center: canvas element with `phx-hook="GameHook"`
- Right panel: selected unit detail (all stats, leader info, attachments)
- Bottom action bar: phase-appropriate action buttons, "End Phase" button

**Step 3:** Handle events:
- `"hex_selected"` from canvas hook → select unit at hex or set move target
- `"end_phase"` → call `GameServer.end_phase/2`
- `"action_selected"` → set the current action mode (move, fire, hold, etc.)
- `"move_unit"` → call `GameServer.perform_action/3` with move action
- `"declare_attack"` → call `GameServer.perform_action/3` with attack action

**Step 4:** Add route: `live "/game/:id", GameLive`

**Step 5:** Commit.

### Task 5.4: GameHook (LiveView ↔ PixiJS bridge)

**Files:**
- Create: `apps/wargame_web/assets/ts/hooks/GameHook.ts`
- Modify: `apps/wargame_web/assets/ts/hooks/index.ts` (register hook)

**Step 1:** Create `GameHook` extending the pattern from `MapEditorHook`:
- `mounted()`: initialize `Pixi2DRenderer` with game mode config
- Handle events from LiveView:
  - `"render_game"` - full render: map tiles + units
  - `"update_units"` - update unit positions/stats
  - `"show_reachable"` - highlight reachable hexes for selected unit
  - `"show_combat_preview"` - show attack odds overlay
  - `"animate_move"` - animate unit movement along path
  - `"animate_combat"` - show combat result animation
  - `"clear_selection"` - clear highlights
- Push events to LiveView:
  - `"hex_selected"` with `{q, r, shift}`
  - `"hex_hovered"` with `{q, r}`

**Step 2:** Register in hooks index.

**Step 3:** Commit.

### Task 5.5: Game setup / lobby page

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/game_setup_live.ex`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex`

**Step 1:** Create `GameSetupLive`:
- Select a scenario from list
- Choose side (or random)
- Configure settings: fog of war, AI difficulty, AI personality
- "Start Game" button creates a `Game` record, starts `GameServer`, redirects to `GameLive`

**Step 2:** Add route: `live "/games/new", GameSetupLive`
- Also add `live "/games", GameListLive` for listing active/completed games (can be a simple list initially)

**Step 3:** Commit.

---

## Phase 6: Editor UIs

**Goal:** Let users create and manage units, leaders, and scenarios through the browser.

### Task 6.1: Map persistence in existing editor

**Files:**
- Modify: `apps/wargame_web/lib/wargame_web_web/live/map_editor_live.ex`

**Step 1:** Replace the current YAML file save/load with database persistence:
- "Save" button calls `WargamePersistence.Maps.save_game_map/2`
- "Load" shows a modal with `WargamePersistence.Maps.list_maps/1` results
- Selecting a map calls `WargamePersistence.Maps.load_game_map/1`
- "New" creates a fresh map (existing behavior) but also gives it a DB record on first save
- Keep YAML export as a secondary option ("Export to YAML")

**Step 2:** Add map metadata form: name (already exists), description, scale, author info.

**Step 3:** Test manually via browser, commit.

### Task 6.2: Unit template editor

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/unit_editor_live.ex`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex`

**Step 1:** Create `UnitEditorLive`:
- Left panel: searchable/filterable list of unit templates (filter by nationality, era, category)
- Right panel: detail form for selected template (all fields from UnitTemplate)
- CRUD operations via `WargamePersistence.Units` context
- "New Template" button, "Clone" button (copy existing as starting point)
- "Delete" with confirmation
- Form validation matching schema constraints

**Step 2:** Add a live preview of the unit counter (small PixiJS canvas showing how the unit will look on the map) - reuse `UnitRenderer` from Task 5.1.

**Step 3:** Add route: `live "/unit-editor", UnitEditorLive`

**Step 4:** Commit.

### Task 6.3: Leader editor

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/leader_editor_live.ex`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex`

**Step 1:** Create `LeaderEditorLive`:
- Similar structure to unit editor
- List with filters (nationality, era, rank, historical/generic)
- Detail form: name, nationality, era, rank, historical flag, command radius, all modifiers, abilities (multi-select)
- Replacement leader assignment (dropdown of generic leaders at same rank)
- CRUD via `WargamePersistence.Units` context (leaders section)

**Step 2:** Add route: `live "/leader-editor", LeaderEditorLive`

**Step 3:** Commit.

### Task 6.4: Scenario editor

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/scenario_editor_live.ex`
- Create: `apps/wargame_web/assets/ts/hooks/ScenarioEditorHook.ts`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex`

**Step 1:** Create `ScenarioEditorLive` with tabbed interface:

**Tab 1 - General:**
- Name, description, era, date_start, date_per_turn, max_turns
- Select map from library (dropdown with preview)
- Select action profile (dropdown)
- Configure sides (names, forces)
- First move selection

**Tab 2 - Deployment:**
- Map canvas showing the selected map
- Unit palette on the side (filtered unit templates for the scenario's era)
- Drag units from palette onto map hexes (or click to place)
- Set per-unit overrides: name, strength, experience, morale
- Assign leaders to hexes
- Color-coded by side

**Tab 3 - Reinforcements:**
- Timeline view showing turns
- Drag units to specific turns
- Configure reinforcement_mode per scenario
- For variable mode: set probability, earliest, latest, no_show_chance per unit
- Set deploy zone (hex or map edge)

**Tab 4 - Victory & Weather:**
- Victory condition type selector
- VP level configuration
- Unit kill VP values
- Weather schedule builder (turn ranges → weather/ground pairs)
- Supply source placement (on map)

**Step 2:** Create `ScenarioEditorHook.ts` extending the map renderer for deployment mode:
- Renders map tiles (read-only, from selected map)
- Renders placed units on hexes
- Click hex to place/remove unit
- Different visual mode from game (editor overlay showing VP hexes, supply sources)

**Step 3:** Add route: `live "/scenario-editor", ScenarioEditorLive`
- Also: `live "/scenario-editor/:id", ScenarioEditorLive` for editing existing

**Step 4:** Commit.

### Task 6.5: Navigation and home page

**Files:**
- Modify: `apps/wargame_web/lib/wargame_web_web/controllers/page_html/home.html.heex`
- Modify: `apps/wargame_web/lib/wargame_web_web/components/layouts/root.html.heex`

**Step 1:** Add a navigation bar to the root layout with links to:
- Home, Map Editor, Unit Editor, Leader Editor, Scenario Editor, Play Game

**Step 2:** Update home page to be a dashboard showing:
- Recent scenarios
- Active games
- Quick links to editors

**Step 3:** Commit.

---

## Phase 7: AI System

**Goal:** AI opponent that can play a full game at variable difficulty.

### Task 7.1: AI decision framework

**Files:**
- Create: `apps/wargame_ai/lib/wargame_ai/player.ex`
- Create: `apps/wargame_ai/lib/wargame_ai/evaluator.ex`
- Create: `apps/wargame_ai/test/wargame_ai/evaluator_test.exs`

**Step 1:** Create `WargameAI.Evaluator` - scores board positions:
- `evaluate_position/2` (game_state, side) → numeric score
- Factors: VP control, unit strength totals, supply status, territorial control, leader survival
- Weights configurable per personality

**Step 2:** Create `WargameAI.Player`:
- `play_turn/2` (game_state, ai_config) → list of actions
- Delegates to phase-specific handlers
- Applies difficulty-based degradation (random suboptimal choices at lower difficulties)

**Step 3:** Write evaluator tests with known board states.

**Step 4:** Commit.

### Task 7.2: AI movement logic

**Files:**
- Create: `apps/wargame_ai/lib/wargame_ai/tactics/movement.ex`
- Create: `apps/wargame_ai/test/wargame_ai/tactics/movement_test.exs`

**Step 1:** Implement movement decision making:
- For each unit, score all reachable hexes
- Scoring factors: proximity to nearest objective, defensive terrain value, friendly support density, leader command radius, supply line safety, threat avoidance
- Personality modifiers: aggressive weights offense, defensive weights terrain
- Difficulty degradation: lower difficulties randomly skip some optimization

**Step 2:** Write tests with specific board setups:
- AI moves toward uncontrolled VP hex
- AI retreats damaged unit to safer position
- AI keeps units within leader command radius

**Step 3:** Commit.

### Task 7.3: AI combat logic

**Files:**
- Create: `apps/wargame_ai/lib/wargame_ai/tactics/combat.ex`
- Create: `apps/wargame_ai/test/wargame_ai/tactics/combat_test.exs`

**Step 1:** Implement attack decision making:
- Enumerate all possible attack combinations (which units attack which targets)
- Calculate expected value for each: odds * result value
- Greedy allocation: best attack first, then re-evaluate
- Personality: aggressive accepts worse odds, defensive requires 2:1+
- Difficulty: lower difficulties miss some attack combinations

**Step 2:** Write tests:
- AI attacks when odds are favorable
- AI skips attacks when odds are terrible
- AI prioritizes VP hex attacks over random attacks

**Step 3:** Commit.

### Task 7.4: AI integration with GameServer

**Files:**
- Modify: `apps/wargame_core/lib/wargame_core/game/game_server.ex`
- Create: `apps/wargame_core/test/wargame_core/game/ai_integration_test.exs`

**Step 1:** Add AI turn handling to `GameServer`:
- When `TurnState.advance_phase/1` results in AI side becoming active:
  - Spawn a `Task` running `WargameAI.Player.play_turn/2`
  - Task returns list of actions
  - GameServer executes each action sequentially with a small delay (configurable, for "thinking" feel)
  - After all actions, auto-end phase
  - Continue through all phases for AI's turn

**Step 2:** Write integration test:
- Start a game with one human side, one AI side
- Human takes a turn (move + attack + end)
- AI automatically plays its turn
- Verify AI made valid moves (no errors)
- Verify game state advanced to next turn

**Step 3:** Commit.

---

## Phase 8: Polish & Enhancement

**Goal:** Complete the feature set with fog of war, game replay, and quality-of-life improvements.

### Task 8.1: Fog of war implementation

**Files:**
- Create: `apps/wargame_core/lib/wargame_core/game/fog_of_war.ex`
- Create: `apps/wargame_core/test/wargame_core/game/fog_of_war_test.exs`
- Modify: `apps/wargame_core/lib/wargame_core/game/game_server.ex`

**Step 1:** Implement `FogOfWar` module:
- `calculate_visibility/3` (units, map, weather) → `MapSet` of visible coords
- Per-unit spotting range with modifiers (elevation, weather, terrain, leader bonus)
- `filter_state_for_side/2` - strips enemy unit positions that aren't in visible hexes

**Step 2:** Integrate with `GameServer`:
- On each state broadcast, filter by side's visibility if fog_of_war setting is `:full` or `:partial`
- `:partial` mode: terrain always visible, units hidden
- `:none` mode: no filtering

**Step 3:** Update frontend to render fog (darken non-visible hexes).

**Step 4:** Tests + commit.

### Task 8.2: Game replay viewer

**Files:**
- Create: `apps/wargame_web/lib/wargame_web_web/live/replay_live.ex`
- Modify: `apps/wargame_web/lib/wargame_web_web/router.ex`

**Step 1:** Create `ReplayLive`:
- Loads a completed game's action log
- Reconstructs state by replaying actions from initial scenario state
- Playback controls: play, pause, step forward, step back, speed control
- Shows both sides (no fog of war in replay)

**Step 2:** Add route: `live "/games/:id/replay", ReplayLive`

**Step 3:** Commit.

### Task 8.3: First playable scenario - Kursk vignette

**Files:**
- Create: `apps/wargame_persistence/priv/repo/seeds/kursk_scenario.exs`

**Step 1:** Create a small but complete scenario:
- 15x12 map with mixed terrain (open steppe, some villages, a river)
- 5-6 units per side (mix of infantry, armor, artillery)
- 1 leader per side
- VP hexes on key positions
- 8-turn limit
- Weather: clear first 4 turns, overcast last 4
- Supply sources on map edges

This is the "demo scenario" that proves the entire system works.

**Step 2:** Run the seed, playtest in browser, fix issues.

**Step 3:** Commit.

---

## Testing Strategy

**Unit tests:** Every module in `wargame_core` is pure-functional and tested without database or GenServer. These are fast and cover game logic.

**Integration tests:** `GameServer` tests use the full pipeline. DB tests use `DataCase` with sandbox.

**Frontend tests:** Vitest for TypeScript modules (coord math, renderer construction). Manual browser testing for LiveView integration.

**Run commands:**
```bash
# All tests
MIX_ENV=test mix test

# Core only (fast, no DB)
MIX_ENV=test mix test --only apps/wargame_core

# Persistence only (needs DB)
MIX_ENV=test mix test --only apps/wargame_persistence

# Frontend
cd apps/wargame_web/assets && npx vitest run
```

## Commit Strategy

- Commit after every task (not every step)
- Commit message format: `feat: <description>` for new features, `test: <description>` for test-only commits
- Each phase should be a logical chunk that could be a PR
- Never commit with warnings (per CLAUDE.md instructions)
