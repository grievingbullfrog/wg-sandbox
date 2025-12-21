import { Application, Container, Graphics } from "pixi.js";
import { HexCoord, hexToPixel, pixelToHex, AxialCoord } from "../hex/coord";

/**
 * Terrain type enumeration matching backend terrain types
 */
export type TerrainType =
  | "clear"
  | "forest_pine"
  | "forest_deciduous"
  | "mountain"
  | "hill"
  | "desert"
  | "farmland"
  | "pasture"
  | "swamp"
  | "lake"
  | "ocean"
  | "urban"
  | "ruins";

/**
 * Color mapping for terrain types
 */
const TERRAIN_COLORS: Record<TerrainType, number> = {
  clear: 0x90ee90,        // Light green
  forest_pine: 0x228b22,  // Forest green
  forest_deciduous: 0x32cd32, // Lime green
  mountain: 0x808080,     // Gray
  hill: 0xa0522d,         // Sienna
  desert: 0xf4a460,       // Sandy brown
  farmland: 0xdaa520,     // Goldenrod
  pasture: 0x98fb98,      // Pale green
  swamp: 0x556b2f,        // Dark olive green
  lake: 0x4169e1,         // Royal blue
  ocean: 0x000080,        // Navy
  urban: 0x696969,        // Dim gray
  ruins: 0x8b4513,        // Saddle brown
};

/**
 * Tile data for rendering
 */
export interface TileData {
  coord: AxialCoord;
  terrain: TerrainType;
  elevation?: number;
}

/**
 * Configuration for the 2D renderer
 */
export interface Pixi2DRendererConfig {
  hexSize: number;
  backgroundColor: number;
}

const DEFAULT_CONFIG: Pixi2DRendererConfig = {
  hexSize: 40,
  backgroundColor: 0x1a1a2e,
};

/**
 * 2D hex map renderer using PixiJS
 */
export class Pixi2DRenderer {
  private app: Application;
  private mapContainer: Container;
  private unitContainer: Container;
  private uiContainer: Container;
  private config: Pixi2DRendererConfig;
  private selectedHex: HexCoord | null = null;
  private hoveredHex: HexCoord | null = null;

  constructor(config: Partial<Pixi2DRendererConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.app = new Application();
    this.mapContainer = new Container();
    this.unitContainer = new Container();
    this.uiContainer = new Container();
  }

  /**
   * Initialize the renderer with a canvas element
   */
  async init(canvas: HTMLCanvasElement): Promise<void> {
    await this.app.init({
      canvas,
      width: canvas.clientWidth,
      height: canvas.clientHeight,
      backgroundColor: this.config.backgroundColor,
      antialias: true,
      resolution: window.devicePixelRatio || 1,
      autoDensity: true,
    });

    // Set up container hierarchy
    this.app.stage.addChild(this.mapContainer);
    this.app.stage.addChild(this.unitContainer);
    this.app.stage.addChild(this.uiContainer);

    // Enable interactivity
    this.app.stage.eventMode = "static";
    this.app.stage.hitArea = this.app.screen;

    // Set up pan and zoom
    this.setupCameraControls();

    // Handle window resize
    window.addEventListener("resize", () => this.handleResize(canvas));
  }

