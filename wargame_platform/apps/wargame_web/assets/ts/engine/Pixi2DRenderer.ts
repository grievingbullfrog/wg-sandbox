import { Application, Container, Graphics, Text, TextStyle } from "pixi.js";
import { HexCoord, hexToPixel, pixelToHex, AxialCoord } from "../hex/coord";

/**
 * Terrain type enumeration matching backend terrain types
 */
export type TerrainType =
  | "clear"
  | "woods"
  | "forest"
  | "hills"
  | "mountains"
  | "marsh"
  | "swamp"
  | "water"
  | "river"
  | "lake"
  | "urban"
  | "village"
  | "road"
  | "railroad"
  | "bridge"
  | "ford"
  | "fortification"
  | "trench"
  | "bunker"
  | "airfield";

/**
 * Color mapping for terrain types (matching Elixir TerrainType colors)
 */
const TERRAIN_COLORS: Record<string, number> = {
  clear: 0x90ee90,       // Light green
  woods: 0x228b22,       // Forest green
  forest: 0x006400,      // Dark green
  hills: 0xdeb887,       // Burlywood
  mountains: 0x808080,   // Gray
  marsh: 0x9acd32,       // Yellow green
  swamp: 0x556b2f,       // Dark olive green
  water: 0x4169e1,       // Royal blue
  river: 0x4682b4,       // Steel blue
  lake: 0x1e90ff,        // Dodger blue
  urban: 0xa9a9a9,       // Dark gray
  village: 0xd2691e,     // Chocolate
  road: 0x8b4513,        // Saddle brown
  railroad: 0x2f4f4f,    // Dark slate gray
  bridge: 0x696969,      // Dim gray
  ford: 0x87ceeb,        // Sky blue
  fortification: 0x808000, // Olive
  trench: 0x6b4423,      // Brown
  bunker: 0x505050,      // Dark gray
  airfield: 0xd3d3d3,    // Light gray
};

/**
 * Edge feature types for hex edges
 */
export type EdgeFeature = "road" | "railroad" | "river" | "stream" | "bridge" | "ford";

/**
 * Overlay types for hex overlays
 */
export type OverlayType = "minefield" | "fortification" | "trench" | "wire" | "bunker";

/**
 * Tile data for rendering
 */
export interface TileData {
  coord: AxialCoord;
  terrain: TerrainType | string;
  elevation?: number;
  edges?: { [direction: number]: EdgeFeature[] };
  overlays?: OverlayType[];
  control?: string;
  victoryPoints?: number;
  name?: string;
}

/**
 * Configuration for the 2D renderer
 */
export interface Pixi2DRendererConfig {
  hexSize: number;
  backgroundColor: number;
  showGrid: boolean;
  showCoords: boolean;
  showElevation: boolean;
}

const DEFAULT_CONFIG: Pixi2DRendererConfig = {
  hexSize: 40,
  backgroundColor: 0x1a1a2e,
  showGrid: true,
  showCoords: false,
  showElevation: true,
};

/**
 * Highlight modes for hexes
 */
export type HighlightMode = "selected" | "hover" | "movable" | "attackable" | "path";

const HIGHLIGHT_COLORS: Record<HighlightMode, { color: number; alpha: number }> = {
  selected: { color: 0xffff00, alpha: 0.5 },
  hover: { color: 0xffffff, alpha: 0.3 },
  movable: { color: 0x00ff00, alpha: 0.3 },
  attackable: { color: 0xff0000, alpha: 0.3 },
  path: { color: 0x00ffff, alpha: 0.4 },
};

/**
 * 2D hex map renderer using PixiJS
 */
export class Pixi2DRenderer {
  private app: Application;
  private mapContainer: Container;
  private edgeContainer: Container;
  private overlayContainer: Container;
  private highlightContainer: Container;
  private unitContainer: Container;
  private uiContainer: Container;
  private labelContainer: Container;
  private config: Pixi2DRendererConfig;
  private selectedHex: HexCoord | null = null;
  private hoveredHex: HexCoord | null = null;
  private hexGraphics: Map<string, Graphics> = new Map();
  private highlightGraphics: Map<string, Graphics> = new Map();
  private isDragging = false;
  private dragStartPos = { x: 0, y: 0 };

