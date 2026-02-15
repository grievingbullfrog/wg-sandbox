/**
 * NATO APP-6 Military Symbol Drawing Functions
 *
 * Draws standard NATO military symbols using PixiJS Graphics.
 * Each function draws its symbol centered at (0, 0) within a given size.
 * The symbol fits within a square of dimensions (size x size).
 */
import { Graphics } from "pixi.js";

/** Unit category type matching backend categories */
export type UnitCategory =
  | "infantry"
  | "armor"
  | "artillery"
  | "recon"
  | "engineer"
  | "anti_tank"
  | "anti_air"
  | "cavalry"
  | "mechanized"
  | "headquarters"
  | "supply"
  | "leader";

/** Unit size type matching backend unit sizes */
export type UnitSize =
  | "squad"
  | "section"
  | "platoon"
  | "company"
  | "battalion"
  | "regiment"
  | "brigade"
  | "division"
  | "corps"
  | "army";

const SYMBOL_COLOR = 0x000000;
const SYMBOL_LINE_WIDTH = 2;

/**
 * Draw the infantry symbol: crossed diagonal lines (X)
 */
export function drawInfantry(g: Graphics, size: number): void {
  const half = size / 2;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.moveTo(-half, -half);
  g.lineTo(half, half);
  g.stroke();
  g.moveTo(half, -half);
  g.lineTo(-half, half);
  g.stroke();
}

/**
 * Draw the armor symbol: oval/ellipse
 */
export function drawArmor(g: Graphics, size: number): void {
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.ellipse(0, 0, size / 2, size / 3);
  g.stroke();
}

/**
 * Draw the artillery symbol: filled circle
 */
export function drawArtillery(g: Graphics, size: number): void {
  const radius = size / 4;
  g.circle(0, 0, radius);
  g.fill(SYMBOL_COLOR);
}

/**
 * Draw the recon symbol: diagonal line (slash)
 */
export function drawRecon(g: Graphics, size: number): void {
  const half = size / 2;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.moveTo(half, -half);
  g.lineTo(-half, half);
  g.stroke();
}

/**
 * Draw the engineer symbol: letter "E"
 */
export function drawEngineer(g: Graphics, size: number): void {
  const half = size / 2;
  const third = size / 3;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  // Vertical bar
  g.moveTo(-third, -half);
  g.lineTo(-third, half);
  g.stroke();
  // Top bar
  g.moveTo(-third, -half);
  g.lineTo(third, -half);
  g.stroke();
  // Middle bar
  g.moveTo(-third, 0);
  g.lineTo(third * 0.7, 0);
  g.stroke();
  // Bottom bar
  g.moveTo(-third, half);
  g.lineTo(third, half);
  g.stroke();
}

/**
 * Draw the anti-tank symbol: oval with center line
 */
export function drawAntiTank(g: Graphics, size: number): void {
  // Draw the armor oval
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.ellipse(0, 0, size / 2, size / 3);
  g.stroke();
  // Vertical line through center
  g.moveTo(0, -size / 3);
  g.lineTo(0, size / 3);
  g.stroke();
}

/**
 * Draw the anti-air symbol: infantry X rotated 45 degrees (+ shape)
 */
export function drawAntiAir(g: Graphics, size: number): void {
  const half = size / 2;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  // Vertical line
  g.moveTo(0, -half);
  g.lineTo(0, half);
  g.stroke();
  // Horizontal line
  g.moveTo(-half, 0);
  g.lineTo(half, 0);
  g.stroke();
}

/**
 * Draw the cavalry symbol: single diagonal line
 */
export function drawCavalry(g: Graphics, size: number): void {
  const half = size / 2;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.moveTo(-half, -half);
  g.lineTo(half, half);
  g.stroke();
}

/**
 * Draw the mechanized infantry symbol: infantry X with oval
 */
export function drawMechanized(g: Graphics, size: number): void {
  drawInfantry(g, size * 0.8);
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  g.ellipse(0, 0, size / 2, size / 3);
  g.stroke();
}

/**
 * Draw the headquarters symbol: horizontal line with flag
 */
export function drawHeadquarters(g: Graphics, size: number): void {
  const half = size / 2;
  g.setStrokeStyle({ width: SYMBOL_LINE_WIDTH, color: SYMBOL_COLOR });
  // Horizontal base line
  g.moveTo(-half, 0);
  g.lineTo(half, 0);
  g.stroke();
  // Vertical flagpole from center
  g.moveTo(0, 0);
  g.lineTo(0, -half);
  g.stroke();
}

/**
 * Draw the supply symbol: filled square
 */
export function drawSupply(g: Graphics, size: number): void {
  const quarter = size / 4;
  g.rect(-quarter, -quarter, quarter * 2, quarter * 2);
  g.fill(SYMBOL_COLOR);
}

/**
 * Draw the leader symbol: star
 */
export function drawLeader(g: Graphics, size: number): void {
  const outerR = size / 2;
  const innerR = size / 5;
  const points: number[] = [];
  for (let i = 0; i < 5; i++) {
    // Outer point (start from top)
    const outerAngle = (Math.PI * 2 * i) / 5 - Math.PI / 2;
    points.push(Math.cos(outerAngle) * outerR, Math.sin(outerAngle) * outerR);
    // Inner point
    const innerAngle = outerAngle + Math.PI / 5;
    points.push(Math.cos(innerAngle) * innerR, Math.sin(innerAngle) * innerR);
  }
  g.poly(points);
  g.fill(SYMBOL_COLOR);
}

/**
 * Draw the NATO symbol for a given unit category
 */
export function drawNATOSymbol(g: Graphics, category: UnitCategory, size: number): void {
  switch (category) {
    case "infantry":
      drawInfantry(g, size);
      break;
    case "armor":
      drawArmor(g, size);
      break;
    case "artillery":
      drawArtillery(g, size);
      break;
    case "recon":
      drawRecon(g, size);
      break;
    case "engineer":
      drawEngineer(g, size);
      break;
    case "anti_tank":
      drawAntiTank(g, size);
      break;
    case "anti_air":
      drawAntiAir(g, size);
      break;
    case "cavalry":
      drawCavalry(g, size);
      break;
    case "mechanized":
      drawMechanized(g, size);
      break;
    case "headquarters":
      drawHeadquarters(g, size);
      break;
    case "supply":
      drawSupply(g, size);
      break;
    case "leader":
      drawLeader(g, size);
      break;
  }
}

/** Size indicator marks above the unit symbol box */
const SIZE_INDICATORS: Record<UnitSize, string> = {
  squad: "\u2022",       // •
  section: "\u2022\u2022",    // ••
  platoon: "\u2022\u2022\u2022",  // •••
  company: "I",
  battalion: "II",
  regiment: "III",
  brigade: "X",
  division: "XX",
  corps: "XXX",
  army: "XXXX",
};

/**
 * Get the display string for a unit size indicator
 */
export function getSizeIndicator(size: UnitSize): string {
  return SIZE_INDICATORS[size] || "";
}
