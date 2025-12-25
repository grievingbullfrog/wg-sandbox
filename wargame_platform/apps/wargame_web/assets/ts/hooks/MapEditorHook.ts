import { Pixi2DRenderer, TileData, Pixi2DRendererConfig, HexClickModifiers } from "../engine/Pixi2DRenderer";
import { HexCoord } from "../hex/coord";
import "../types/phoenix.d.ts";

/**
 * Phoenix LiveView Hook for the hex map editor.
 *
 * This hook extends the basic MapHook with editor-specific functionality:
 * - Continuous painting while dragging
 * - File upload/download for save/load
 * - Bulk tile updates
 *
 * Usage in LiveView template:
 * ```heex
 * <canvas id="map-editor-canvas" phx-hook="MapEditorHook" phx-update="ignore"
 *         data-width="50" data-height="40" data-hex-size="40"></canvas>
 * ```
 */

export interface MapEditorHookType {
  renderer: Pixi2DRenderer | null;
  isPainting: boolean;
  lastPaintedHex: { q: number; r: number } | null;
  downloadFile: (content: string, filename: string, type: string) => void;
  requestFileUpload: () => void;
}

export const MapEditorHook = {
  renderer: null as Pixi2DRenderer | null,
  isPainting: false,
  lastPaintedHex: null as { q: number; r: number } | null,

  async mounted(this: ViewHook & MapEditorHookType) {
    const canvas = this.el as HTMLCanvasElement;

    // Get configuration from data attributes
    const config: Partial<Pixi2DRendererConfig> = {
      hexSize: parseInt(canvas.dataset.hexSize || "40"),
      showGrid: canvas.dataset.showGrid !== "false",
      showCoords: canvas.dataset.showCoords === "true",
      tileOverlay: (canvas.dataset.tileOverlay as Pixi2DRendererConfig["tileOverlay"]) || "none",
    };

    // Create and initialize renderer
    this.renderer = new Pixi2DRenderer(config);
    await this.renderer.init(canvas);

    // Set up hex selection callback (for single clicks)
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

    this.handleEvent("update_tiles", (data: unknown) => {
      const { tiles } = data as { tiles: TileData[] };
      if (this.renderer) {
        this.renderer.updateHexes(tiles);
      }
    });

    this.handleEvent("update_tile", (data: unknown) => {
      const { tile } = data as { tile: TileData };
      if (this.renderer) {
        this.renderer.updateHex(tile);
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
        // Check if any rendering-affecting config changed
        const needsRerender =
          config.showGrid !== undefined ||
          config.showCoords !== undefined ||
          config.tileOverlay !== undefined;

        this.renderer.setConfig(config);

        // Only re-render the map if rendering config changed
        // (not for tool state changes like elevationToolActive)
        if (needsRerender) {
          this.pushEvent("map_ready", {});
        }
      }
    });

    // File download handling
    this.handleEvent("download_file", (data: unknown) => {
      const { content, filename, type } = data as { content: string; filename: string; type: string };
      this.downloadFile(content, filename, type);
    });

    // File upload request handling
    this.handleEvent("request_file_upload", () => {
      this.requestFileUpload();
    });

    // Request initial map data from server
    this.pushEvent("map_ready", {});
  },

  destroyed(this: ViewHook & MapEditorHookType) {
    if (this.renderer) {
      this.renderer.destroy();
      this.renderer = null;
    }
  },

  reconnected(this: ViewHook & MapEditorHookType) {
    // Request map data again after reconnection
    this.pushEvent("map_ready", {});
  },

  /**
   * Download a file to the user's computer
   */
  downloadFile(this: ViewHook & MapEditorHookType, content: string, filename: string, type: string) {
    const blob = new Blob([content], { type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  },

  /**
   * Request a file upload from the user
   */
  requestFileUpload(this: ViewHook & MapEditorHookType) {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".yaml,.yml";

    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (event) => {
          const content = event.target?.result as string;
          this.pushEvent("file_loaded", {
            content,
            filename: file.name
          });
        };
        reader.readAsText(file);
      }
    };

    input.click();
  },
};

export default MapEditorHook;
