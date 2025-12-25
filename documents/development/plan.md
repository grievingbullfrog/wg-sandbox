# Wargame Platform Development Plan

## Overview

Build a browser-based turn-based strategy wargame platform inspired by 90s Talonsoft games (Eastern Front, Western Front). The platform will be data-driven and scenario-agnostic, supporting both 2D board-game and 3D realistic rendering modes.

**First Scenario**: Grossdeutschland at Butovo-Gertsovka (July 4-5, 1943)
- Scale: 200m per hex
- Map: ~50x40 hexes (10km x 8km)
- See [scenarios.md](scenarios.md) for full details

---

## Technology Stack

### Backend
- **Elixir Umbrella App** with Phoenix + LiveView
- **PostgreSQL** for persistence
- **Phoenix Channels** for real-time game state sync

### Frontend
- **PixiJS v8** - 2D board-game style rendering (fastest WebGL 2D renderer)
- **Babylon.js** - 3D realistic terrain/units (TypeScript-native, excellent tooling)
- **Solid.js** - Lightweight reactive UI for menus/dialogs

---

## Elixir Umbrella Structure

```
wargame_platform/
├── apps/
│   ├── wargame_core/          # Pure game logic (no Phoenix deps)
│   │   ├── hex/               # Hex grid mathematics
│   │   ├── units/             # Unit types, stats, behaviors
│   │   ├── terrain/           # Terrain types and effects
│   │   ├── combat/            # Combat resolution engine
│   │   ├── movement/          # Movement rules, pathfinding
│   │   ├── turns/             # Turn sequence and phases
│   │   └── scenarios/         # Scenario loading/validation
│   │
│   ├── wargame_ai/            # AI opponent logic
│   │   ├── strategies/        # Strategic AI behaviors
│   │   ├── tactics/           # Tactical decision making
│   │   └── evaluation/        # Position evaluation
│   │
│   ├── wargame_persistence/   # Ecto repo, schemas, migrations
│   ├── wargame_matchmaking/   # Lobbies, game sessions
│   ├── wargame_accounts/      # User auth, profiles
│   │
│   └── wargame_web/           # Phoenix web interface
│       ├── live/              # LiveView modules
│       ├── channels/          # Phoenix Channels (game sync)
│       └── assets/ts/         # TypeScript frontend
```

---

## Development Phases

### Phase 1: Foundation & Infrastructure ✅ COMPLETE
- [x] Elixir umbrella project setup
- [x] Phoenix + LiveView configuration
- [x] TypeScript build pipeline (esbuild) with PixiJS + Babylon.js + Solid.js
- [x] PostgreSQL + Ecto configuration
- [x] Docker dev environment (docker-compose.yml)
- [x] TypeScript hex coordinate system (`assets/ts/hex/coord.ts`)
- [x] PixiJS 2D renderer scaffold (`assets/ts/engine/Pixi2DRenderer.ts`)

### Phase 2: Core Game Engine ✅ COMPLETE
- [x] Hex coordinate system (`wargame_core/hex/coord.ex`)
- [x] Hex grid operations (`wargame_core/hex/grid.ex`) - neighbors, distance, LOS, pathfinding
- [x] Terrain types module (`wargame_core/terrain/terrain_type.ex`) - 20 terrain types
- [x] Map tile structure (`wargame_core/map/tile.ex`) - terrain, elevation, edges, overlays
- [x] Map data structure (`wargame_core/map/map.ex`) - dimensions, tiles, pathfinding
- [x] Turn/phase management (`wargame_core/turns/`) - phases, turn state, IGOUGO
- [x] Rules engine behaviour (`wargame_core/rules/`) - movement, combat, victory conditions

### Phase 2A: Test Suite ✅ COMPLETE
- [x] Elixir test infrastructure with ExUnit
- [x] TypeScript test infrastructure with Vitest
- [x] Comprehensive test coverage for all core modules (91% coverage)
- [x] Parallel test execution with unique identifiers
- [x] Doctest integration for public API examples

