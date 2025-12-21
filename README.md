# Wargame Platform

A browser-based turn-based strategy wargame platform inspired by 90s Talonsoft games (Eastern Front, Western Front, etc.). Build historical wargame scenarios with a data-driven, scenario-agnostic engine.

## Tech Stack

- **Backend**: Elixir umbrella app + Phoenix + LiveView
- **Frontend**: PixiJS (2D) + Babylon.js (3D) + Solid.js (UI)
- **Database**: PostgreSQL

## Project Structure

```
wargame_platform/
├── apps/
│   ├── wargame_core/          # Pure game logic
│   ├── wargame_ai/            # AI opponent
│   ├── wargame_persistence/   # Database layer
│   ├── wargame_matchmaking/   # Game sessions
│   ├── wargame_accounts/      # User management
│   └── wargame_web/           # Phoenix web interface
```

## Development

See [documents/development/plan.md](documents/development/plan.md) for the full development plan.

### Prerequisites

- Elixir 1.16+ / OTP 26+
- Node.js 20+ LTS
- PostgreSQL 16+
- pnpm (preferred) or npm

### Setup

```bash
# Install dependencies
mix deps.get
cd apps/wargame_web/assets && pnpm install

# Setup database
mix ecto.setup

# Start the server
mix phx.server
```

## Documentation

- [Development Plan](documents/development/plan.md)
- [Features](documents/development/features.md)
- [Design Notes](documents/development/design.md)

## First Scenario

**Battle of Kursk** (WWII Eastern Front) - A large-scale air and land battle at 1000m per hex scale.