  constructor(config: Partial<Pixi2DRendererConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.app = new Application();
    this.mapContainer = new Container();
    this.edgeContainer = new Container();
    this.overlayContainer = new Container();
    this.highlightContainer = new Container();
    this.unitContainer = new Container();
    this.uiContainer = new Container();
    this.labelContainer = new Container();
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

    // Set up container hierarchy (order matters for z-index)
    this.app.stage.addChild(this.mapContainer);
    this.app.stage.addChild(this.edgeContainer);
    this.app.stage.addChild(this.overlayContainer);
    this.app.stage.addChild(this.highlightContainer);
    this.app.stage.addChild(this.unitContainer);
    this.app.stage.addChild(this.labelContainer);
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
    let lastPosition = { x: 0, y: 0 };

    this.app.stage.on("pointerdown", (event) => {
      this.isDragging = false;
      this.dragStartPos = { x: event.global.x, y: event.global.y };
      lastPosition = { x: event.global.x, y: event.global.y };
    });

    this.app.stage.on("pointerup", (event) => {
      // Check if this was a click (not a drag)
      const dx = Math.abs(event.global.x - this.dragStartPos.x);
      const dy = Math.abs(event.global.y - this.dragStartPos.y);

      if (dx < 5 && dy < 5) {
        // This was a click, not a drag
        const worldPos = this.screenToWorld(event.global.x, event.global.y);
        const clickedHex = pixelToHex(worldPos.x, worldPos.y, this.config.hexSize);
        this.selectHex(clickedHex);
      }
      this.isDragging = false;
    });

    this.app.stage.on("pointerupoutside", () => {
      this.isDragging = false;
    });

    this.app.stage.on("pointermove", (event) => {
      const dx = event.global.x - lastPosition.x;
      const dy = event.global.y - lastPosition.y;

      // Check if we're dragging (moved more than threshold)
      const totalDx = Math.abs(event.global.x - this.dragStartPos.x);
      const totalDy = Math.abs(event.global.y - this.dragStartPos.y);

      if (event.buttons > 0 && (totalDx > 5 || totalDy > 5)) {
        this.isDragging = true;
        this.panCamera(dx, dy);
        lastPosition = { x: event.global.x, y: event.global.y };
      } else if (event.buttons === 0) {
        // Update hovered hex when not dragging
        const worldPos = this.screenToWorld(event.global.x, event.global.y);
        const newHoveredHex = pixelToHex(worldPos.x, worldPos.y, this.config.hexSize);

        if (!this.hoveredHex || !newHoveredHex.equals(this.hoveredHex)) {
          this.setHoveredHex(newHoveredHex);
        }
      }
    });

    // Zoom with mouse wheel
    this.app.canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      const scaleFactor = event.deltaY > 0 ? 0.9 : 1.1;
      this.zoomAt(event.offsetX, event.offsetY, scaleFactor);
    });
  }

  /**
   * Pan the camera by delta pixels
   */
  private panCamera(dx: number, dy: number): void {
    const containers = [
      this.mapContainer,
      this.edgeContainer,
      this.overlayContainer,
      this.highlightContainer,
      this.unitContainer,
      this.labelContainer,
    ];

    for (const container of containers) {
      container.x += dx;
      container.y += dy;
    }
  }

  /**
   * Zoom at a specific screen position
   */
  private zoomAt(screenX: number, screenY: number, scaleFactor: number): void {
    const minScale = 0.25;
    const maxScale = 4;
    const currentScale = this.mapContainer.scale.x;
    const newScale = Math.max(minScale, Math.min(maxScale, currentScale * scaleFactor));

    if (newScale === currentScale) return;

    const worldPosBefore = this.screenToWorld(screenX, screenY);

    const containers = [
      this.mapContainer,
      this.edgeContainer,
      this.overlayContainer,
      this.highlightContainer,
      this.unitContainer,
      this.labelContainer,
    ];

    for (const container of containers) {
      container.scale.set(newScale);
    }

    const worldPosAfter = this.screenToWorld(screenX, screenY);
    const dx = (worldPosAfter.x - worldPosBefore.x) * newScale;
    const dy = (worldPosAfter.y - worldPosBefore.y) * newScale;

    for (const container of containers) {
      container.x += dx;
      container.y += dy;
    }
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
   * Get the edge midpoints for a hex (for drawing edge features)
   */
  private getEdgeMidpoints(): Array<{ x: number; y: number }> {
    const midpoints: Array<{ x: number; y: number }> = [];
    const points = this.getHexPoints(0, 0);

    for (let i = 0; i < 6; i++) {
      const x1 = points[i * 2];
      const y1 = points[i * 2 + 1];
      const x2 = points[((i + 1) % 6) * 2];
      const y2 = points[((i + 1) % 6) * 2 + 1];
      midpoints.push({ x: (x1 + x2) / 2, y: (y1 + y2) / 2 });
    }

    return midpoints;
  }

  /**
   * Draw a single hex tile
   */
  drawHex(tile: TileData): Graphics {
    const { x, y } = hexToPixel(tile.coord, this.config.hexSize);
    const hex = new Graphics();
    const terrain = tile.terrain as string;
    const color = TERRAIN_COLORS[terrain] ?? TERRAIN_COLORS.clear;

    // Draw filled hex
    hex.poly(this.getHexPoints(0, 0));
    hex.fill(color);

    // Draw grid outline
    if (this.config.showGrid) {
      hex.stroke({ width: 1, color: 0x000000, alpha: 0.4 });
    }

    // Draw elevation shading
    if (this.config.showElevation && tile.elevation && tile.elevation > 0) {
      const shade = Math.min(tile.elevation * 0.1, 0.3);
      hex.poly(this.getHexPoints(0, 0));
      hex.fill({ color: 0xffffff, alpha: shade });
    }

    hex.x = x;
    hex.y = y;

    // Store for later reference
    const key = `${tile.coord.q},${tile.coord.r}`;
    this.hexGraphics.set(key, hex);

    this.mapContainer.addChild(hex);

    // Draw edge features
    if (tile.edges) {
      this.drawEdgeFeatures(tile.coord, tile.edges);
    }

    // Draw overlays
    if (tile.overlays && tile.overlays.length > 0) {
      this.drawOverlays(tile.coord, tile.overlays);
    }

    // Draw coordinate labels
    if (this.config.showCoords) {
      this.drawCoordLabel(tile.coord);
    }

    // Draw victory point indicator
    if (tile.victoryPoints && tile.victoryPoints > 0) {
      this.drawVictoryPointIndicator(tile.coord, tile.victoryPoints);
    }

    // Draw control indicator
    if (tile.control) {
      this.drawControlIndicator(tile.coord, tile.control);
    }

    return hex;
  }

  /**
   * Draw edge features (roads, rivers, etc.)
   */
  private drawEdgeFeatures(coord: AxialCoord, edges: { [direction: number]: EdgeFeature[] }): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const midpoints = this.getEdgeMidpoints();

    for (const [dirStr, features] of Object.entries(edges)) {
      const direction = parseInt(dirStr);
      if (direction < 0 || direction > 5) continue;

      const midpoint = midpoints[direction];

      for (const feature of features) {
        const edgeGraphic = new Graphics();
        edgeGraphic.x = x;
        edgeGraphic.y = y;

        switch (feature) {
          case "road":
            edgeGraphic.moveTo(0, 0);
            edgeGraphic.lineTo(midpoint.x, midpoint.y);
            edgeGraphic.stroke({ width: 4, color: 0x8b4513, alpha: 0.8 });
            break;

          case "railroad":
            edgeGraphic.moveTo(0, 0);
            edgeGraphic.lineTo(midpoint.x, midpoint.y);
            edgeGraphic.stroke({ width: 2, color: 0x333333, alpha: 0.9 });
            // Railroad ties
            const rdx = midpoint.x / 5;
            const rdy = midpoint.y / 5;
            for (let i = 1; i < 5; i++) {
              const px = rdx * i;
              const py = rdy * i;
              const perpX = -rdy * 0.3;
              const perpY = rdx * 0.3;
              edgeGraphic.moveTo(px - perpX, py - perpY);
              edgeGraphic.lineTo(px + perpX, py + perpY);
              edgeGraphic.stroke({ width: 2, color: 0x666666 });
            }
            break;

          case "river":
            edgeGraphic.moveTo(0, 0);
            edgeGraphic.lineTo(midpoint.x, midpoint.y);
            edgeGraphic.stroke({ width: 6, color: 0x4682b4, alpha: 0.9 });
            break;

          case "stream":
            edgeGraphic.moveTo(0, 0);
            edgeGraphic.lineTo(midpoint.x, midpoint.y);
            edgeGraphic.stroke({ width: 3, color: 0x87ceeb, alpha: 0.8 });
            break;

          case "bridge":
            edgeGraphic.rect(midpoint.x - 5, midpoint.y - 3, 10, 6);
            edgeGraphic.fill(0x8b4513);
            edgeGraphic.stroke({ width: 1, color: 0x000000 });
            break;

          case "ford":
            // Dashed blue line
            edgeGraphic.moveTo(0, 0);
            edgeGraphic.lineTo(midpoint.x, midpoint.y);
            edgeGraphic.stroke({ width: 4, color: 0x87ceeb, alpha: 0.7 });
            break;
        }

        this.edgeContainer.addChild(edgeGraphic);
      }
    }
  }

  /**
   * Draw overlays (minefields, fortifications, etc.)
   */
  private drawOverlays(coord: AxialCoord, overlays: OverlayType[]): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const size = this.config.hexSize * 0.3;

    for (let i = 0; i < overlays.length; i++) {
      const overlay = overlays[i];
      const offsetX = (i % 2) * size * 0.8 - size * 0.4;
      const offsetY = Math.floor(i / 2) * size * 0.8 - size * 0.4;

      const overlayGraphic = new Graphics();
      overlayGraphic.x = x + offsetX;
      overlayGraphic.y = y + offsetY;

      switch (overlay) {
        case "minefield":
          // Skull/danger symbol
          overlayGraphic.circle(0, 0, size * 0.4);
          overlayGraphic.fill(0xff0000);
          overlayGraphic.stroke({ width: 1, color: 0x000000 });
          break;

        case "fortification":
          // Star shape
          overlayGraphic.star(0, 0, 5, size * 0.4, size * 0.2);
          overlayGraphic.fill(0x808000);
          overlayGraphic.stroke({ width: 1, color: 0x000000 });
          break;

        case "trench":
          // Zigzag line
          overlayGraphic.moveTo(-size * 0.3, -size * 0.2);
          overlayGraphic.lineTo(-size * 0.1, size * 0.2);
          overlayGraphic.lineTo(size * 0.1, -size * 0.2);
          overlayGraphic.lineTo(size * 0.3, size * 0.2);
          overlayGraphic.stroke({ width: 2, color: 0x6b4423 });
          break;

        case "wire":
          // X pattern
          overlayGraphic.moveTo(-size * 0.3, -size * 0.3);
          overlayGraphic.lineTo(size * 0.3, size * 0.3);
          overlayGraphic.moveTo(-size * 0.3, size * 0.3);
          overlayGraphic.lineTo(size * 0.3, -size * 0.3);
          overlayGraphic.stroke({ width: 1, color: 0x666666 });
          break;

        case "bunker":
          // Square
          overlayGraphic.rect(-size * 0.3, -size * 0.2, size * 0.6, size * 0.4);
          overlayGraphic.fill(0x505050);
          overlayGraphic.stroke({ width: 1, color: 0x000000 });
          break;
      }

      this.overlayContainer.addChild(overlayGraphic);
    }
  }

  /**
   * Draw coordinate label
   */
  private drawCoordLabel(coord: AxialCoord): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);

    const style = new TextStyle({
      fontSize: 10,
      fill: 0x000000,
      fontFamily: "monospace",
    });

    const label = new Text({ text: `${coord.q},${coord.r}`, style });
    label.anchor.set(0.5);
    label.x = x;
    label.y = y + this.config.hexSize * 0.6;

    this.labelContainer.addChild(label);
  }

  /**
   * Draw victory point indicator
   */
  private drawVictoryPointIndicator(coord: AxialCoord, vp: number): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const size = this.config.hexSize * 0.25;

    const indicator = new Graphics();
    indicator.star(x, y - this.config.hexSize * 0.4, 5, size, size * 0.5);
    indicator.fill(0xffd700);
    indicator.stroke({ width: 1, color: 0x000000 });

    if (vp > 1) {
      const style = new TextStyle({
        fontSize: 8,
        fill: 0x000000,
        fontWeight: "bold",
      });
      const label = new Text({ text: vp.toString(), style });
      label.anchor.set(0.5);
      label.x = x;
      label.y = y - this.config.hexSize * 0.4;
      this.labelContainer.addChild(label);
    }

    this.overlayContainer.addChild(indicator);
  }

  /**
   * Draw control indicator
   */
  private drawControlIndicator(coord: AxialCoord, control: string): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);

    // Small flag in corner
    const flag = new Graphics();
    const flagX = x + this.config.hexSize * 0.4;
    const flagY = y - this.config.hexSize * 0.4;

    // Color based on control
    const flagColor = control === "german" ? 0x333333 : control === "soviet" ? 0xcc0000 : 0x0066cc;

    flag.moveTo(flagX, flagY);
    flag.lineTo(flagX, flagY + 10);
    flag.stroke({ width: 1, color: 0x000000 });

    flag.moveTo(flagX, flagY);
    flag.lineTo(flagX + 8, flagY + 3);
    flag.lineTo(flagX, flagY + 6);
    flag.fill(flagColor);

    this.overlayContainer.addChild(flag);
  }

  /**
   * Highlight a hex
   */
  highlightHex(coord: AxialCoord, mode: HighlightMode): void {
    const key = `${coord.q},${coord.r}`;

    // Remove existing highlight for this hex
    this.clearHighlight(coord);

    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const highlight = new Graphics();

    const { color, alpha } = HIGHLIGHT_COLORS[mode];

    highlight.poly(this.getHexPoints(0, 0));
    highlight.fill({ color, alpha });

    if (mode === "selected") {
      highlight.poly(this.getHexPoints(0, 0));
      highlight.stroke({ width: 3, color: 0xffff00, alpha: 1 });
    }

    highlight.x = x;
    highlight.y = y;

    this.highlightGraphics.set(key, highlight);
    this.highlightContainer.addChild(highlight);
  }

  /**
   * Highlight multiple hexes
   */
  highlightHexes(coords: AxialCoord[], mode: HighlightMode): void {
    for (const coord of coords) {
      this.highlightHex(coord, mode);
    }
  }

  /**
   * Clear highlight from a specific hex
   */
  clearHighlight(coord: AxialCoord): void {
    const key = `${coord.q},${coord.r}`;
    const highlight = this.highlightGraphics.get(key);
    if (highlight) {
      this.highlightContainer.removeChild(highlight);
      highlight.destroy();
      this.highlightGraphics.delete(key);
    }
  }

  /**
   * Clear all highlights
   */
  clearAllHighlights(): void {
    this.highlightContainer.removeChildren();
    for (const highlight of this.highlightGraphics.values()) {
      highlight.destroy();
    }
    this.highlightGraphics.clear();
  }

  /**
   * Select a hex
   */
  selectHex(coord: HexCoord): void {
    // Clear previous selection highlight
    if (this.selectedHex) {
      this.clearHighlight(this.selectedHex);
    }

    this.selectedHex = coord;
    this.highlightHex(coord, "selected");
    this.onHexSelected?.(coord);
  }

  /**
   * Set the hovered hex
   */
  private setHoveredHex(coord: HexCoord): void {
    // Clear previous hover highlight (but not if it's selected)
    if (this.hoveredHex && (!this.selectedHex || !this.hoveredHex.equals(this.selectedHex))) {
      this.clearHighlight(this.hoveredHex);
    }

    this.hoveredHex = coord;

    // Don't show hover on selected hex
    if (!this.selectedHex || !coord.equals(this.selectedHex)) {
      this.highlightHex(coord, "hover");
    }

    this.onHexHovered?.(coord);
  }

  /**
   * Render a complete map from tile data
   */
  renderMap(tiles: TileData[]): void {
    this.clearMap();
    for (const tile of tiles) {
      this.drawHex(tile);
    }
  }

  /**
   * Clear all rendered content
   */
  clearMap(): void {
    this.mapContainer.removeChildren();
    this.edgeContainer.removeChildren();
    this.overlayContainer.removeChildren();
    this.labelContainer.removeChildren();
    this.hexGraphics.clear();
    this.clearAllHighlights();
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
    const targetX = this.app.screen.width / 2 - x * scale;
    const targetY = this.app.screen.height / 2 - y * scale;

    const containers = [
      this.mapContainer,
      this.edgeContainer,
      this.overlayContainer,
      this.highlightContainer,
      this.unitContainer,
      this.labelContainer,
    ];

    for (const container of containers) {
      container.x = targetX;
      container.y = targetY;
    }
  }

  /**
   * Center the camera on the map
   */
  centerOnMap(width: number, height: number): void {
    const centerQ = Math.floor(width / 2);
    const centerR = Math.floor(height / 2);
    this.centerOnHex({ q: centerQ, r: centerR });
  }

  /**
   * Callback for hex selection
   */
  onHexSelected?: (coord: HexCoord) => void;

  /**
   * Callback for hex hover
   */
  onHexHovered?: (coord: HexCoord) => void;

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
   * Update configuration
   */
  setConfig(config: Partial<Pixi2DRendererConfig>): void {
    this.config = { ...this.config, ...config };
  }

  /**
   * Get current configuration
   */
  getConfig(): Pixi2DRendererConfig {
    return { ...this.config };
  }

  /**
   * Get the hex size
   */
  getHexSize(): number {
    return this.config.hexSize;
  }

  /**
   * Set the hex size and re-render
   */
  setHexSize(size: number): void {
    this.config.hexSize = size;
  }

  /**
   * Destroy the renderer and clean up resources
   */
  destroy(): void {
    this.clearMap();
    this.clearUnits();
    this.app.destroy(true);
  }

  /**
   * Get the PixiJS application instance
   */
  getApp(): Application {
    return this.app;
  }

  /**
   * Get the unit container for adding unit graphics
   */
  getUnitContainer(): Container {
    return this.unitContainer;
  }

  /**
   * Get the UI container for adding UI elements
   */
  getUIContainer(): Container {
    return this.uiContainer;
  }
}