### Phase 3: 2D Rendering & Map Display ✅ COMPLETE
- [x] PixiJS hex grid rendering (`assets/ts/engine/Pixi2DRenderer.ts`)
- [x] Terrain tile colors (20 terrain types matching Elixir backend)
- [x] Camera pan/zoom controls (mouse drag & scroll wheel)
- [x] Hex selection and highlighting (5 highlight modes)
- [x] LiveView integration via Phoenix hooks (`assets/ts/hooks/MapHook.ts`)
- [x] Demo map view (`/map-demo` route)
- [x] Edge features rendering (roads, rivers, railroads, bridges)
- [x] Overlay rendering (fortifications, trenches, minefields, bunkers, wire)
- [x] Victory point indicators and control flags
- [x] Coordinate labels and elevation shading

### Phase 4: Map Editor ✅ COMPLETE
- [x] LiveView-based hex map editor (`lib/wargame_web_web/live/map_editor_live.ex`)
- [x] Terrain painting tools (brush, fill, line, eraser)
- [x] Elevation editing with selectable levels (0-5)
- [x] Edge features editing (roads, rivers, railroads, streams, bridges, fords)
- [x] Overlay editing (fortifications, trenches, minefields, bunkers, wire)
- [x] Map save/load to YAML format with download/upload
- [x] Map resize and scale configuration modal
- [x] Undo/redo history (50 levels)
- [x] View options (grid, coordinates, elevation shading)
- [x] Real-time hex info panel
- [x] Phoenix hook for client-side rendering (`assets/ts/hooks/MapEditorHook.ts`)
- [x] Comprehensive test suite (27 tests)

### Phase 5: Scenario Editor (NEXT)
- Scenario metadata editing (name, description, scale, sides)
- Starting unit placement with drag-and-drop
- Order of Battle (OOB) management
- Victory condition configuration
- Turn structure settings
- Scenario save/load and validation

### Phase 6: Unit System
- Unit template system (data-driven definitions)
- Unit counter rendering (2D sprites)
- Movement execution with terrain costs
- Stacking validation
- Unit facing and orientation

### Phase 7: Combat & Rules Engine
- Odds-based combat resolution (CRT tables)
- Artillery bombardment
- Air combat and ground support
- Morale system with routing

### Phase 8: AI Opponent
- Position evaluation function
- Move generation and scoring
- Multiple AI personalities (aggressive, defensive, balanced)
- Difficulty levels

### Phase 9: Grossdeutschland at Butovo-Gertsovka Scenario
- Historical map (50x40 hexes at 200m scale)
- Grossdeutschland division OOB (Panthers, Tigers, Panzergrenadiers)
- Soviet 6th Guards Army defensive positions
- Special rules: minefields, marshy terrain, fortifications
- Playtesting and balancing

### Future Scenarios (see scenarios.md)
- Battle for Ponyri (infantry/urban combat)
- III Panzer Corps Donets Crossing (river assault)
- Olkhovatka Heights (elevation/defensive terrain)
- II SS Panzer Corps at Prokhorovka (large armor battle)

### Phase 10: 3D Rendering (Future)
- Babylon.js terrain generation
- 3D unit models
- 2D/3D view toggle

### Phase 11: Network Multiplayer (Future)
- Game lobbies
- Phoenix Presence for player status
- Turn timer enforcement
- Save/load for interrupted games
- Spectator mode

---

## Key Technical Decisions

### Hex Coordinates
- **Axial coordinates** (q, r) with computed s = -q - r
- Based on Red Blob Games implementation guide
- ETS for runtime O(1) lookups, PostgreSQL JSONB for persistence

### Rendering Architecture
- Separate PixiJS (2D) and Babylon.js (3D) renderer instances
- Shared game state manager
- Toggle visibility for mode switching

### Real-time Communication
- **LiveView** for UI and single-player game state
- **Phoenix Channels** for future network multiplayer (deferred)

