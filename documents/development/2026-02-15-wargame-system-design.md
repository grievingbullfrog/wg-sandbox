# Wargame Designer System - Full Architecture Design

**Date:** 2026-02-15
**Status:** Approved
**Scope:** Complete system design for a browser-based, turn-based military strategy game development platform

## 1. Vision

A browser-based wargame design and play system inspired by Talonsoft's Campaign Series (Eastern Front, West Front), Panzer General, and Unity of Command. The system supports designing hex-based maps, defining unit databases, creating scenarios, and playing turn-based wargames against AI or other players.

Initial focus: **Eastern Front 1941-1945** campaigns, with the architecture supporting any era (Civil War, Napoleonic, modern) through pluggable rules and action profiles.

## 2. System Architecture Overview

Seven major subsystems built on the existing Elixir umbrella structure:

| Subsystem | Umbrella App | Status | Purpose |
|-----------|-------------|--------|---------|
| **Map System** | `wargame_core` + `wargame_web` | ~70% done | Hex grid, terrain, map editor |
| **Unit System** | `wargame_core` (new modules) | Not started | Unit types, OOB, stats, attachments, leaders |
| **Scenario System** | `wargame_core` (new modules) | Not started | Scenarios, setup, victory conditions, reinforcements |
| **Game Runtime** | `wargame_core` + new GenServer | Rules exist, no runtime | Turn execution, state machine, action resolution |
| **AI System** | `wargame_ai` | Stub only | Variable-difficulty opponent |
| **Persistence** | `wargame_persistence` | Repo only | DB schemas for maps, units, scenarios, games |
| **Frontend** | `wargame_web` | Map editor done | Unit rendering, game UI, scenario editor |

### Key Architectural Decisions

1. **Data-driven unit definitions** - Units defined as data (in DB/JSON), not code. An OOB editor creates unit templates; scenarios instantiate them.
2. **Scenario-as-configuration** - A scenario bundles: map, OOB per side, reinforcement schedule, victory conditions, special rules, weather schedule, turn limit.
3. **Game state as immutable snapshots** - Core modules are pure-functional structs. The runtime wraps them in a GenServer for state management and PubSub broadcasting.
4. **Era-pluggable rules** - The `RulesEngine` behaviour (already implemented) allows different eras to have different combat resolution, action models, and phase structures.
5. **Eastern Front 1941-45 as the "steel thread"** - Build one playable scenario first (e.g., small Kursk engagement) to validate the entire stack.

## 3. Unit System

### Unit Template

The definition of what a unit type *is* - stored in the database as reusable templates:

```
UnitTemplate:
  id:                  UUID
  name:                string ("Panzer IV Ausf. H")
  nationality:         string ("german")
  era:                 string ("ww2")
  category:            infantry | armor | motorized | artillery | recon | engineer |
                       anti_tank | anti_air | cavalry | naval | air
  unit_size:           squad | platoon | company | battalion | regiment |
                       brigade | division | corps
  icon_type:           NATO APP-6 symbol identifier (for 2D rendering)

  # Combat stats
  attack_soft:         0-99 (effectiveness vs infantry/soft targets)
  attack_hard:         0-99 (effectiveness vs armor/hard targets)
  defense:             0-99
  armor:               0-99 (damage resistance, 0 for infantry)

  # Movement
  movement_points:     integer
  movement_type:       foot | wheeled | tracked | horse | rail_only | air

  # Range & special
  range:               0-10 hexes (0 = melee/adjacent only)
  spotting:            1-10 hexes
  initiative:          0-10 (action order within phase)

  # Capacity
  max_strength:        1-15 (strength steps, Panzer General style)
  max_ammo:            integer (shots before resupply needed)
  max_fuel:            integer (movement actions before resupply)

  # Flags
  can_bridge:          boolean
  can_entrench:        boolean
  is_organic_transport: boolean
```

### Unit Instance

A specific unit placed in a scenario/game:

