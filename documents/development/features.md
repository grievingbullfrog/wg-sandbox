# Features

Platform features organized by development phase.

---

## Phase 1: Foundation & Infrastructure

- [ ] Elixir umbrella project with 6 child apps
- [ ] Phoenix + LiveView web application
- [ ] TypeScript build pipeline (esbuild)
- [ ] PostgreSQL database with Ecto
- [ ] Basic user authentication
- [ ] Docker development environment

---

## Phase 2: Core Game Engine

- [ ] Axial hex coordinate system
- [ ] Map data structure with tiles
- [ ] Turn and phase management
- [ ] Rules engine behaviour/protocol

---

## Phase 3: 2D Rendering

- [ ] PixiJS hex grid rendering
- [ ] Terrain tile sprites
- [ ] Camera pan and zoom
- [ ] Hex selection and highlighting
- [ ] Unit counter display
- [ ] Fog of war (optional visibility)

---

## Phase 4: Map Editor

- [ ] Create new maps (width x height)
- [ ] Set map scale (meters per hex)
- [ ] Terrain painting (brush, fill)
- [ ] Elevation editing
- [ ] Road/railroad placement
- [ ] River/stream placement
- [ ] Save/load maps (YAML)
- [ ] Map validation

---

## Phase 5: Scenario Editor

- [ ] Scenario metadata (name, description, date)
- [ ] Side configuration (nations, colors)
- [ ] Starting unit placement
- [ ] Order of Battle management
- [ ] Victory conditions setup
- [ ] Turn structure configuration
- [ ] Save/load scenarios (YAML)
- [ ] Scenario validation

---

## Phase 6: Unit System

- [ ] Unit template definitions (YAML)
- [ ] Unit categories (infantry, armor, artillery, air)
- [ ] Unit stats (attack, defense, movement)
- [ ] Unit facing (6 directions)
- [ ] Stacking limits per hex
- [ ] Supply tracking
- [ ] Morale and experience

---

## Phase 7: Combat System

- [ ] Odds-based combat resolution
- [ ] Combat Results Table (CRT)
- [ ] Terrain defense modifiers
- [ ] Combined arms bonuses
- [ ] Artillery bombardment
- [ ] Air strikes and support
- [ ] Morale checks and routing
- [ ] Retreat and advance after combat

---

## Phase 8: AI Opponent

- [ ] Position evaluation function
- [ ] Move generation
- [ ] Combat decision AI
- [ ] Strategic objective prioritization
- [ ] Difficulty levels (easy, normal, hard)
- [ ] AI personalities (aggressive, defensive, balanced)

---

## Phase 9: Battle of Kursk Scenario

- [ ] Historical map (120x80 hexes)
- [ ] German OOB (4th Panzer Army, Army Detachment Kempf)
- [ ] Soviet OOB (Voronezh Front)
- [ ] Fortified defensive lines
- [ ] Minefield hexes
- [ ] Historical victory conditions
- [ ] Scenario documentation

---

## Future: Phase 10 - 3D Rendering

- [ ] Babylon.js terrain generation
- [ ] 3D unit models
- [ ] 2D/3D view toggle
- [ ] Lighting and shadows
- [ ] Camera flyover mode

---

## Future: Phase 11 - Network Multiplayer

- [ ] Game lobbies
- [ ] Real-time game sync (Phoenix Channels)
- [ ] Turn timers
- [ ] Reconnection handling
- [ ] Save/resume games
- [ ] Spectator mode
- [ ] Chat integration
