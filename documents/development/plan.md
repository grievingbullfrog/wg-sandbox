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

### Phase 2: Core Game Engine (NEXT)
- Hex coordinate system (axial coordinates)
- Map data structures
- Turn/phase management
- Basic rules engine behaviour

### Phase 3: 2D Rendering & Map Display
- PixiJS hex grid rendering
- Terrain tile sprites
- Camera pan/zoom controls
- Hex selection and highlighting

### Phase 4: Map Editor
- LiveView-based hex map editor
- Terrain painting tools (brush, fill, line)
- Elevation editing
- Edge features (roads, rivers, railroads)
- Map save/load to YAML format
- Map resize and scale configuration

### Phase 5: Scenario Editor
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

## Critical Files to Create First

1. `apps/wargame_core/lib/hex/coord.ex` - Hex coordinate system
2. `apps/wargame_core/lib/hex/grid.ex` - Grid operations (neighbors, distance, LOS)
3. `apps/wargame_core/lib/map.ex` - Map data structure
4. `apps/wargame_web/assets/ts/engine/Pixi2DRenderer.ts` - 2D hex rendering
5. `apps/wargame_web/lib/wargame_web/live/map_editor_live.ex` - Map editor LiveView
6. `apps/wargame_web/lib/wargame_web/live/scenario_editor_live.ex` - Scenario editor LiveView
7. `apps/wargame_core/lib/game_session.ex` - Game session GenServer (single-player)
