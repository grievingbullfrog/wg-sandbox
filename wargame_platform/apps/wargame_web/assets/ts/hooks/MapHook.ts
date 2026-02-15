import { Pixi2DRenderer, TileData, Pixi2DRendererConfig, HexClickModifiers } from "../engine/Pixi2DRenderer";
import { HexCoord } from "../hex/coord";
import "../types/phoenix.d.ts";

/**
 * Phoenix LiveView Hook for the hex map display.
 *
 * This hook initializes and manages the PixiJS renderer,
 * handling communication between LiveView and the renderer.
 *
 * Usage in LiveView template:
 * ```heex
 * <canvas id="map-canvas" phx-hook="MapHook" phx-update="ignore"
 *         data-width="50" data-height="40" data-scale="200"></canvas>
 * ```
 */

export interface MapHookType {
  renderer: Pixi2DRenderer | null;
}

export const MapHook = {
  renderer: null as Pixi2DRenderer | null,

  async mounted(this: ViewHook & MapHookType) {
    const canvas = this.el as HTMLCanvasElement;

    // Get configuration from data attributes
    const config: Partial<Pixi2DRendererConfig> = {
      hexSize: parseInt(canvas.dataset.hexSize || "40"),
      showGrid: canvas.dataset.showGrid !== "false",
      showCoords: canvas.dataset.showCoords === "true",
      elevationToolActive: canvas.dataset.showElevation === "true",
    };

    // Create and initialize renderer
    this.renderer = new Pixi2DRenderer(config);
    await this.renderer.init(canvas);

    // Set up hex selection callback
    this.renderer.onHexSelected = (coord: HexCoord, modifiers: HexClickModifiers) => {
      this.pushEvent("hex_selected", { q: coord.q, r: coord.r, shift: modifiers.shift });
    };

    // Set up hex hover callback
    this.renderer.onHexHovered = (coord: HexCoord) => {
      this.pushEvent("hex_hovered", { q: coord.q, r: coord.r });
    };

    // Handle events from LiveView
    this.handleEvent("render_map", (data: unknown) => {
      const { tiles } = data as { tiles: TileData[] };
      if (this.renderer) {
        this.renderer.renderMap(tiles);

        // Center on map if dimensions provided
        const width = parseInt(canvas.dataset.width || "0");
        const height = parseInt(canvas.dataset.height || "0");
        if (width > 0 && height > 0) {
          this.renderer.centerOnMap(width, height);
        }
      }
    });

    this.handleEvent("update_tile", (data: unknown) => {
      const { tile } = data as { tile: TileData };
      if (this.renderer) {
        this.renderer.drawHex(tile);
      }
    });

    this.handleEvent("highlight_hexes", (data: unknown) => {
      const { hexes, mode } = data as { hexes: Array<{ q: number; r: number }>, mode: string };
      if (this.renderer) {
        const coords = hexes.map(h => ({ q: h.q, r: h.r }));
        this.renderer.highlightHexes(coords, mode as "selected" | "hover" | "movable" | "attackable" | "path");
      }
    });

    this.handleEvent("clear_highlights", () => {
      if (this.renderer) {
        this.renderer.clearAllHighlights();
      }
    });

    this.handleEvent("center_on_hex", (data: unknown) => {
      const { q, r } = data as { q: number; r: number };
      if (this.renderer) {
        this.renderer.centerOnHex({ q, r });
      }
    });

    this.handleEvent("set_config", (data: unknown) => {
      const config = data as Partial<Pixi2DRendererConfig>;
      if (this.renderer) {
        this.renderer.setConfig(config);
      }
    });

    // Request initial map data from server
    this.pushEvent("map_ready", {});
  },

  destroyed(this: ViewHook & MapHookType) {
    if (this.renderer) {
      this.renderer.destroy();
      this.renderer = null;
    }
  },

  reconnected(this: ViewHook & MapHookType) {
    // Request map data again after reconnection
    this.pushEvent("map_ready", {});
  },
};

export default MapHook;