```
UnitInstance:
  id:                  UUID
  unit_template_id:    references UnitTemplate
  scenario_id:         references Scenario
  name:                "3rd Panzer Division" (custom display name)
  side:                :axis | :allied
  force:               :german | :soviet | etc.

  # Current state
  position:            {q, r} | nil (nil = not yet deployed)
  current_strength:    1..max_strength
  current_ammo:        integer
  current_fuel:        integer
  experience:          0-5 (green -> elite, affects combat rolls)
  morale:              0-100
  entrenchment:        0-3 (turns dug in, improves defense)

  # Turn state
  movement_remaining:  number
  has_attacked:        boolean
  has_moved:           boolean
  is_disrupted:        boolean
  is_routed:           boolean

  # Attachments (specialist steps a la Unity of Command)
  attachments:         [UnitTemplate.id] (heavy artillery, AT guns, etc.)

  # Deployment
  arrives_turn:        integer (reinforcement schedule)
  deploy_hex:          {q, r} | :map_edge_north | etc.
```

### Strength Steps Model

Units use strength steps (not individual soldiers):
- A unit at 10/15 strength fights at 66% effectiveness
- Visual: strength bar on the unit counter
- Losses are applied as step reductions
- Steps can be recovered via reinforcement/replacement (if in supply)

### Soft/Hard Attack Split

The core tactical tension:
- Infantry is devastating vs soft targets (high `attack_soft`)
- Tanks are devastating vs hard targets (high `attack_hard`)
- Defending unit's `armor` value determines which attack stat applies
- Combined arms (mixing unit types in an attack) provides bonuses

### Attachments (Unity of Command style)

Specialist steps that attach to base units:
- Heavy artillery, AT guns, engineers, AA guns, etc.
- Each attachment is itself a UnitTemplate but used as a modifier
- Adds its stats to the parent unit (e.g., AT attachment adds `attack_hard` bonus)
- Can be detached and reassigned between scenarios in campaign mode

### Leader System

Leaders are special units that provide command bonuses:

```
Leader:
  id:                  UUID
  name:                string ("Heinz Guderian")
  nationality:         string
  era:                 string
  is_historical:       boolean (named historical figure vs generic)
  rank:                lieutenant | captain | major | colonel | general | field_marshal

  # Command radius (hexes from leader where bonuses apply)
  command_radius:      1-6 (scales with rank)

  # Modifiers applied to units within command radius
  attack_modifier:     -2 to +3
  defense_modifier:    -2 to +3
  morale_modifier:     -10 to +20
  initiative_modifier: -2 to +3

  # Special abilities
  abilities:           [:inspire, :blitz, :fortify, :recon_bonus,
                        :artillery_expert, :combined_arms,
                        :defensive_genius, :logistics]

  # Replacement on death
  replacement_pool:    rank-appropriate generic leader auto-generated
```

**Rank-to-radius defaults:**

| Rank | Radius | Typical Command |
|------|--------|----------------|
| Lieutenant | 1 | Platoon/Company |
| Captain | 1 | Company/Battalion |
| Major | 2 | Battalion |
| Colonel | 2 | Regiment |
| General | 4 | Division/Corps |
| Field Marshal | 6 | Army |

**Command mechanics:**
- Leaders stack with a unit (their "HQ hex") and project a command radius
- Units **in radius** get the leader's modifiers
- Units **out of radius** fight at a penalty (reduced initiative, no morale recovery)
- Leader death: low probability per combat, increases if their hex is directly attacked. Generic replacement arrives with weaker stats.

**Nationalities for Eastern Front 1941-45:**
Germany, Soviet Union, Romania, Hungary, Italy, Finland

## 4. Scenario System

A scenario is the complete package needed to play a game:

```
Scenario:
  id:                  UUID
  name:                string
  description:         text
  map_id:              references Map
  action_profile_id:   references ActionProfile
  era:                 string
  date_start:          "1943-07-05" (historical date)
  date_per_turn:       :hours_6 | :hours_12 | :day | :days_2 | :week
  max_turns:           integer
  first_move:          side id (who goes first)

  sides: [
    %{id: :axis, name: "Axis", forces: [:german, :hungarian]},
    %{id: :allied, name: "Allied", forces: [:soviet]}
  ]

  victory_conditions:
    type:              :victory_points | :territorial | :elimination | :custom
    sudden_death_vp:   integer | nil
    vp_levels:         %{decisive: 80, tactical: 60, marginal: 40}
    unit_kill_vp:      %{armor: 3, infantry: 1, leader: 5}

  weather_schedule: [
    %{turns: 1..4, weather: :clear, ground: :dry},
    %{turns: 5..8, weather: :overcast, ground: :mud},
    %{turns: 9..12, weather: :snow, ground: :frozen}
  ]

  supply_sources: [
    %{side: :axis, hexes: [{0,5}, {0,6}], edge: :west}
  ]

  reinforcement_mode:  :fixed | :variable
  special_rules:       map (scenario-specific overrides)
```

