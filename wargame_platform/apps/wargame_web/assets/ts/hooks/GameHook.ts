/**
 * GameHook - LiveView ↔ PixiJS bridge for game play
 *
 * Handles communication between the GameLive LiveView and the PixiJS
 * renderer for interactive game play (unit display, movement, combat).
 */
import { Pixi2DRenderer, Pixi2DRendererConfig, TileData, HexClickModifiers } from "../engine/Pixi2DRenderer";
import { UnitData } from "../engine/UnitRenderer";
import { MovementOverlay, ReachableHex, CombatPreview } from "../engine/MovementOverlay";
import { HexCoord } from "../hex/coord";

export interface GameHookInterface {
  el: HTMLElement;
  renderer: Pixi2DRenderer | null;
  movementOverlay: MovementOverlay | null;
  pushEvent(event: string, payload: Record<string, unknown>): void;
  handleEvent(event: string, callback: (data: unknown) => void): void;
  mounted(): void;
  destroyed(): void;
  reconnected(): void;
}

/**
 * GameHook definition for Phoenix LiveView
 */
export const GameHook: GameHookInterface = {
  el: null as unknown as HTMLElement,
  renderer: null,
  movementOverlay: null,

  pushEvent(_event: string, _payload: Record<string, unknown>): void {},
  handleEvent(_event: string, _callback: (data: unknown) => void): void {},

  async mounted() {
    const canvas = this.el.querySelector("canvas") as HTMLCanvasElement;
    if (!canvas) {
      console.error("GameHook: No canvas element found");
      return;
    }

    // Initialize renderer in game mode
    const config: Partial<Pixi2DRendererConfig> = {
      hexSize: parseInt(canvas.dataset.hexSize || "40"),
      showGrid: true,
      showCoords: false,
    };

    this.renderer = new Pixi2DRenderer(config);
    await this.renderer.init(canvas);

    // Initialize movement overlay using the UI container
    this.movementOverlay = new MovementOverlay(
      this.renderer.getUIContainer(),
      config.hexSize || 40
    );

    // Set up hex interaction callbacks
    this.renderer.onHexSelected = (coord: HexCoord, modifiers: HexClickModifiers) => {
      this.pushEvent("hex_selected", {
        q: coord.q,
        r: coord.r,
        shift: modifiers.shift,
        ctrl: modifiers.ctrl,
      });
    };

    this.renderer.onHexHovered = (coord: HexCoord) => {
      this.pushEvent("hex_hovered", { q: coord.q, r: coord.r });
    };

    // --- Events from LiveView ---

    // Full game render: map tiles + units
    this.handleEvent("render_game", (data: unknown) => {
      const { tiles, units, width, height } = data as {
        tiles: TileData[];
        units: UnitData[];
        width: number;
        height: number;
      };
      if (this.renderer) {
        this.renderer.renderMap(tiles);
        this.renderer.setMapDimensions(width, height);
        this.renderer.centerOnMap(width, height);
        this.renderer.renderUnits(units);
      }
    });

    // Update map tiles only
    this.handleEvent("render_map", (data: unknown) => {
      const { tiles, width, height } = data as {
        tiles: TileData[];
        width: number;
        height: number;
      };
      if (this.renderer) {
        this.renderer.renderMap(tiles);
        this.renderer.setMapDimensions(width, height);
        this.renderer.centerOnMap(width, height);
      }
    });

    // Update all units
    this.handleEvent("update_units", (data: unknown) => {
      const { units } = data as { units: UnitData[] };
      if (this.renderer) {
        this.renderer.renderUnits(units);
      }
    });

    // Update a single unit
    this.handleEvent("update_unit", (data: unknown) => {
      const unit = data as UnitData;
      if (this.renderer) {
        this.renderer.updateUnit(unit);
      }
    });

    // Remove a destroyed unit
    this.handleEvent("remove_unit", (data: unknown) => {
      const { id } = data as { id: string };
      if (this.renderer) {
        this.renderer.removeUnit(id);
      }
    });

    // Show reachable hexes for movement
    this.handleEvent("show_reachable", (data: unknown) => {
      const { hexes } = data as { hexes: ReachableHex[] };
      if (this.movementOverlay) {
        this.movementOverlay.clearReachable();
        this.movementOverlay.showReachableHexes(hexes);
      }
    });

    // Show movement path preview
    this.handleEvent("show_path", (data: unknown) => {
      const { path } = data as { path: { q: number; r: number }[] };
      if (this.movementOverlay) {
        this.movementOverlay.clearPath();
        this.movementOverlay.showMovementPath(path);
      }
    });

    // Show combat preview (odds overlay)
    this.handleEvent("show_combat_preview", (data: unknown) => {
      const preview = data as CombatPreview;
      if (this.movementOverlay) {
        this.movementOverlay.clearCombat();
        this.movementOverlay.showCombatPreview(preview);
      }
    });

    // Combat result animation
    this.handleEvent("combat_result", (data: unknown) => {
      const { result, targetHex } = data as {
        result: string;
        targetHex: { q: number; r: number };
      };
      // Flash the target hex with result color
      if (this.renderer) {
        const mode = result === "DE" || result === "DR" ? "attackable" : "path";
        this.renderer.highlightHex(targetHex, mode);
        // Auto-clear after animation
        setTimeout(() => {
          if (this.renderer) {
            this.renderer.clearHighlight(targetHex);
          }
        }, 1500);
      }
    });

    // Clear all overlays
    this.handleEvent("clear_selection", (_data: unknown) => {
      if (this.movementOverlay) {
        this.movementOverlay.clear();
      }
      if (this.renderer) {
        this.renderer.clearAllHighlights();
      }
    });

    // Highlight specific hexes
    this.handleEvent("highlight_hexes", (data: unknown) => {
      const { coords, mode } = data as {
        coords: { q: number; r: number }[];
        mode: "selected" | "hover" | "movable" | "attackable" | "path";
      };
      if (this.renderer) {
        this.renderer.highlightHexes(coords, mode);
      }
    });

    // Clear highlights
    this.handleEvent("clear_highlights", (_data: unknown) => {
      if (this.renderer) {
        this.renderer.clearAllHighlights();
      }
    });

    // Center camera on a hex
    this.handleEvent("center_on_hex", (data: unknown) => {
      const { q, r } = data as { q: number; r: number };
      if (this.renderer) {
        this.renderer.centerOnHex({ q, r });
      }
    });

    // Update config
    this.handleEvent("set_config", (data: unknown) => {
      const config = data as Partial<Pixi2DRendererConfig>;
      if (this.renderer) {
        this.renderer.setConfig(config);
      }
    });

    // Notify LiveView that the canvas is ready
    this.pushEvent("game_canvas_ready", {});
  },

  destroyed() {
    if (this.movementOverlay) {
      this.movementOverlay.destroy();
      this.movementOverlay = null;
    }
    if (this.renderer) {
      this.renderer.destroy();
      this.renderer = null;
    }
  },

  reconnected() {
    // Request fresh game state after reconnection
    this.pushEvent("request_game_state", {});
  },
};