  /**
   * Set up camera pan and zoom controls
   */
  private setupCameraControls(): void {
    let isDragging = false;
    let lastPosition = { x: 0, y: 0 };

    this.app.stage.on("pointerdown", (event) => {
      isDragging = true;
      lastPosition = { x: event.global.x, y: event.global.y };
    });

    this.app.stage.on("pointerup", () => {
      isDragging = false;
    });

    this.app.stage.on("pointerupoutside", () => {
      isDragging = false;
    });

    this.app.stage.on("pointermove", (event) => {
      if (isDragging) {
        const dx = event.global.x - lastPosition.x;
        const dy = event.global.y - lastPosition.y;
        this.mapContainer.x += dx;
        this.mapContainer.y += dy;
        this.unitContainer.x += dx;
        this.unitContainer.y += dy;
        lastPosition = { x: event.global.x, y: event.global.y };
      } else {
        // Update hovered hex
        const worldPos = this.screenToWorld(event.global.x, event.global.y);
        this.hoveredHex = pixelToHex(worldPos.x, worldPos.y, this.config.hexSize);
      }
    });

    // Zoom with mouse wheel
    this.app.canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      const scaleFactor = event.deltaY > 0 ? 0.9 : 1.1;
      const minScale = 0.25;
      const maxScale = 4;

      const newScale = Math.max(
        minScale,
        Math.min(maxScale, this.mapContainer.scale.x * scaleFactor)
      );

      // Zoom towards mouse position
      const mouseX = event.offsetX;
      const mouseY = event.offsetY;

      const worldPosBefore = this.screenToWorld(mouseX, mouseY);

      this.mapContainer.scale.set(newScale);
      this.unitContainer.scale.set(newScale);

      const worldPosAfter = this.screenToWorld(mouseX, mouseY);

      this.mapContainer.x += (worldPosAfter.x - worldPosBefore.x) * newScale;
      this.mapContainer.y += (worldPosAfter.y - worldPosBefore.y) * newScale;
      this.unitContainer.x = this.mapContainer.x;
      this.unitContainer.y = this.mapContainer.y;
    });
  }

  /**
   * Convert screen coordinates to world coordinates
   */
  private screenToWorld(screenX: number, screenY: number): { x: number; y: number } {
    return {
      x: (screenX - this.mapContainer.x) / this.mapContainer.scale.x,
      y: (screenY - this.mapContainer.y) / this.mapContainer.scale.y,
    };
  }

  /**
   * Handle window resize
   */
  private handleResize(canvas: HTMLCanvasElement): void {
    this.app.renderer.resize(canvas.clientWidth, canvas.clientHeight);
  }

  /**
   * Draw a single hex tile
   */
  drawHex(coord: AxialCoord, terrain: TerrainType): Graphics {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const hex = new Graphics();
    const color = TERRAIN_COLORS[terrain] ?? TERRAIN_COLORS.clear;

    // Draw filled hex
    hex.poly(this.getHexPoints(0, 0));
    hex.fill(color);
    hex.stroke({ width: 1, color: 0x000000, alpha: 0.3 });

    hex.x = x;
    hex.y = y;

    // Store coordinate data for click handling
    hex.eventMode = "static";
    hex.cursor = "pointer";
    hex.on("pointerdown", () => {
      this.selectedHex = new HexCoord(coord.q, coord.r);
      this.onHexSelected?.(this.selectedHex);
    });

    this.mapContainer.addChild(hex);
    return hex;
  }

  /**
   * Get the corner points of a pointy-top hex centered at origin
   */
  private getHexPoints(centerX: number, centerY: number): number[] {
    const points: number[] = [];
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI / 3) * i - Math.PI / 6;
      points.push(
        centerX + this.config.hexSize * Math.cos(angle),
        centerY + this.config.hexSize * Math.sin(angle)
      );
    }
    return points;
  }

  /**
   * Render a complete map from tile data
   */
  renderMap(tiles: TileData[]): void {
    this.clearMap();
    for (const tile of tiles) {
      this.drawHex(tile.coord, tile.terrain);
    }
  }

  /**
   * Clear all rendered content
   */
  clearMap(): void {
    this.mapContainer.removeChildren();
  }

  /**
   * Clear unit layer
   */
  clearUnits(): void {
    this.unitContainer.removeChildren();
  }

  /**
   * Center the camera on a specific hex
   */
  centerOnHex(coord: AxialCoord): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const scale = this.mapContainer.scale.x;
    this.mapContainer.x = this.app.screen.width / 2 - x * scale;
    this.mapContainer.y = this.app.screen.height / 2 - y * scale;
    this.unitContainer.x = this.mapContainer.x;
    this.unitContainer.y = this.mapContainer.y;
  }

  /**
   * Callback for hex selection
   */
  onHexSelected?: (coord: HexCoord) => void;

  /**
   * Get the currently selected hex
   */
  getSelectedHex(): HexCoord | null {
    return this.selectedHex;
  }

  /**
   * Get the currently hovered hex
   */
  getHoveredHex(): HexCoord | null {
    return this.hoveredHex;
  }

  /**
   * Destroy the renderer and clean up resources
   */
  destroy(): void {
    this.app.destroy(true);
  }

  /**
   * Get the PixiJS application instance
   */
  getApp(): Application {
    return this.app;
  }
}