### Era-Pluggable Action Profiles

The action model within a turn is era-configurable:

```
ActionProfile:
  id:                  UUID
  name:                "WW2 Standard"
  era:                 string

  action_options: [
    %{id: :move_and_fire,  move: true,  fire: true,  melee: false, move_penalty: 0.5},
    %{id: :fire_only,      move: false, fire: true,  melee: false},
    %{id: :move_only,      move: true,  fire: false, melee: false},
    %{id: :hold,           move: false, fire: false, melee: false, entrench: true},
    %{id: :assault,        move: true,  fire: true,  melee: true,  move_penalty: 0.5},
  ]

  phase_sequence: [ordered list of Phase definitions]
  rules_module:        module (e.g., WargameCore.Rules.StandardRules)
```

**Era examples:**

| Era | Actions | Phases | Distinct Mechanics |
|-----|---------|--------|--------------------|
| WW2 | move_and_fire, fire, move, hold | command, movement, combat, exploitation, supply, end | Soft/hard attack, armor |
| Civil War | move, fire, move_fire_melee, hold | command, movement, fire, melee, rally, end | Separate melee CRT, formation |
| Napoleonic | move, fire, charge, form_square, hold | command, movement, fire, melee, rally, end | Cavalry charges, squares |

The three axes are independent:
- **ActionProfile** = what choices a unit has
- **PhaseSequence** = turn structure
- **RulesModule** = resolution mechanics (implements RulesEngine behaviour)

### Weather Effects

Critical for Eastern Front campaigns:

| Weather | Ground | Movement Modifier | Combat Modifier | Air Support |
|---------|--------|------------------|----------------|------------|
| Clear | Dry | 1.0x | none | full |
| Rain | Mud | 0.5x wheeled, 0.7x tracked | -1 attacker | reduced |
| Overcast | Dry | 1.0x | none | none |
| Snow | Frozen | 0.8x all | -1 attacker | reduced |
| Blizzard | Frozen | 0.5x all | -2 attacker | none |
| Rasputitsa | Deep Mud | 0.3x wheeled, 0.5x tracked | -2 attacker | reduced |

### Supply Model (Unity of Command inspired)

- Supply sources are hexes on map edges
- Supply traces a path from source to unit (must not cross enemy ZOC or impassable terrain)
- Units out of supply: no ammo resupply, reduced morale recovery, strength attrition each turn
- Cutting supply lines is the core strategic gameplay of encirclement battles

### Reinforcement Modes

```
:fixed      → arrives exactly on arrives_turn (historical mode)

:variable   → probability-based around arrives_turn:
                base_probability: 80%
                earliest: arrives_turn - 1
                latest: arrives_turn + 3
                no_show_chance: 10%
                Probability increases each turn past arrives_turn

:conditional → arrives when condition met (e.g., "axis controls hex X")
```

Per-scenario setting: historical purists get exact arrivals, replayability seekers get uncertainty.

## 5. Game Runtime

### GameServer (GenServer per active game)

```
GameServer state:
  game_id:           UUID
  scenario:          loaded Scenario
  map:               GameMap
  units:             %{unit_id => UnitInstance}
  leaders:           %{leader_id => LeaderInstance}
  turn_state:        TurnState
  action_profile:    ActionProfile
  rules_module:      module()
  weather:           current weather from schedule
  supply_cache:      %{unit_id => :supplied | :unsupplied}
  fog_of_war:        %{side => MapSet of visible coords}
  action_log:        [ActionEntry]
  players:           %{side => player_id | :ai}
  settings:          %{fog_of_war: :full | :partial | :none,
                       ai_difficulty: atom, ai_personality: atom}
  status:            :setup | :playing | :paused | :finished
  result:            nil | {:victory, side, reason} | {:draw, reason}
```

