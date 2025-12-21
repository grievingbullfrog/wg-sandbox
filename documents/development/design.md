# Design Notes

Technical research and design decisions for the wargame platform.

---

## Hex Grid System

### Coordinate System: Axial Coordinates

Using axial coordinates (q, r) based on [Red Blob Games hex grid guide](https://www.redblobgames.com/grids/hexagons/).

- Store only `q` and `r`; compute `s = -q - r` when needed
- Pointy-top hexes as default orientation
- 1000m per hex scale for Battle of Kursk

```elixir
# Elixir implementation
defmodule WargameCore.Hex.Coord do
  @type t :: %__MODULE__{q: integer(), r: integer()}
  defstruct [:q, :r]

  def s(%__MODULE__{q: q, r: r}), do: -q - r

  def distance(a, b) do
    div(abs(a.q - b.q) + abs(a.r - b.r) + abs(s(a) - s(b)), 2)
  end
end
```

```typescript
// TypeScript implementation
interface AxialCoord {
  q: number;
  r: number;
}

class HexCoord implements AxialCoord {
  constructor(public readonly q: number, public readonly r: number) {}
  get s(): number { return -this.q - this.r; }
}
```

### Neighbor Directions (Pointy-Top)

```
Direction 0: (+1,  0)  - East
Direction 1: (+1, -1)  - Northeast
Direction 2: ( 0, -1)  - Northwest
Direction 3: (-1,  0)  - West
Direction 4: (-1, +1)  - Southwest
Direction 5: ( 0, +1)  - Southeast
```

---

## Rendering Architecture

### 2D View (PixiJS v8)

- Board game aesthetic with hex tiles and unit counters
- Sprite batching for efficient rendering of large maps
- Camera pan/zoom via container transforms

### 3D View (Babylon.js) - Future

- Terrain mesh from hex elevation data
- 3D unit models (GLTF/GLB format)
- Same camera position/rotation mapped to 3D space

### Mode Switching

Both renderers subscribe to shared game state. Only one is visible at a time:

```typescript
class GameRenderer {
  private pixi2D: Pixi2DRenderer;
  private babylon3D: Babylon3DRenderer;
  private activeMode: '2d' | '3d' = '2d';

  toggleMode(): void {
    this.activeMode = this.activeMode === '2d' ? '3d' : '2d';
    this.pixi2D.visible = this.activeMode === '2d';
    this.babylon3D.visible = this.activeMode === '3d';
  }
}
```

---

## Game State Management

### GenServer per Game Session

Each active game has its own GenServer process managing state.

```elixir
defmodule WargameCore.GameSession do
  use GenServer

  defstruct [:game_id, :scenario, :map, :units, :turn, :phase]

  def start_link(game_id, scenario_id) do
    GenServer.start_link(__MODULE__, {game_id, scenario_id}, name: via_tuple(game_id))
  end
end
```

### Data Storage

- **Runtime**: ETS tables for O(1) hex/unit lookups
- **Persistence**: PostgreSQL with JSONB for flexible schema
- **Snapshots**: Periodic saves every 5 minutes

---

## Scenario Data Format

Using YAML for human readability with JSON Schema validation.

```yaml
# scenarios/kursk_1943/scenario.yaml
meta:
  id: "kursk_1943_south"
  name: "Battle of Kursk - Southern Sector"
  scale: 1000  # meters per hex

map:
  width: 120
  height: 80
  orientation: pointy_top

sides:
  - id: "germany"
    name: "Wehrmacht"
  - id: "soviet"
    name: "Red Army"
```

---

## References

- [Red Blob Games - Hexagonal Grids](https://www.redblobgames.com/grids/hexagons/)
- [PixiJS Documentation](https://pixijs.com/)
- [Babylon.js Documentation](https://doc.babylonjs.com/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)
