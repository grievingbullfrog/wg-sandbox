/**
 * Unit Counter Renderer for PixiJS
 *
 * Renders military unit counters with NATO symbology, stats, and status indicators.
 * Each UnitCounter is a PixiJS Container that can be added to the unit layer.
 */
import { Container, Graphics, Text, TextStyle } from "pixi.js";
import { drawNATOSymbol, getSizeIndicator, UnitCategory, UnitSize } from "./NATOSymbols";
import { AxialCoord, hexToPixel } from "../hex/coord";

/** Side colors for unit counters */
export interface SideColors {
  background: number;
  border: number;
  text: number;
}

/** Default side color palettes */
export const SIDE_COLORS: Record<string, SideColors> = {
  axis: { background: 0x4a6fa5, border: 0x2a4f85, text: 0xffffff },     // Blue tones
  allied: { background: 0xc0392b, border: 0x922b21, text: 0xffffff },    // Red tones
  german: { background: 0x4a6fa5, border: 0x2a4f85, text: 0xffffff },
  soviet: { background: 0xc0392b, border: 0x922b21, text: 0xffffff },
  american: { background: 0x27ae60, border: 0x1e8449, text: 0xffffff },  // Green
  british: { background: 0x8e6c3e, border: 0x6d5230, text: 0xffffff },   // Khaki
  default: { background: 0x7f8c8d, border: 0x5d6d7e, text: 0xffffff },   // Gray
};

/** Data structure for a unit to render */
export interface UnitData {
  id: string;
  name: string;
  side: string;
  force: string;
  category: UnitCategory;
  unitSize: UnitSize;
  position: AxialCoord;
  attackSoft: number;
  attackHard: number;
  defense: number;
  strength: number;
  maxStrength: number;
  movement: number;
  maxMovement: number;
  morale: number;
  experience: number;
  isDisrupted: boolean;
  isRouted: boolean;
  isEntrenched: boolean;
  isUnsupplied: boolean;
  hasAttacked: boolean;
  hasMoved: boolean;
  isSelected?: boolean;
}

/** Counter dimensions */
const COUNTER_WIDTH = 48;
const COUNTER_HEIGHT = 48;
const BORDER_WIDTH = 2;
const SYMBOL_SIZE = 18;
const STAT_FONT_SIZE = 8;
const NAME_FONT_SIZE = 7;
const SIZE_FONT_SIZE = 8;

/**
 * UnitCounter renders a single military unit counter as a PixiJS Container.
 *
 * Layout (48x48):
 * ┌────────────────────┐
 * │  Size Indicator     │  (top, centered)
 * │                     │
 * │   [NATO Symbol]     │  (center area)
 * │                     │
 * │  Unit Name          │  (below symbol)
 * ├──────┬──────┬──────┤
 * │ ATK  │ DEF  │ MOV  │  (bottom stats row)
 * └──────┴──────┴──────┘
 * [===strength bar====] (very bottom)
 */
export class UnitCounter extends Container {
  private data: UnitData;
  private bg: Graphics;
  private symbolGraphics: Graphics;
  private nameText: Text;
  private sizeText: Text;
  private statsText: Text;
  private strengthBar: Graphics;
  private statusIcons: Graphics;
  private selectionHighlight: Graphics;

  constructor(data: UnitData) {
    super();
    this.data = data;

    // Create all child display objects
    this.bg = new Graphics();
    this.symbolGraphics = new Graphics();
    this.nameText = new Text({ text: "", style: this.nameStyle() });
    this.sizeText = new Text({ text: "", style: this.sizeStyle() });
    this.statsText = new Text({ text: "", style: this.statsStyle() });
    this.strengthBar = new Graphics();
    this.statusIcons = new Graphics();
    this.selectionHighlight = new Graphics();

    this.addChild(this.selectionHighlight);
    this.addChild(this.bg);
    this.addChild(this.symbolGraphics);
    this.addChild(this.sizeText);
    this.addChild(this.nameText);
    this.addChild(this.statsText);
    this.addChild(this.strengthBar);
    this.addChild(this.statusIcons);

    this.render();

    // Center the counter on its position
    this.pivot.set(COUNTER_WIDTH / 2, COUNTER_HEIGHT / 2);
  }

  /** Get current unit data */
  getData(): UnitData {
    return this.data;
  }

  /** Update unit data and re-render */
  update(data: Partial<UnitData>): void {
    this.data = { ...this.data, ...data };
    this.render();
  }

  /** Full re-render of the counter */
  private render(): void {
    this.renderBackground();
    this.renderSymbol();
    this.renderName();
    this.renderSizeIndicator();
    this.renderStats();
    this.renderStrengthBar();
    this.renderStatusIcons();
    this.renderSelection();
  }

  private getColors(): SideColors {
    return (
      SIDE_COLORS[this.data.force] ||
      SIDE_COLORS[this.data.side] ||
      SIDE_COLORS.default
    );
  }