### Action Flow

```
Player clicks "Move unit X to hex Y"
  │
  ├─ 1. Client: pushEvent("game_action", %{type: :move, unit_id: X, target: {q,r}})
  ├─ 2. GameLive forwards to GameServer: GenServer.call(pid, {:action, side, action})
  ├─ 3. GameServer pipeline:
  │     a. validate_phase_action(state, :move)        # right phase?
  │     b. validate_side(state, side)                  # your turn?
  │     c. rules_module.validate_movement(state, ...)  # legal move?
  │     d. rules_module.execute_movement(state, ...)   # apply it
  │     e. recalculate_fog_of_war(state, side)         # visibility update
  │     f. append_to_action_log(state, action)         # for replay
  │     g. broadcast_state_update(state)               # PubSub to clients
  ├─ 4. GameLive receives broadcast, pushes diff to frontend
  └─ 5. Renderer updates unit positions, animates movement
```

### Phase Scope

A phase covers ALL eligible units. The player issues all movement orders during the movement phase, then explicitly clicks "End Movement Phase" to advance. Each individual move is validated and applied immediately (unit by unit), but the phase doesn't end until the player commits.

### Turn Lifecycle

```
on_turn_start(turn_number):
  1. Advance weather (check schedule)
  2. Recalculate supply for all units
  3. Apply attrition to unsupplied units
  4. Deploy reinforcements (fixed or variable roll)
  5. Reset unit action flags
  6. Apply leader command radius bonuses
  7. Broadcast turn start

on_phase_start(phase_id):
  1. Phase-specific setup
  2. Broadcast phase change

on_phase_end(phase_id):
  1. Phase-specific cleanup
  2. If combat phase: resolve all declared combats

on_turn_end(turn_number):
  1. Entrenchment increases for stationary units
  2. Morale recovery (in supply + in command radius)
  3. Check victory conditions
  4. Persist game state snapshot
  5. If AI's turn next: trigger AI decision cycle
```

### Fog of War (configurable)

Settings: `:full` | `:partial` (terrain visible, units hidden) | `:none`

When enabled:
```
visible_hexes(state, side):
  for each friendly unit:
    effective_range = base_spotting
      + elevation_bonus (higher ground: +1 to +2)
      + leader_bonus (recon_bonus ability: +1)
      - terrain_reduction (concealment: -1 to -2)
      - weather_reduction (fog/snow/blizzard: -1 to -3)
    effective_range = max(1, effective_range)
    add all hexes within effective_range to visible set
```

Previously-seen terrain stays revealed; units vanish when not in LOS.

### Multiplayer via PubSub

```elixir
topic = "game:#{game_id}"
# Players subscribe on join
Phoenix.PubSub.subscribe(WargameWeb.PubSub, topic)
# GameServer broadcasts fog-filtered state per side
Phoenix.PubSub.broadcast(topic, {:game_update, filtered_state_for_side})
```

### Game Persistence

- State serialized to DB on each turn end (not every action)
- Action log persisted per-action for replay capability
- Save/resume support
- Completed games stored for replay viewing

## 6. AI System

### Architecture

Single strong AI with controlled degradation for difficulty levels:

```
AIPlayer:
  difficulty:    :novice | :regular | :veteran | :elite | :genius
  personality:   :aggressive | :defensive | :balanced | :historical
  side:          atom
```

### Difficulty Scaling

| Difficulty | Evaluation Depth | Mistakes | Bonuses |
|-----------|-----------------|----------|---------|
| Novice | 1 phase ahead | Ignores flanking, supply. 30% suboptimal moves | None |
| Regular | 1 turn ahead | Occasionally misses combos. 10% suboptimal | None |
| Veteran | 2 turns ahead | Plays clean | None |
| Elite | 2 turns ahead | Plays clean | +1 spotting range |
| Genius | 3 turns ahead | Plays clean | +1 spotting, +10% combat luck |

Elite/Genius bonuses simulate better generalship rather than requiring smarter algorithms.

