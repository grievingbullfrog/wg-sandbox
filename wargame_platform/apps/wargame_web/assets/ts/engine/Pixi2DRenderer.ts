import { Application, Assets, Container, Graphics, Sprite, Text, TextStyle, Texture } from "pixi.js";
import { HexCoord, hexToPixel, pixelToHex, AxialCoord } from "../hex/coord";

/**
 * Terrain type enumeration matching backend terrain types
 * These must match WargameCore.Terrain.TerrainType definitions
 */
export type TerrainType =
  | "clear"
  | "forest_pine"
  | "forest_deciduous"
  | "marsh"
  | "orchard"
  | "light_urban"
  | "heavy_urban"
  | "industrial"
  | "desert"
  | "semi_arid"
  | "tundra"
  | "arctic"
  | "freshwater_lake"
  | "frozen_lake"
  | "ocean"
  | "frozen_ocean";

/**
 * Color mapping for terrain types (matching Elixir TerrainType colors exactly)
 */
const TERRAIN_COLORS: Record<string, number> = {
  clear: 0x90ee90,           // Light green
  forest_pine: 0x228b22,     // Forest green
  forest_deciduous: 0x32cd32, // Lime green
  marsh: 0x6b8e23,           // Olive drab
  orchard: 0x9acd32,         // Yellow-green
  light_urban: 0xa9a9a9,     // Dark gray
  heavy_urban: 0x696969,     // Dim gray
  industrial: 0x505050,      // Dark gray
  desert: 0xf4a460,          // Sandy brown
  semi_arid: 0xc2b280,       // Khaki
  tundra: 0x8b8682,          // Gray-brown
  arctic: 0xe8e8e8,          // Off-white
  freshwater_lake: 0x4169e1, // Royal blue
  frozen_lake: 0xb0e0e6,     // Powder blue
  ocean: 0x000080,           // Navy
  frozen_ocean: 0xadd8e6,    // Light blue
};

/**
 * Edge feature types for hex edges (water features only)
 */
export type EdgeFeature = "small_stream" | "large_stream" | "small_river" | "large_river";

/**
 * Transport segment types
 */
export type TransportSegmentType =
  | "trail"
  | "small_unpaved_road"
  | "large_unpaved_road"
  | "small_paved_road"
  | "large_paved_road"
  | "railroad"
  | "double_track_railroad"
  | "triple_track_railroad"
  | "runway";

/**
 * Transport segment data
 */
export interface TransportSegment {
  type: TransportSegmentType;
  entry_edges: number[];  // 0-5, using new edge numbering (0=N, clockwise)
  exit_edges: number[];   // 0-5
}

/**
 * Overlay types for hex overlays
 */
export type OverlayType = "minefield" | "fortification" | "trench" | "wire" | "bunker";

/**
 * Objective data for victory condition hexes
 */
export interface Objective {
  name: string | null;
  force: string | null;  // e.g., "allied", "axis", "neutral"
}

/**
 * Modifier keys state for click events
 */
export interface HexClickModifiers {
  shift: boolean;
  ctrl: boolean;
  alt: boolean;
}

/**
 * Tile data for rendering
 */
export interface TileData {
  coord: AxialCoord;
  terrain: TerrainType | string;
  elevation?: number;
  edges?: { [direction: number]: EdgeFeature[] };
  overlays?: OverlayType[];
  transportSegments?: TransportSegment[];
  control?: string;
  victoryPoints?: number;
  name?: string;
  objective?: Objective | null;
}

/**
 * Configuration for the 2D renderer
 */
/**
 * Overlay display modes for showing per-tile information
 */
export type TileOverlayMode = "none" | "elevation_relative" | "elevation_absolute" | "terrain" | "control";

export interface Pixi2DRendererConfig {
  hexSize: number;
  backgroundColor: number;
  showGrid: boolean;
  showCoords: boolean;
  tileOverlay: TileOverlayMode;
  elevationToolActive: boolean;
  baseElevation: number;
  satelliteOpacity: number;
  showSatellite: boolean;
}

const DEFAULT_CONFIG: Pixi2DRendererConfig = {
  hexSize: 40,
  backgroundColor: 0x1a1a2e,
  showGrid: true,
  showCoords: false,
  tileOverlay: "none",
  elevationToolActive: false,
  baseElevation: 0,
  satelliteOpacity: 0.5,
  showSatellite: false,
};

/**
 * Satellite tile data received from backend
 */
export interface SatelliteTile {
  url: string;
  x: number;
  y: number;
  north: number;
  south: number;
  west: number;
  east: number;
}