  private renderBackground(): void {
    const colors = this.getColors();
    this.bg.clear();

    // Outer border
    this.bg.roundRect(0, 0, COUNTER_WIDTH, COUNTER_HEIGHT, 3);
    this.bg.fill(colors.border);

    // Inner background
    this.bg.roundRect(
      BORDER_WIDTH,
      BORDER_WIDTH,
      COUNTER_WIDTH - BORDER_WIDTH * 2,
      COUNTER_HEIGHT - BORDER_WIDTH * 2,
      2
    );
    this.bg.fill(colors.background);

    // Disrupted/routed visual: overlay tint
    if (this.data.isRouted) {
      this.bg.roundRect(
        BORDER_WIDTH,
        BORDER_WIDTH,
        COUNTER_WIDTH - BORDER_WIDTH * 2,
        COUNTER_HEIGHT - BORDER_WIDTH * 2,
        2
      );
      this.bg.fill({ color: 0xff0000, alpha: 0.3 });
    } else if (this.data.isDisrupted) {
      this.bg.roundRect(
        BORDER_WIDTH,
        BORDER_WIDTH,
        COUNTER_WIDTH - BORDER_WIDTH * 2,
        COUNTER_HEIGHT - BORDER_WIDTH * 2,
        2
      );
      this.bg.fill({ color: 0xffaa00, alpha: 0.2 });
    }
  }

  private renderSymbol(): void {
    this.symbolGraphics.clear();
    this.symbolGraphics.x = COUNTER_WIDTH / 2;
    this.symbolGraphics.y = 17;
    drawNATOSymbol(this.symbolGraphics, this.data.category, SYMBOL_SIZE);
  }

  private renderName(): void {
    this.nameText.text = this.truncateName(this.data.name, 8);
    this.nameText.x = COUNTER_WIDTH / 2;
    this.nameText.y = 28;
    this.nameText.anchor.set(0.5, 0);
  }

  private renderSizeIndicator(): void {
    this.sizeText.text = getSizeIndicator(this.data.unitSize as UnitSize);
    this.sizeText.x = COUNTER_WIDTH / 2;
    this.sizeText.y = 3;
    this.sizeText.anchor.set(0.5, 0);
  }

  private renderStats(): void {
    // Show attack (soft) / defense / movement remaining
    const atk = this.data.attackSoft;
    const def = this.data.defense;
    const mov = this.data.movement;
    this.statsText.text = `${atk}-${def}-${mov}`;
    this.statsText.x = COUNTER_WIDTH / 2;
    this.statsText.y = 37;
    this.statsText.anchor.set(0.5, 0);
  }

  private renderStrengthBar(): void {
    this.strengthBar.clear();
    const barY = COUNTER_HEIGHT - 4;
    const barWidth = COUNTER_WIDTH - BORDER_WIDTH * 2 - 2;
    const barHeight = 2;
    const barX = BORDER_WIDTH + 1;

    // Background
    this.strengthBar.rect(barX, barY, barWidth, barHeight);
    this.strengthBar.fill(0x333333);

    // Filled portion
    const ratio = Math.max(0, Math.min(1, this.data.strength / this.data.maxStrength));
    const fillColor = ratio > 0.6 ? 0x27ae60 : ratio > 0.3 ? 0xf39c12 : 0xe74c3c;
    if (ratio > 0) {
      this.strengthBar.rect(barX, barY, barWidth * ratio, barHeight);
      this.strengthBar.fill(fillColor);
    }
  }

  private renderStatusIcons(): void {
    this.statusIcons.clear();
    const iconY = 10;
    const iconSize = 5;
    let iconX = COUNTER_WIDTH - BORDER_WIDTH - 2;

    // Entrenched: small shield icon (filled triangle pointing up)
    if (this.data.isEntrenched) {
      this.statusIcons.moveTo(iconX, iconY);
      this.statusIcons.lineTo(iconX - iconSize, iconY + iconSize);
      this.statusIcons.lineTo(iconX + iconSize, iconY + iconSize);
      this.statusIcons.closePath();
      this.statusIcons.fill(0x00cc00);
      iconX -= iconSize * 2 + 2;
    }

    // Unsupplied: small red circle
    if (this.data.isUnsupplied) {
      this.statusIcons.circle(iconX, iconY + iconSize / 2, iconSize / 2);
      this.statusIcons.fill(0xff4444);
      iconX -= iconSize + 2;
    }

    // Has attacked: small lightning bolt (simplified as filled diamond)
    if (this.data.hasAttacked) {
      this.statusIcons.moveTo(iconX, iconY);
      this.statusIcons.lineTo(iconX + iconSize / 2, iconY + iconSize / 2);
      this.statusIcons.lineTo(iconX, iconY + iconSize);
      this.statusIcons.lineTo(iconX - iconSize / 2, iconY + iconSize / 2);
      this.statusIcons.closePath();
      this.statusIcons.fill(0xffcc00);
    }
  }

  private renderSelection(): void {
    this.selectionHighlight.clear();
    if (this.data.isSelected) {
      this.selectionHighlight.roundRect(-2, -2, COUNTER_WIDTH + 4, COUNTER_HEIGHT + 4, 4);
      this.selectionHighlight.fill({ color: 0xffff00, alpha: 0.4 });
      this.selectionHighlight.setStrokeStyle({ width: 2, color: 0xffff00 });
      this.selectionHighlight.roundRect(-2, -2, COUNTER_WIDTH + 4, COUNTER_HEIGHT + 4, 4);
      this.selectionHighlight.stroke();
    }
  }