### AI Decision Pipeline

```
Movement Phase:
  1. Evaluate threat map (enemy positions, likely attack zones)
  2. Identify objectives (VP hexes, supply lines, defensive positions)
  3. Score each unit's possible moves:
     - Proximity to objective
     - Defensive terrain value at destination
     - Friendly support (stacking, mutual ZOC)
     - Leader command radius coverage
     - Supply line maintenance
     - Avoid overextension
  4. Execute moves highest-priority units first

Combat Phase:
  1. Identify all possible attacks
  2. Calculate odds for each combination
  3. Score by expected outcome:
     - Favorable odds on VP hexes: high priority
     - Encirclement attacks: high priority
     - Unfavorable odds: skip unless desperate
  4. Allocate attackers to maximize expected VP gain
  5. Execute in priority order

Command Phase:
  1. Rally disrupted/routed units (prioritize experienced ones)
  2. Assign reinforcements to weakest sector
  3. Reposition leaders for optimal coverage
```

### Personality Modifiers

```
:aggressive  → attack weight +50%, accepts worse odds (2:3 minimum),
               pushes leaders forward

:defensive   → terrain defense weight +50%, won't attack below 2:1,
               keeps reserves, prioritizes entrenchment

:balanced    → no modifiers, plays by the book

:historical  → follows historical operational plans (configured per scenario
               as waypoints/objectives with turn targets)
```

### Execution Model

```
GameServer detects AI's turn
  → spawns Task: AIPlayer.play_turn(state, config)
  → AI returns list of actions
  → GameServer validates and executes each sequentially
  → broadcasts updates to human player
```

AI plays by the same rules as humans (uses same RulesEngine callbacks). Could swap in LLM-based AI as alternative backend later.

## 7. Persistence (Database Schemas)

All schemas in `wargame_persistence`, Postgres with pgvector available.

### maps

```
id:               uuid, primary key
name:             string
description:      text
version:          string
width:            integer
height:           integer
scale:            integer (meters per hex)
base_elevation:   integer
centerpoint_lat:  float, nullable
centerpoint_lng:  float, nullable
default_terrain:  string
metadata:         jsonb
tile_data:        binary (compressed erlang term)
author_id:        references users, nullable
published:        boolean, default false
timestamps
```

Tile data stored as compressed binary (`:erlang.term_to_binary/2`) - always loaded/saved as a whole unit.

### unit_templates

```
id:               uuid, primary key
name:             string
nationality:      string
era:              string
category:         string
unit_size:        string
icon_type:        string (NATO APP-6 symbol key)
stats:            jsonb (all combat/movement/capacity stats)
author_id:        references users, nullable
published:        boolean, default false
timestamps
```

Stats as JSONB for flexibility across eras without schema migrations.

### leaders

```
id:               uuid, primary key
name:             string
nationality:      string
era:              string
is_historical:    boolean
rank:             string
command_radius:   integer
modifiers:        jsonb (attack/defense/morale/initiative modifiers, abilities)
replacement_leader_id: references leaders, nullable
author_id:        references users, nullable
timestamps
```

### action_profiles

```
id:               uuid, primary key
name:             string
era:              string
actions:          jsonb (list of action option definitions)
phase_sequence:   jsonb (ordered phase definitions)
rules_module:     string (Elixir module name)
timestamps
```

### scenarios

```
id:               uuid, primary key
name:             string
description:      text
author_id:        references users, nullable
map_id:           references maps
action_profile_id: references action_profiles
era:              string
date_start:       string
date_per_turn:    string
max_turns:        integer
first_move:       string
sides:            jsonb
victory_conditions: jsonb
weather_schedule: jsonb
supply_sources:   jsonb
reinforcement_mode: string (:fixed | :variable)
special_rules:    jsonb
published:        boolean, default false
timestamps
```

### scenario_units

```
id:               uuid, primary key
scenario_id:      references scenarios
unit_template_id: references unit_templates
leader_id:        references leaders, nullable
side:             string
force:            string
name:             string
position_q:       integer, nullable
position_r:       integer, nullable
arrives_turn:     integer, default 1
deploy_zone:      string, nullable
strength:         integer
experience:       integer
morale:           integer
attachment_ids:   jsonb (list of unit_template_ids)
reinforcement_config: jsonb, nullable (variable mode parameters)
timestamps
```

