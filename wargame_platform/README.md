# Wargame Platform

A browser-based turn-based strategy wargame platform inspired by 90s Talonsoft games.

## Tech Stack

- **Backend**: Elixir 1.18+ / OTP 26+, Phoenix 1.8, LiveView
- **Frontend**: PixiJS (2D), Babylon.js (3D), Solid.js (UI), TypeScript
- **Database**: PostgreSQL 16+

## Project Structure

```
wargame_platform/
├── apps/
│   ├── wargame_core/          # Pure game logic (no Phoenix deps)
│   ├── wargame_ai/            # AI opponent logic
│   ├── wargame_persistence/   # Ecto repo and schemas
│   ├── wargame_matchmaking/   # Game sessions
│   ├── wargame_accounts/      # User management
│   └── wargame_web/           # Phoenix web interface
├── config/                    # Umbrella configuration
└── docker-compose.yml         # Docker dev environment
```

## Development Setup

### Prerequisites

- Elixir 1.18+
- Node.js 20+ LTS
- PostgreSQL 16+ (or use Docker)
- pnpm (recommended) or npm

### With Docker

```bash
# Start PostgreSQL
docker-compose up db -d

# Install dependencies
mix deps.get
cd apps/wargame_web/assets && pnpm install && cd ../../..

# Setup database
mix ecto.setup

# Start the server
mix phx.server
```

### Without Docker

```bash
# Ensure PostgreSQL is running locally

# Install dependencies
mix deps.get
cd apps/wargame_web/assets && pnpm install && cd ../../..

# Setup database
mix ecto.create
mix ecto.migrate

# Start the server
mix phx.server
```

Visit http://localhost:4000

## Running Tests

```bash
mix test
```

## Umbrella Apps

| App | Description |
|-----|-------------|
| `wargame_core` | Pure game logic: hex grids, units, terrain, combat, turns |
| `wargame_ai` | AI opponent: evaluation, strategies, difficulty levels |
| `wargame_persistence` | Database layer: Ecto repo, schemas, migrations |
| `wargame_matchmaking` | Game sessions and (future) lobbies |
| `wargame_accounts` | User authentication and profiles |
| `wargame_web` | Phoenix web interface with LiveView |