/**
 * Satellite data structure from backend
 */
export interface SatelliteData {
  zoom: number;
  tiles: SatelliteTile[];
  bounds: {
    north: number;
    south: number;
    west: number;
    east: number;
  };
  center: {
    lat: number;
    lng: number;
  };
  map_extent_meters: {
    width: number;
    height: number;
  };
}

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
  private satelliteContainer: Container;
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
  private tileDataMap: Map<string, TileData> = new Map();
  // Track auxiliary display objects (edges, overlays, transport, labels) per hex for proper cleanup
  private auxGraphics: Map<string, Container[]> = new Map();
  private elevationPopup: Text | null = null;
  private isDragging = false;
  private dragStartPos = { x: 0, y: 0 };
  private mapWidth = 0;
  private mapHeight = 0;
  // Satellite background state
  private satelliteData: SatelliteData | null = null;
  private satelliteSprites: Sprite[] = [];
  private satelliteMask: Graphics | null = null;

  constructor(config: Partial<Pixi2DRendererConfig> = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.app = new Application();
    this.satelliteContainer = new Container();
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
    // Satellite overlays on top of map with adjustable opacity
    this.app.stage.addChild(this.mapContainer);
    this.app.stage.addChild(this.satelliteContainer);  // Above map, below edges
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
        // Pass modifier keys from the original event
        const modifiers = {
          shift: event.shiftKey ?? false,
          ctrl: event.ctrlKey ?? false,
          alt: event.altKey ?? false,
        };
        this.selectHex(clickedHex, modifiers);
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
    // Use normalized zoom for smoother trackpad scrolling
    this.app.canvas.addEventListener("wheel", (event) => {
      event.preventDefault();
      // Normalize deltaY: clamp to reasonable range and scale down
      // Trackpads often send many small delta values, mice send larger ones
      const normalizedDelta = Math.sign(event.deltaY) * Math.min(Math.abs(event.deltaY), 100);
      const zoomIntensity = 0.002; // Reduced from 0.1 for smoother zooming
      const scaleFactor = 1 - normalizedDelta * zoomIntensity;
      this.zoomAt(event.offsetX, event.offsetY, scaleFactor);
    });
  }

  /**
   * Pan the camera by delta pixels
   */
  private panCamera(dx: number, dy: number): void {
    const containers = [
      this.satelliteContainer,
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
      this.satelliteContainer,
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

    hex.x = x;
    hex.y = y;

    // Store for later reference
    const key = `${tile.coord.q},${tile.coord.r}`;
    this.hexGraphics.set(key, hex);
    this.tileDataMap.set(key, tile);

    this.mapContainer.addChild(hex);

    // Draw edge features
    if (tile.edges) {
      this.drawEdgeFeatures(tile.coord, tile.edges);
    }

    // Draw overlays
    if (tile.overlays && tile.overlays.length > 0) {
      this.drawOverlays(tile.coord, tile.overlays);
    }

    // Draw transport segments
    if (tile.transportSegments && tile.transportSegments.length > 0) {
      this.drawTransportSegments(tile.coord, tile.transportSegments);
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

    // Draw objective indicator
    if (tile.objective) {
      this.drawObjectiveIndicator(tile.coord, tile.objective, tile.victoryPoints || 0);
    }

    // Draw tile overlay text based on selected overlay mode
    if (this.config.tileOverlay !== "none") {
      this.drawTileOverlay(tile);
    }

    return hex;
  }

  /**
   * Draw tile overlay text (elevation, terrain name, etc.)
   */
  private drawTileOverlay(tile: TileData): void {
    const { x, y } = hexToPixel(tile.coord, this.config.hexSize);
    let text = "";

    switch (this.config.tileOverlay) {
      case "elevation_relative":
        const elevation = tile.elevation ?? 0;
        text = elevation === 0 ? "0" : (elevation > 0 ? `+${elevation}` : `${elevation}`);
        break;
      case "elevation_absolute":
        const absElevation = this.config.baseElevation + (tile.elevation ?? 0);
        text = `${absElevation}`;
        break;
      case "terrain":
        text = (tile.terrain as string).replace("_", "\n");
        break;
      case "control":
        text = tile.control ?? "";
        break;
      default:
        return;
    }

    if (!text) return;

    // Get terrain color for contrast calculation
    const terrain = (tile.terrain as string) ?? "clear";
    const terrainColor = TERRAIN_COLORS[terrain] ?? TERRAIN_COLORS.clear;
    const textColor = this.getContrastColor(terrainColor);

    const fontSize = this.config.hexSize * 0.35;
    const style = new TextStyle({
      fontFamily: "Arial",
      fontSize: fontSize,
      fontWeight: "bold",
      fill: textColor,
      align: "center",
    });

    const label = new Text({ text, style });
    label.anchor.set(0.5, 0.5);
    label.x = x;
    label.y = y;

    this.labelContainer.addChild(label);
    this.trackAuxGraphic(tile.coord, label);
  }

  /**
   * Get the vertices of a hex edge (the two corner points that form the edge)
   * Edge numbering: 0=N, 1=NE, 2=SE, 3=S, 4=SW, 5=NW
   *
   * For a pointy-top hex, vertices are numbered 0-5 starting at right (3 o'clock) going clockwise:
   *   Vertex 0: Right (3 o'clock)
   *   Vertex 1: Bottom-right (5 o'clock)
   *   Vertex 2: Bottom-left (7 o'clock)
   *   Vertex 3: Left (9 o'clock)
   *   Vertex 4: Top-left (11 o'clock)
   *   Vertex 5: Top-right (1 o'clock)
   *
   * Edge to vertex mapping (edge connects vertex i to vertex i+1):
   *   Edge 0 (N):  vertices 5 and 0 (top edge)
   *   Edge 1 (NE): vertices 0 and 1 (top-right edge)
   *   Edge 2 (SE): vertices 1 and 2 (bottom-right edge)
   *   Edge 3 (S):  vertices 2 and 3 (bottom edge)
   *   Edge 4 (SW): vertices 3 and 4 (bottom-left edge)
   *   Edge 5 (NW): vertices 4 and 5 (top-left edge)
   */
  private getEdgeVertices(edge: number): { v1: { x: number; y: number }; v2: { x: number; y: number } } {
    const points = this.getHexPoints(0, 0);

    // Map edge number to vertex indices
    // Edge 0 (N) connects vertices 5 and 0
    // Edge 1 (NE) connects vertices 0 and 1
    // etc.
    const vertexMap: [number, number][] = [
      [5, 0], // Edge 0: N
      [0, 1], // Edge 1: NE
      [1, 2], // Edge 2: SE
      [2, 3], // Edge 3: S
      [3, 4], // Edge 4: SW
      [4, 5], // Edge 5: NW
    ];

    const [v1Idx, v2Idx] = vertexMap[edge];

    return {
      v1: { x: points[v1Idx * 2], y: points[v1Idx * 2 + 1] },
      v2: { x: points[v2Idx * 2], y: points[v2Idx * 2 + 1] },
    };
  }

  /**
   * Track an auxiliary display object (edge, overlay, transport, label) for a hex
   * These are cleaned up when the hex is updated or removed
   */
  private trackAuxGraphic(coord: AxialCoord, displayObject: Container): void {
    const key = `${coord.q},${coord.r}`;
    const existing = this.auxGraphics.get(key) || [];
    existing.push(displayObject);
    this.auxGraphics.set(key, existing);
  }

  /**
   * Remove all auxiliary graphics for a hex
   */
  private clearAuxGraphics(coord: AxialCoord): void {
    const key = `${coord.q},${coord.r}`;
    const objects = this.auxGraphics.get(key);
    if (objects) {
      for (const obj of objects) {
        obj.parent?.removeChild(obj);
        obj.destroy();
      }
      this.auxGraphics.delete(key);
    }
  }

  /**
   * Draw edge features (water features: streams, rivers)
   * Edge features are drawn along the hex edge (between vertices), not from center to edge.
   */
  private drawEdgeFeatures(coord: AxialCoord, edges: { [direction: number]: EdgeFeature[] }): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);

    for (const [dirStr, features] of Object.entries(edges)) {
      const direction = parseInt(dirStr);
      if (direction < 0 || direction > 5) continue;

      const { v1, v2 } = this.getEdgeVertices(direction);

      for (const feature of features) {
        const edgeGraphic = new Graphics();
        edgeGraphic.x = x;
        edgeGraphic.y = y;

        switch (feature) {
          case "small_stream":
            // Light blue thin line along edge
            edgeGraphic.moveTo(v1.x, v1.y);
            edgeGraphic.lineTo(v2.x, v2.y);
            edgeGraphic.stroke({ width: 4, color: 0x87ceeb, alpha: 0.8 });
            break;

          case "large_stream":
            // Light blue medium line along edge
            edgeGraphic.moveTo(v1.x, v1.y);
            edgeGraphic.lineTo(v2.x, v2.y);
            edgeGraphic.stroke({ width: 8, color: 0x87ceeb, alpha: 0.9 });
            break;

          case "small_river":
            // Steel blue line along edge
            edgeGraphic.moveTo(v1.x, v1.y);
            edgeGraphic.lineTo(v2.x, v2.y);
            edgeGraphic.stroke({ width: 10, color: 0x4682b4, alpha: 0.9 });
            break;

          case "large_river":
            // Wide steel blue line along edge
            edgeGraphic.moveTo(v1.x, v1.y);
            edgeGraphic.lineTo(v2.x, v2.y);
            edgeGraphic.stroke({ width: 16, color: 0x4682b4, alpha: 1 });
            break;
        }

        this.edgeContainer.addChild(edgeGraphic);
        this.trackAuxGraphic(coord, edgeGraphic);
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
      this.trackAuxGraphic(coord, overlayGraphic);
    }
  }

  /**
   * Transport segment styling configuration
   * Colors and widths designed for clear visual distinction:
   * - Trails: Brown dotted (2px) - hiking paths
   * - Unpaved roads: Tan/sand color (4px small, 6px large)
   * - Paved roads: Dark gray (5px small, 8px large)
   * - Railroads: Black with ties (3px single, 5px double, 7px triple)
   * - Runway: Very wide dark gray (10px)
   */
  private getTransportStyle(type: TransportSegmentType): { color: number; width: number; dashed: boolean } {
    switch (type) {
      case "trail":
        return { color: 0x8b4513, width: 2, dashed: true };  // Brown dotted
      case "small_unpaved_road":
        return { color: 0xd2a679, width: 4, dashed: false };  // Tan/sand
      case "large_unpaved_road":
        return { color: 0xc49a6c, width: 6, dashed: false };  // Darker tan
      case "small_paved_road":
        return { color: 0x505050, width: 5, dashed: false };  // Dark gray
      case "large_paved_road":
        return { color: 0x3a3a3a, width: 8, dashed: false };  // Darker gray
      case "railroad":
        return { color: 0x1a1a1a, width: 3, dashed: false };  // Near black
      case "double_track_railroad":
        return { color: 0x1a1a1a, width: 5, dashed: false };  // Near black, wider
      case "triple_track_railroad":
        return { color: 0x1a1a1a, width: 7, dashed: false };  // Near black, widest
      case "runway":
        return { color: 0x404040, width: 10, dashed: false };  // Gray, very wide
      default:
        return { color: 0x888888, width: 2, dashed: false };
    }
  }

  /**
   * Draw transport segments (roads, railroads, etc.)
   * Segments connect entry edges through the center to exit edges
   */
  private drawTransportSegments(coord: AxialCoord, segments: TransportSegment[]): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const midpoints = this.getEdgeMidpoints();

    for (const segment of segments) {
      const style = this.getTransportStyle(segment.type);
      const graphic = new Graphics();
      graphic.x = x;
      graphic.y = y;

      // Collect all edge points for this segment
      const allEdges = [...segment.entry_edges, ...segment.exit_edges];

      if (allEdges.length === 0) {
        continue;
      }

      if (allEdges.length === 1) {
        // Dead-end: draw from edge to center
        const edge = allEdges[0];
        if (edge >= 0 && edge <= 5) {
          const mp = midpoints[edge];
          graphic.moveTo(mp.x, mp.y);
          graphic.lineTo(0, 0);
          graphic.stroke({ width: style.width, color: style.color, alpha: 0.9 });
        }
      } else {
        // Multiple edges: connect all edges through the center
        for (const edge of allEdges) {
          if (edge >= 0 && edge <= 5) {
            const mp = midpoints[edge];
            graphic.moveTo(0, 0);
            graphic.lineTo(mp.x, mp.y);
            graphic.stroke({ width: style.width, color: style.color, alpha: 0.9 });
          }
        }

        // Draw center hub for junctions (3+ edges)
        if (allEdges.length >= 3) {
          graphic.circle(0, 0, style.width * 1.5);
          graphic.fill({ color: style.color, alpha: 0.9 });
        }
      }

      // Add railroad ties for all railroad types
      if (segment.type === "railroad" || segment.type === "double_track_railroad" || segment.type === "triple_track_railroad") {
        const tieWidth = segment.type === "triple_track_railroad" ? 3 :
                         segment.type === "double_track_railroad" ? 2.5 : 2;
        const tieScale = segment.type === "triple_track_railroad" ? 0.6 :
                         segment.type === "double_track_railroad" ? 0.5 : 0.4;
        for (const edge of allEdges) {
          if (edge >= 0 && edge <= 5) {
            const mp = midpoints[edge];
            const dx = mp.x / 5;
            const dy = mp.y / 5;
            for (let i = 1; i < 5; i++) {
              const px = dx * i;
              const py = dy * i;
              const perpX = -dy * tieScale;
              const perpY = dx * tieScale;
              graphic.moveTo(px - perpX, py - perpY);
              graphic.lineTo(px + perpX, py + perpY);
              graphic.stroke({ width: tieWidth, color: 0x6b4423 });  // Brown ties
            }
          }
        }
      }

      // Add runway markings (white center line)
      if (segment.type === "runway") {
        for (const edge of allEdges) {
          if (edge >= 0 && edge <= 5) {
            const mp = midpoints[edge];
            graphic.moveTo(0, 0);
            graphic.lineTo(mp.x, mp.y);
            graphic.stroke({ width: 1, color: 0xffffff, alpha: 0.9 });
          }
        }
      }

      this.overlayContainer.addChild(graphic);
      this.trackAuxGraphic(coord, graphic);
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
    this.trackAuxGraphic(coord, label);
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
      this.trackAuxGraphic(coord, label);
    }

    this.overlayContainer.addChild(indicator);
    this.trackAuxGraphic(coord, indicator);
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
    this.trackAuxGraphic(coord, flag);
  }

  /**
   * Draw objective indicator (star icon with name label)
   */
  private drawObjectiveIndicator(coord: AxialCoord, objective: Objective, victoryPoints: number): void {
    const { x, y } = hexToPixel(coord, this.config.hexSize);
    const graphics = new Graphics();

    // Color based on force
    const forceColor = this.getForceColor(objective.force);

    // Draw star in center of hex
    const starSize = this.config.hexSize * 0.25;
    this.drawStar(graphics, x, y - 5, starSize, forceColor);

    this.overlayContainer.addChild(graphics);
    this.trackAuxGraphic(coord, graphics);

    // Draw objective name if present
    if (objective.name) {
      const labelStyle = new TextStyle({
        fontSize: 9,
        fill: 0xffffff,
        stroke: { color: 0x000000, width: 2 },
        fontWeight: "bold",
      });

      const label = new Text({ text: objective.name, style: labelStyle });
      label.anchor.set(0.5, 0);
      label.x = x;
      label.y = y + 5;

      this.overlayContainer.addChild(label);
      this.trackAuxGraphic(coord, label);
    }
  }

  /**
   * Draw a 5-pointed star
   */
  private drawStar(graphics: Graphics, cx: number, cy: number, size: number, color: number): void {
    const points = 5;
    const outerRadius = size;
    const innerRadius = size * 0.4;
    const angleStep = Math.PI / points;

    graphics.moveTo(
      cx + outerRadius * Math.cos(-Math.PI / 2),
      cy + outerRadius * Math.sin(-Math.PI / 2)
    );

    for (let i = 0; i < points * 2; i++) {
      const radius = i % 2 === 0 ? outerRadius : innerRadius;
      const angle = -Math.PI / 2 + angleStep * i;
      graphics.lineTo(
        cx + radius * Math.cos(angle),
        cy + radius * Math.sin(angle)
      );
    }

    graphics.closePath();
    graphics.fill(color);
    graphics.stroke({ width: 1, color: 0x000000 });
  }

  /**
   * Get color for a force
   */
  private getForceColor(force: string | null): number {
    if (!force) return 0xffd700; // Gold for neutral

    switch (force.toLowerCase()) {
      case "allied":
      case "american":
      case "british":
      case "french":
        return 0x0066cc; // Blue
      case "axis":
      case "german":
      case "italian":
        return 0x333333; // Dark gray
      case "soviet":
      case "russian":
        return 0xcc0000; // Red
      case "japanese":
        return 0xff6600; // Orange
      default:
        return 0xffd700; // Gold for unknown
    }
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
   * Modifier keys state for click events
   */
  static readonly DEFAULT_MODIFIERS: HexClickModifiers = { shift: false, ctrl: false, alt: false };

  /**
   * Select a hex
   */
  selectHex(coord: HexCoord, modifiers: HexClickModifiers = Pixi2DRenderer.DEFAULT_MODIFIERS): void {
    // Ignore clicks outside map bounds
    if (!this.isInBounds(coord)) {
      return;
    }

    // Clear previous selection highlight
    if (this.selectedHex) {
      this.clearHighlight(this.selectedHex);
    }

    // Clear hover highlight from previously hovered hex if it's different from the new selection
    // This prevents stale hover highlights from persisting after selection changes
    if (this.hoveredHex && !this.hoveredHex.equals(coord)) {
      this.clearHighlight(this.hoveredHex);
    }

    this.selectedHex = coord;
    this.hoveredHex = coord; // Update hover to match selection
    this.highlightHex(coord, "selected");
    this.onHexSelected?.(coord, modifiers);
  }

  /**
   * Set the hovered hex
   */
  private setHoveredHex(coord: HexCoord): void {
    // Ignore hover outside map bounds
    if (!this.isInBounds(coord)) {
      // Clear previous hover if we moved outside bounds
      if (this.hoveredHex && (!this.selectedHex || !this.hoveredHex.equals(this.selectedHex))) {
        this.clearHighlight(this.hoveredHex);
      }
      this.hoveredHex = null;
      this.hideElevationPopup();
      return;
    }

    // Clear previous hover highlight (but not if it's selected)
    if (this.hoveredHex && (!this.selectedHex || !this.hoveredHex.equals(this.selectedHex))) {
      this.clearHighlight(this.hoveredHex);
    }

    this.hoveredHex = coord;

    // Don't show hover on selected hex
    if (!this.selectedHex || !coord.equals(this.selectedHex)) {
      this.highlightHex(coord, "hover");
    }

    // Show elevation popup when elevation tool is active
    if (this.config.elevationToolActive) {
      this.showElevationPopup(coord);
    } else {
      this.hideElevationPopup();
    }

    this.onHexHovered?.(coord);
  }

  /**
   * Show elevation popup on the hovered hex
   */
  private showElevationPopup(coord: HexCoord): void {
    const key = `${coord.q},${coord.r}`;
    const tileData = this.tileDataMap.get(key);
    const elevation = tileData?.elevation ?? 0;

    // Format elevation with sign for non-zero values
    const elevationText = elevation === 0 ? "0" : (elevation > 0 ? `+${elevation}` : `${elevation}`);

    // Get terrain color for contrast calculation
    const terrain = (tileData?.terrain as string) ?? "clear";
    const terrainColor = TERRAIN_COLORS[terrain] ?? TERRAIN_COLORS.clear;
    const textColor = this.getContrastColor(terrainColor);

    const { x, y } = hexToPixel(coord, this.config.hexSize);

    if (!this.elevationPopup) {
      // Create popup text - font size is 25% of hex height (hex height = 2 * hexSize)
      const fontSize = this.config.hexSize * 0.5; // 25% of (2 * hexSize)
      const style = new TextStyle({
        fontFamily: "Arial",
        fontSize: fontSize,
        fontWeight: "bold",
        fill: textColor,
        align: "center",
      });
      this.elevationPopup = new Text({ text: elevationText, style });
      this.elevationPopup.anchor.set(0.5, 0.5);
      // Add to labelContainer so it moves/scales with the map
      this.labelContainer.addChild(this.elevationPopup);
    } else {
      this.elevationPopup.text = elevationText;
      // Update font size and color in case hex size or terrain changed
      const fontSize = this.config.hexSize * 0.5;
      this.elevationPopup.style.fontSize = fontSize;
      this.elevationPopup.style.fill = textColor;
    }

    this.elevationPopup.x = x;
    this.elevationPopup.y = y;
    this.elevationPopup.visible = true;
  }

  /**
   * Calculate contrasting text color (black or white) based on background color luminance
   */
  private getContrastColor(bgColor: number): number {
    // Extract RGB components
    const r = (bgColor >> 16) & 0xff;
    const g = (bgColor >> 8) & 0xff;
    const b = bgColor & 0xff;

    // Calculate relative luminance using sRGB formula
    // https://www.w3.org/TR/WCAG20/#relativeluminancedef
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;

    // Return black for light backgrounds, white for dark backgrounds
    return luminance > 0.5 ? 0x000000 : 0xffffff;
  }

  /**
   * Hide the elevation popup
   */
  private hideElevationPopup(): void {
    if (this.elevationPopup) {
      this.elevationPopup.visible = false;
    }
  }

  /**
   * Update a single hex tile (removes old graphics first)
   */
  updateHex(tile: TileData): void {
    const key = `${tile.coord.q},${tile.coord.r}`;

    // Remove old hex graphics
    const oldHex = this.hexGraphics.get(key);
    if (oldHex) {
      this.mapContainer.removeChild(oldHex);
      oldHex.destroy();
      this.hexGraphics.delete(key);
    }

    // Remove old auxiliary graphics (edges, overlays, transport segments, labels)
    this.clearAuxGraphics(tile.coord);

    // Draw the new hex
    this.drawHex(tile);

    // Update elevation popup if this hex is currently hovered and elevation tool is active
    if (
      this.config.elevationToolActive &&
      this.hoveredHex &&
      this.hoveredHex.q === tile.coord.q &&
      this.hoveredHex.r === tile.coord.r
    ) {
      this.showElevationPopup(this.hoveredHex);
    }
  }

  /**
   * Update multiple hex tiles
   */
  updateHexes(tiles: TileData[]): void {
    for (const tile of tiles) {
      this.updateHex(tile);
    }
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
    this.tileDataMap.clear();
    this.auxGraphics.clear();
    // Destroy elevation popup since labelContainer.removeChildren() removed it
    if (this.elevationPopup) {
      this.elevationPopup.destroy();
      this.elevationPopup = null;
    }
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
      this.satelliteContainer,
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
    this.mapWidth = width;
    this.mapHeight = height;
    const centerQ = Math.floor(width / 2);
    const centerR = Math.floor(height / 2);
    this.centerOnHex({ q: centerQ, r: centerR });
  }

  /**
   * Set the map dimensions for bounds checking
   */
  setMapDimensions(width: number, height: number): void {
    this.mapWidth = width;
    this.mapHeight = height;
  }

  /**
   * Check if a coordinate is within the map bounds
   */
  isInBounds(coord: { q: number; r: number }): boolean {
    if (this.mapWidth === 0 || this.mapHeight === 0) {
      // No bounds set, allow all coordinates
      return true;
    }
    return coord.q >= 0 && coord.q < this.mapWidth && coord.r >= 0 && coord.r < this.mapHeight;
  }

  /**
   * Callback for hex selection
   */
  onHexSelected?: (coord: HexCoord, modifiers: HexClickModifiers) => void;

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
    const wasElevationToolActive = this.config.elevationToolActive;
    const wasShowSatellite = this.config.showSatellite;
    const oldOpacity = this.config.satelliteOpacity;
    this.config = { ...this.config, ...config };

    // Hide elevation popup when elevation tool is deactivated
    if (wasElevationToolActive && !this.config.elevationToolActive) {
      this.hideElevationPopup();
    }
    // Show elevation popup if elevation tool is now active and we have a hovered hex
    if (!wasElevationToolActive && this.config.elevationToolActive && this.hoveredHex) {
      this.showElevationPopup(this.hoveredHex);
    }

    // Update satellite visibility
    if (wasShowSatellite !== this.config.showSatellite) {
      this.satelliteContainer.visible = this.config.showSatellite;
    }

    // Update satellite opacity if changed
    if (oldOpacity !== this.config.satelliteOpacity) {
      this.satelliteContainer.alpha = this.config.satelliteOpacity;
    }
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

  /**
   * Load and display satellite imagery
   *
   * @param data - Satellite data from backend including tiles and bounds
   * @param mapScale - Meters per hex from map configuration
   * @param mapWidth - Map width in hexes
   * @param mapHeight - Map height in hexes
   */
  async loadSatelliteData(
    data: SatelliteData,
    mapScale: number,
    mapWidth?: number,
    mapHeight?: number
  ): Promise<void> {
    // Clear existing satellite sprites
    this.clearSatellite();

    // Store the data for reference
    this.satelliteData = data;

    // Use passed dimensions or fall back to stored values
    const width = mapWidth ?? this.mapWidth;
    const height = mapHeight ?? this.mapHeight;

    console.log("loadSatelliteData - dimensions:", { width, height, hexSize: this.config.hexSize });
    console.log("loadSatelliteData - bounds:", data.bounds);
    console.log("loadSatelliteData - tiles count:", data.tiles.length);

    if (width === 0 || height === 0) {
      console.error("Cannot load satellite data: map dimensions not set");
      return;
    }

    // Calculate the pixel dimensions of the map
    // For pointy-top hexes:
    //   hex_width (horizontal spacing) = hexSize * sqrt(3)
    //   hex_height (vertical spacing) = hexSize * 1.5
    const hexWidth = this.config.hexSize * Math.sqrt(3);
    const hexHeight = this.config.hexSize * 1.5;

    // Map dimensions in pixels
    const mapWidthPixels = hexWidth * width;
    const mapHeightPixels = hexHeight * height;

    console.log("loadSatelliteData - map pixels:", { mapWidthPixels, mapHeightPixels });

    // Map bounds in lat/lng
    const { north, south, west, east } = data.bounds;

    // Calculate pixels per degree
    const lngRange = east - west;
    const latRange = north - south;
    const pixelsPerDegreeLng = mapWidthPixels / lngRange;
    const pixelsPerDegreeLat = mapHeightPixels / latRange;

    console.log("loadSatelliteData - pixels per degree:", { pixelsPerDegreeLng, pixelsPerDegreeLat });

    // Load each tile
    const loadPromises = data.tiles.map(async (tile) => {
      try {
        console.log("Loading tile:", tile.url);
        // Load the texture from the tile URL using Assets.load for proper caching
        const texture = await Assets.load<Texture>(tile.url);
        const sprite = new Sprite(texture);

        // Calculate tile position in pixels relative to map origin
        // The map origin (0,0) is at the top-left corner in pixel space
        // which corresponds to the northwest corner in geo coordinates
        const tileWest = tile.west;
        const tileNorth = tile.north;

        // Position from the map's west/north bounds
        const x = (tileWest - west) * pixelsPerDegreeLng;
        const y = (north - tileNorth) * pixelsPerDegreeLat;

        // Calculate tile dimensions in pixels
        const tileWidth = (tile.east - tile.west) * pixelsPerDegreeLng;
        const tileHeight = (tileNorth - tile.south) * pixelsPerDegreeLat;

        console.log("Tile position:", { x, y, tileWidth, tileHeight });

        sprite.x = x;
        sprite.y = y;
        sprite.width = tileWidth;
        sprite.height = tileHeight;

        this.satelliteSprites.push(sprite);
        this.satelliteContainer.addChild(sprite);
        console.log("Tile added successfully");
      } catch (error) {
        console.warn(`Failed to load satellite tile ${tile.url}:`, error);
      }
    });

    await Promise.all(loadPromises);

    console.log("All tiles loaded, sprites count:", this.satelliteSprites.length);

    // Create a mask to clip satellite imagery to the hex map bounds
    // Calculate the pixel bounds of the hex map
    const hexWidthPx = this.config.hexSize * Math.sqrt(3);
    const hexHeightPx = this.config.hexSize * 2;
    const vertSpacing = hexHeightPx * 0.75;

    // Map bounds in pixels:
    // - Left edge: hex (0,0) center minus half hex width
    // - Right edge: hex (width-1, even row) plus half hex width, or odd row plus full hex width
    // - Top edge: hex (0,0) center minus half hex height
    // - Bottom edge: hex (0, height-1) center plus half hex height
    const minX = -hexWidthPx / 2;
    const maxX = (width - 1) * hexWidthPx + hexWidthPx / 2 + hexWidthPx / 2; // Extra for odd row offset
    const minY = -hexHeightPx / 2;
    const maxY = (height - 1) * vertSpacing + hexHeightPx / 2;

    console.log("Satellite mask bounds:", { minX, maxX, minY, maxY });

    // Create the mask
    if (this.satelliteMask) {
      this.satelliteMask.destroy();
    }
    this.satelliteMask = new Graphics();
    this.satelliteMask.rect(minX, minY, maxX - minX, maxY - minY);
    this.satelliteMask.fill(0xffffff);

    // Apply mask to satellite container
    this.satelliteContainer.mask = this.satelliteMask;
    this.satelliteContainer.addChild(this.satelliteMask);

    // Make visible immediately after loading
    this.satelliteContainer.visible = true;
    this.config.showSatellite = true;
    this.satelliteContainer.alpha = this.config.satelliteOpacity;
  }

  /**
   * Clear all satellite imagery
   */
  clearSatellite(): void {
    for (const sprite of this.satelliteSprites) {
      sprite.destroy();
    }
    this.satelliteSprites = [];
    this.satelliteContainer.removeChildren();
    this.satelliteContainer.mask = null;
    if (this.satelliteMask) {
      this.satelliteMask.destroy();
      this.satelliteMask = null;
    }
    this.satelliteData = null;
  }

  /**
   * Set satellite overlay opacity (0-1)
   */
  setSatelliteOpacity(opacity: number): void {
    this.config.satelliteOpacity = Math.max(0, Math.min(1, opacity));
    this.satelliteContainer.alpha = this.config.satelliteOpacity;
  }

  /**
   * Toggle satellite visibility
   */
  setSatelliteVisible(visible: boolean): void {
    this.config.showSatellite = visible;
    this.satelliteContainer.visible = visible;
  }

  /**
   * Check if satellite data is loaded
   */
  hasSatelliteData(): boolean {
    return this.satelliteData !== null && this.satelliteSprites.length > 0;
  }

  /**
   * Get the satellite container
   */
  getSatelliteContainer(): Container {
    return this.satelliteContainer;
  }
}