### games

```
id:               uuid, primary key
scenario_id:      references scenarios
status:           string (setup, playing, paused, finished)
players:          jsonb (side -> user/AI mapping with settings)
settings:         jsonb (fog_of_war, ai_difficulty, ai_personality, etc.)
current_turn:     integer
game_state:       binary (compressed erlang term)
result:           jsonb, nullable
started_at:       utc_datetime, nullable
finished_at:      utc_datetime, nullable
timestamps
```

### game_actions

```
id:               uuid, primary key
game_id:          references games
turn:             integer
phase:            string
side:             string
sequence:         integer
action:           jsonb (type, parameters, results)
timestamps
```

### users

```
id:               uuid, primary key
username:         string, unique
email:            string, unique
password_hash:    string
timestamps
```

Minimal for now; `phx_gen_auth` can scaffold full auth later.

## 8. Frontend Architecture

### Existing

- PixiJS 2D hex renderer (1668 lines) - terrain, edges, transport, overlays, satellite
- MapEditorHook with drag-painting, file save/load
- LiveView-based map editor with full tool palette

### Unit Rendering (2D, NATO APP-6 style)

```
UnitCounter (PixiJS Container):
  ┌─────────────────────┐
  │  ═══  (unit size)   │  size indicator
  │  ┌─┐               │
  │  │X│  3rd Panzer    │  NATO symbol + short name
  │  └─┘               │
  │  12-15    6    ★★★  │  attack-defense, movement, experience
  │  ▓▓▓▓▓▓▓▓░░░░      │  strength bar
  └─────────────────────┘
  Border color = side
  Opacity = supply status
  Overlay icons: disrupted, routed, entrenched, out of ammo
```

- Pre-render NATO symbols as sprite atlas
- Stacked units show as offset counters (click to expand)
- Selected unit highlights reachable hexes
- Movement shown as animated path with dotted preview

### Game UI Layout

```
┌──────────────────────────────────────────────────────────┐
│ Turn 5/20 │ Movement Phase │ Axis Turn │ Clear/Dry       │
├──────────┬───────────────────────────────────┬───────────┤
│ Unit     │                                   │ Selected  │
│ List     │        MAP CANVAS (PixiJS)        │ Unit      │
│          │                                   │ Detail    │
│          │                                   │ Panel     │
├──────────┴───────────────────────────────────┴───────────┤
│ [End Phase] [Undo] │ Actions: [Move] [Fire] [Hold]      │
└──────────────────────────────────────────────────────────┘
```

LiveView owns UI chrome (panels, lists, buttons, status). PixiJS owns the map canvas. Communication via existing hook pattern (pushEvent up, handleEvent down).

### Additional Editor UIs

- **Scenario Editor** (`/scenario-editor`): select map, configure sides/victory/weather, place units, set reinforcement schedule, test-play button
- **Unit Template Editor** (`/unit-editor`): CRUD for unit templates, filter by nationality/era/category, live counter preview
- **Leader Editor** (`/leader-editor`): CRUD for leaders, historical leader database, ability configuration

### 3D Rendering (future, not in first build)

- Three.js alongside PixiJS (toggle 2D/3D)
- Hex terrain as heightmapped mesh (elevation data exists)
- Same data flow, different renderer consuming identical tile/unit data

## 9. Configurable Settings Summary

| Setting | Scope | Options |
|---------|-------|---------|
| Fog of War | per-game | `:full` \| `:partial` \| `:none` |
| AI Difficulty | per-game | `:novice` \| `:regular` \| `:veteran` \| `:elite` \| `:genius` |
| AI Personality | per-game | `:aggressive` \| `:defensive` \| `:balanced` \| `:historical` |
| Reinforcement Mode | per-scenario | `:fixed` \| `:variable` \| `:conditional` |
| Turn Structure | per-scenario | `:igougo` \| `:alternating_phase` \| `:simultaneous` |
| Action Profile | per-scenario | era-specific action sets |
| Weather | per-scenario | weather schedule with ground conditions |