### Game State Management
- GenServer per active game session
- ETS for hot data access
- Periodic PostgreSQL snapshots

### Scenario Data Format
- YAML for human-readable scenario files
- JSON Schema for validation
- Converts to internal Elixir structs at load time

---

## Running Tests

### Elixir Tests (ExUnit)

Run all tests from the umbrella root:
```bash
cd wargame_platform
mix test
```

Run tests for a specific app:
```bash
mix test apps/wargame_core/test
mix test apps/wargame_web/test
```

Run a specific test file:
```bash
mix test apps/wargame_core/test/wargame_core/hex/coord_test.exs
```

Run tests matching a pattern:
```bash
mix test apps/wargame_core/test --only test:"distance"
```

#### Test Coverage by Module

**wargame_core** (332 tests, 29 doctests) - **91% code coverage**:

| Module | Coverage | Test File |
|--------|----------|-----------|
| WargameCore.Hex.Coord | 100% | `hex/coord_test.exs` |
| WargameCore.Hex.Grid | 100% | `hex/grid_test.exs` |
| WargameCore.Terrain.TerrainType | 100% | `terrain/terrain_type_test.exs` |
| WargameCore.Turns.Phase | 100% | `turns/phase_test.exs` |
| WargameCore.Map | 97% | `map/map_test.exs` |
| WargameCore.Turns.TurnState | 92% | `turns/turn_state_test.exs` |
| WargameCore.Rules.StandardRules | 86% | `rules/standard_rules_test.exs` |
| WargameCore.Map.Tile | 78% | `map/tile_test.exs` |

**wargame_web** (44 tests) - **65% code coverage**:

| Module | Coverage | Test File |
|--------|----------|-----------|
| WargameWebWeb.MapEditorLive | 90% | `live/map_editor_live_test.exs` |
| WargameWebWeb.MapDemoLive | 95% | `live/map_demo_live_test.exs` |
| WargameWebWeb.Router | 80% | (via integration tests) |

*Note: Lower wargame_web coverage is expected as it includes Phoenix boilerplate (Telemetry, CoreComponents) not typically unit tested.*

### TypeScript Tests (Vitest)

Run tests from the assets directory:
```bash
cd wargame_platform/apps/wargame_web/assets
npm run test        # Single run
npm run test:watch  # Watch mode
```

#### TypeScript Test Coverage

| Module | Tests | Test File |
|--------|-------|-----------|
| HexCoord class | 54 | `ts/hex/coord.test.ts` |
| Pixi2DRenderer types | 10 | `ts/engine/Pixi2DRenderer.test.ts` |

**Total: 64 tests**

Covers:
- HexCoord class, direction functions, pixel conversion, range/ring/line algorithms
- Terrain types matching Elixir backend, tile data structures, highlight modes, config validation

### Test Design Principles

1. **Parallel Execution Safety**: All tests use `async: true` and generate unique identifiers per test process using `:erlang.phash2(self())` and `:erlang.unique_integer([:positive])` to prevent conflicts.

2. **No External Dependencies**: Core game logic tests don't require a database or external services.

3. **Doctest Integration**: All public functions with `@doc` examples are tested via doctests.

---

## Critical Files to Create First

1. `apps/wargame_core/lib/hex/coord.ex` - Hex coordinate system
2. `apps/wargame_core/lib/hex/grid.ex` - Grid operations (neighbors, distance, LOS)
3. `apps/wargame_core/lib/map.ex` - Map data structure
4. `apps/wargame_web/assets/ts/engine/Pixi2DRenderer.ts` - 2D hex rendering
5. `apps/wargame_web/lib/wargame_web/live/map_editor_live.ex` - Map editor LiveView
6. `apps/wargame_web/lib/wargame_web/live/scenario_editor_live.ex` - Scenario editor LiveView
7. `apps/wargame_core/lib/game_session.ex` - Game session GenServer (single-player)