  private truncateName(name: string, maxLen: number): string {
    if (name.length <= maxLen) return name;
    return name.substring(0, maxLen - 1) + ".";
  }

  private nameStyle(): TextStyle {
    return new TextStyle({
      fontFamily: "monospace",
      fontSize: NAME_FONT_SIZE,
      fill: this.getColors().text,
      align: "center",
    });
  }

  private sizeStyle(): TextStyle {
    return new TextStyle({
      fontFamily: "monospace",
      fontSize: SIZE_FONT_SIZE,
      fill: this.getColors().text,
      fontWeight: "bold",
      align: "center",
    });
  }

  private statsStyle(): TextStyle {
    return new TextStyle({
      fontFamily: "monospace",
      fontSize: STAT_FONT_SIZE,
      fill: this.getColors().text,
      align: "center",
    });
  }
}

/** Stacking offset for multiple units on same hex */
const STACK_OFFSET_Y = -8;
const MAX_VISIBLE_STACK = 3;

/**
 * Manages rendering of all unit counters on the map.
 * Handles stacking, selection, and position updates.
 */
export class UnitLayerManager {
  private unitCounters: Map<string, UnitCounter> = new Map();
  private container: Container;
  private hexSize: number;

  constructor(container: Container, hexSize: number) {
    this.container = container;
    this.hexSize = hexSize;
  }

  /** Set hex size (for coordinate conversion) */
  setHexSize(hexSize: number): void {
    this.hexSize = hexSize;
  }

  /** Render all units from a full state update */
  renderUnits(units: UnitData[]): void {
    this.clearUnits();

    // Group units by position for stacking
    const byPosition = new Map<string, UnitData[]>();
    for (const unit of units) {
      const key = `${unit.position.q},${unit.position.r}`;
      const group = byPosition.get(key) || [];
      group.push(unit);
      byPosition.set(key, group);
    }

    // Create and place counters
    for (const [_key, group] of byPosition) {
      this.renderStack(group);
    }
  }

  /** Update a single unit (move, stats change, etc.) */
  updateUnit(unit: UnitData): void {
    const existing = this.unitCounters.get(unit.id);
    if (existing) {
      existing.update(unit);
      this.positionUnit(existing, unit);
    } else {
      // New unit (reinforcement)
      const counter = new UnitCounter(unit);
      this.unitCounters.set(unit.id, counter);
      this.container.addChild(counter);
      this.positionUnit(counter, unit);
    }
  }

  /** Remove a unit (destroyed) */
  removeUnit(unitId: string): void {
    const counter = this.unitCounters.get(unitId);
    if (counter) {
      this.container.removeChild(counter);
      counter.destroy();
      this.unitCounters.delete(unitId);
    }
  }

  /** Clear all units */
  clearUnits(): void {
    for (const counter of this.unitCounters.values()) {
      counter.destroy();
    }
    this.unitCounters.clear();
    this.container.removeChildren();
  }

  /** Get a unit counter by ID */
  getCounter(unitId: string): UnitCounter | undefined {
    return this.unitCounters.get(unitId);
  }

  /** Select a unit (visual highlight) */
  selectUnit(unitId: string | null): void {
    for (const [id, counter] of this.unitCounters) {
      counter.update({ isSelected: id === unitId });
    }
  }

  /** Get all unit IDs at a position */
  getUnitsAtPosition(coord: AxialCoord): string[] {
    const ids: string[] = [];
    for (const [id, counter] of this.unitCounters) {
      const data = counter.getData();
      if (data.position.q === coord.q && data.position.r === coord.r) {
        ids.push(id);
      }
    }
    return ids;
  }

  private renderStack(units: UnitData[]): void {
    // Sort: selected unit on top, then by category priority
    const sorted = [...units].sort((a, b) => {
      if (a.isSelected && !b.isSelected) return 1; // selected on top
      if (!a.isSelected && b.isSelected) return -1;
      return 0;
    });

    const visibleCount = Math.min(sorted.length, MAX_VISIBLE_STACK);
    for (let i = 0; i < sorted.length; i++) {
      const unit = sorted[i];
      const counter = new UnitCounter(unit);
      this.unitCounters.set(unit.id, counter);
      this.container.addChild(counter);

      const { x, y } = hexToPixel(unit.position, this.hexSize);
      if (i < visibleCount) {
        // Stagger visible units upward
        counter.x = x;
        counter.y = y + (visibleCount - 1 - i) * STACK_OFFSET_Y;
        counter.visible = true;
      } else {
        // Hidden in stack
        counter.x = x;
        counter.y = y;
        counter.visible = false;
      }
    }
  }

  private positionUnit(counter: UnitCounter, data: UnitData): void {
    const { x, y } = hexToPixel(data.position, this.hexSize);
    counter.x = x;
    counter.y = y;
  }
}
