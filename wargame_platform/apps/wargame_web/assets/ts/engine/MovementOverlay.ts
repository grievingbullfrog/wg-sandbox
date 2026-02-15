/**
 * Movement Overlay for Game UI
 *
 * Shows reachable hexes for the selected unit with a color gradient
 * indicating remaining movement cost, and draws path previews.
 */
import { Container, Graphics } from "pixi.js";
import { AxialCoord, hexToPixel } from "../hex/coord";

/** Reachable hex with movement cost info */
export interface ReachableHex {
  q: number;
  r: number;
  cost: number;
  maxCost: number;
}

/** Path waypoint */
export interface PathPoint {
  q: number;
  r: number;
}

/** Combat preview data */
export interface CombatPreview {
  targetHex: AxialCoord;
  odds: string;         // e.g. "3:1"
  modifiers: string[];  // e.g. ["terrain +1", "leader +1"]
}

/**
 * Manages movement and combat overlays on the hex map.
 */
export class MovementOverlay {
  private container: Container;
  private reachableGraphics: Graphics;
  private pathGraphics: Graphics;
  private combatGraphics: Graphics;
  private hexSize: number;

  constructor(container: Container, hexSize: number) {
    this.container = container;
    this.hexSize = hexSize;

    this.reachableGraphics = new Graphics();
    this.pathGraphics = new Graphics();
    this.combatGraphics = new Graphics();

    this.container.addChild(this.reachableGraphics);
    this.container.addChild(this.pathGraphics);
    this.container.addChild(this.combatGraphics);
  }

  /** Update hex size */
  setHexSize(hexSize: number): void {
    this.hexSize = hexSize;
  }

  /**
   * Show reachable hexes with color gradient.
   * Green = lots of movement remaining, yellow = moderate, red = nearly exhausted.
   */
  showReachableHexes(hexes: ReachableHex[]): void {
    this.reachableGraphics.clear();

    for (const hex of hexes) {
      const { x, y } = hexToPixel({ q: hex.q, r: hex.r }, this.hexSize);
      const ratio = hex.maxCost > 0 ? hex.cost / hex.maxCost : 0;

      // Gradient: green (low cost) → yellow → red (high cost)
      const color = this.costColor(ratio);

      // Draw hex highlight
      const points = this.getHexPoints(x, y);
      this.reachableGraphics.poly(points);
      this.reachableGraphics.fill({ color, alpha: 0.3 });
      this.reachableGraphics.setStrokeStyle({ width: 1, color, alpha: 0.6 });
      this.reachableGraphics.poly(points);
      this.reachableGraphics.stroke();
    }
  }

  /**
   * Show a movement path as a dotted/dashed line between hex centers.
   */
  showMovementPath(path: PathPoint[]): void {
    this.pathGraphics.clear();
    if (path.length < 2) return;

    const dashLength = 6;
    const gapLength = 4;

    this.pathGraphics.setStrokeStyle({ width: 3, color: 0x00ffff, alpha: 0.8 });

    for (let i = 0; i < path.length - 1; i++) {
      const from = hexToPixel(path[i], this.hexSize);
      const to = hexToPixel(path[i + 1], this.hexSize);
      this.drawDashedLine(from.x, from.y, to.x, to.y, dashLength, gapLength);
    }

    // Draw arrow at destination
    if (path.length >= 2) {
      const last = hexToPixel(path[path.length - 1], this.hexSize);
      const prev = hexToPixel(path[path.length - 2], this.hexSize);
      this.drawArrowHead(prev.x, prev.y, last.x, last.y);
    }
  }

  /**
   * Show combat preview: red highlight on target hex with odds overlay.
   */
  showCombatPreview(preview: CombatPreview): void {
    this.combatGraphics.clear();
    const { x, y } = hexToPixel(preview.targetHex, this.hexSize);

    // Red hex highlight
    const points = this.getHexPoints(x, y);
    this.combatGraphics.poly(points);
    this.combatGraphics.fill({ color: 0xff0000, alpha: 0.3 });
    this.combatGraphics.setStrokeStyle({ width: 2, color: 0xff0000, alpha: 0.8 });
    this.combatGraphics.poly(points);
    this.combatGraphics.stroke();

    // Crosshair
    const crossSize = this.hexSize * 0.3;
    this.combatGraphics.setStrokeStyle({ width: 2, color: 0xff4444, alpha: 0.8 });
    this.combatGraphics.moveTo(x - crossSize, y);
    this.combatGraphics.lineTo(x + crossSize, y);
    this.combatGraphics.stroke();
    this.combatGraphics.moveTo(x, y - crossSize);
    this.combatGraphics.lineTo(x, y + crossSize);
    this.combatGraphics.stroke();
  }

  /** Clear all movement overlays */
  clearReachable(): void {
    this.reachableGraphics.clear();
  }

  /** Clear path preview */
  clearPath(): void {
    this.pathGraphics.clear();
  }

  /** Clear combat preview */
  clearCombat(): void {
    this.combatGraphics.clear();
  }

  /** Clear everything */
  clear(): void {
    this.reachableGraphics.clear();
    this.pathGraphics.clear();
    this.combatGraphics.clear();
  }

  /** Destroy and clean up */
  destroy(): void {
    this.clear();
    this.reachableGraphics.destroy();
    this.pathGraphics.destroy();
    this.combatGraphics.destroy();
  }

  private costColor(ratio: number): number {
    // 0 = green, 0.5 = yellow, 1.0 = red
    const r = Math.round(Math.min(1, ratio * 2) * 255);
    const g = Math.round(Math.min(1, (1 - ratio) * 2) * 255);
    return (r << 16) | (g << 8) | 0;
  }

  private getHexPoints(cx: number, cy: number): number[] {
    const points: number[] = [];
    for (let i = 0; i < 6; i++) {
      const angle = (Math.PI / 3) * i - Math.PI / 6;
      points.push(
        cx + this.hexSize * Math.cos(angle),
        cy + this.hexSize * Math.sin(angle)
      );
    }
    return points;
  }

  private drawDashedLine(
    x1: number, y1: number, x2: number, y2: number,
    dashLen: number, gapLen: number
  ): void {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const len = Math.sqrt(dx * dx + dy * dy);
    const nx = dx / len;
    const ny = dy / len;
    let pos = 0;
    let drawing = true;

    while (pos < len) {
      const segLen = drawing ? dashLen : gapLen;
      const end = Math.min(pos + segLen, len);

      if (drawing) {
        this.pathGraphics.moveTo(x1 + nx * pos, y1 + ny * pos);
        this.pathGraphics.lineTo(x1 + nx * end, y1 + ny * end);
        this.pathGraphics.stroke();
      }

      pos = end;
      drawing = !drawing;
    }
  }

  private drawArrowHead(fromX: number, fromY: number, toX: number, toY: number): void {
    const dx = toX - fromX;
    const dy = toY - fromY;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len === 0) return;

    const nx = dx / len;
    const ny = dy / len;
    const arrowSize = 8;

    // Arrow wings
    const wing1X = toX - arrowSize * (nx - ny * 0.5);
    const wing1Y = toY - arrowSize * (ny + nx * 0.5);
    const wing2X = toX - arrowSize * (nx + ny * 0.5);
    const wing2Y = toY - arrowSize * (ny - nx * 0.5);

    this.pathGraphics.poly([toX, toY, wing1X, wing1Y, wing2X, wing2Y]);
    this.pathGraphics.fill({ color: 0x00ffff, alpha: 0.8 });
  }
}
