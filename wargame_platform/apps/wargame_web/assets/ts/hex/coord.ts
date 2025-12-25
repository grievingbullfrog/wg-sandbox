/**
 * Axial coordinate system for hex grids.
 * Based on Red Blob Games implementation guide.
 * @see https://www.redblobgames.com/grids/hexagons/
 */

export interface AxialCoord {
  readonly q: number;
  readonly r: number;
}

/**
 * Immutable hex coordinate using axial coordinate system.
 * Stores q and r; computes s = -q - r when needed.
 */
export class HexCoord implements AxialCoord {
  constructor(
    public readonly q: number,
    public readonly r: number
  ) {}

  /** Cube coordinate s (computed from q and r) */
  get s(): number {
    return -this.q - this.r;
  }

  /** Create a new HexCoord from axial coordinates */
  static from(q: number, r: number): HexCoord {
    return new HexCoord(q, r);
  }

  /** Create a new HexCoord from cube coordinates (validates s = -q - r) */
  static fromCube(q: number, r: number, s: number): HexCoord {
    if (Math.round(q + r + s) !== 0) {
      throw new Error(`Invalid cube coordinates: q + r + s must equal 0`);
    }
    return new HexCoord(q, r);
  }

  /** Check equality with another coordinate */
  equals(other: AxialCoord): boolean {
    return this.q === other.q && this.r === other.r;
  }

  /** Create a string key for use in Maps/Sets */
  toKey(): string {
    return `${this.q},${this.r}`;
  }

  /** Parse a key back to HexCoord */
  static fromKey(key: string): HexCoord {
    const [q, r] = key.split(",").map(Number);
    return new HexCoord(q, r);
  }

  /** Calculate distance to another hex (number of steps) */
  distanceTo(other: AxialCoord): number {
    return HexCoord.distance(this, other);
  }

  /** Static distance calculation between two coordinates */
  static distance(a: AxialCoord, b: AxialCoord): number {
    const aS = -a.q - a.r;
    const bS = -b.q - b.r;
    return Math.max(
      Math.abs(a.q - b.q),
      Math.abs(a.r - b.r),
      Math.abs(aS - bS)
    );
  }

  /** Add two coordinates */
  add(other: AxialCoord): HexCoord {
    return new HexCoord(this.q + other.q, this.r + other.r);
  }

  /** Subtract another coordinate */
  subtract(other: AxialCoord): HexCoord {
    return new HexCoord(this.q - other.q, this.r - other.r);
  }

  /** Scale coordinate by a factor */
  scale(factor: number): HexCoord {
    return new HexCoord(this.q * factor, this.r * factor);
  }

  toString(): string {
    return `HexCoord(${this.q}, ${this.r})`;
  }
}

/**
 * Direction vectors for pointy-top hexes (0 = East, going counter-clockwise)
 */
export const HEX_DIRECTIONS: readonly AxialCoord[] = [
  { q: 1, r: 0 },   // 0: East
  { q: 1, r: -1 },  // 1: Northeast
  { q: 0, r: -1 },  // 2: Northwest
  { q: -1, r: 0 },  // 3: West
  { q: -1, r: 1 },  // 4: Southwest
  { q: 0, r: 1 },   // 5: Southeast
] as const;

/**
 * Get the neighbor of a hex in a given direction
 * @param coord The starting coordinate
 * @param direction Direction index 0-5 (0 = East, counter-clockwise)
 */
export function hexNeighbor(coord: AxialCoord, direction: number): HexCoord {
  const dir = HEX_DIRECTIONS[((direction % 6) + 6) % 6];
  return new HexCoord(coord.q + dir.q, coord.r + dir.r);
}

/**
 * Get all six neighbors of a hex
 */
export function hexNeighbors(coord: AxialCoord): HexCoord[] {
  return HEX_DIRECTIONS.map((dir) => new HexCoord(coord.q + dir.q, coord.r + dir.r));
}

/**
 * Convert axial hex coordinate to pixel position (pointy-top orientation)
 * This is for true axial coordinates where moving in +r direction goes diagonally.
 * @param coord Hex coordinate
 * @param size Hex size (distance from center to corner)
 */
export function hexToPixelAxial(coord: AxialCoord, size: number): { x: number; y: number } {
  const x = size * (Math.sqrt(3) * coord.q + (Math.sqrt(3) / 2) * coord.r);
  const y = size * ((3 / 2) * coord.r);
  return { x, y };
}

/**
 * Convert offset hex coordinate to pixel position (pointy-top, odd-r layout)
 * This creates a rectangular grid where odd rows are shifted right.
 * Used when q=column, r=row in a rectangular map.
 * @param coord Offset coordinate (q=column, r=row)
 * @param size Hex size (distance from center to corner)
 */
export function hexToPixel(coord: AxialCoord, size: number): { x: number; y: number } {
  const hexWidth = Math.sqrt(3) * size;
  const hexHeight = 2 * size;
  const vertSpacing = hexHeight * 0.75;

  // Odd rows shift right by half a hex width
  const xOffset = (coord.r % 2 === 1) ? hexWidth / 2 : 0;

  const x = coord.q * hexWidth + xOffset;
  const y = coord.r * vertSpacing;

  return { x, y };
}

/**
 * Convert pixel position to axial hex coordinate (pointy-top orientation)
 * This is for true axial coordinates.
 * @param x Pixel x
 * @param y Pixel y
 * @param size Hex size
 */
export function pixelToHexAxial(x: number, y: number, size: number): HexCoord {
  const q = ((Math.sqrt(3) / 3) * x - (1 / 3) * y) / size;
  const r = ((2 / 3) * y) / size;
  return hexRound(q, r);
}

/**
 * Convert pixel position to offset hex coordinate (pointy-top, odd-r layout)
 * Used for rectangular maps where q=column, r=row.
 * @param x Pixel x
 * @param y Pixel y
 * @param size Hex size
 */
export function pixelToHex(x: number, y: number, size: number): HexCoord {
  const hexWidth = Math.sqrt(3) * size;
  const hexHeight = 2 * size;
  const vertSpacing = hexHeight * 0.75;

  // First determine the row
  const row = Math.round(y / vertSpacing);

  // Adjust x for the row offset
  const xOffset = (row % 2 === 1) ? hexWidth / 2 : 0;
  const col = Math.round((x - xOffset) / hexWidth);

  // Do a more precise check by testing this hex and neighbors
  // to find which hex center is actually closest
  const candidates = [
    { q: col, r: row },
    { q: col - 1, r: row },
    { q: col + 1, r: row },
    { q: col, r: row - 1 },
    { q: col, r: row + 1 },
    { q: col - 1, r: row - 1 },
    { q: col + 1, r: row - 1 },
    { q: col - 1, r: row + 1 },
    { q: col + 1, r: row + 1 },
  ];

  let closest = candidates[0];
  let closestDist = Infinity;

  for (const candidate of candidates) {
    const center = hexToPixel(candidate, size);
    const dist = Math.sqrt((x - center.x) ** 2 + (y - center.y) ** 2);
    if (dist < closestDist) {
      closestDist = dist;
      closest = candidate;
    }
  }

  return new HexCoord(closest.q, closest.r);
}

/**
 * Round fractional hex coordinates to nearest hex
 */
export function hexRound(q: number, r: number): HexCoord {
  const s = -q - r;

  let rQ = Math.round(q);
  let rR = Math.round(r);
  let rS = Math.round(s);

  const qDiff = Math.abs(rQ - q);
  const rDiff = Math.abs(rR - r);
  const sDiff = Math.abs(rS - s);

  if (qDiff > rDiff && qDiff > sDiff) {
    rQ = -rR - rS;
  } else if (rDiff > sDiff) {
    rR = -rQ - rS;
  }

  return new HexCoord(rQ, rR);
}

/**
 * Get all hexes within a given range of a center hex
 */
export function hexesInRange(center: AxialCoord, range: number): HexCoord[] {
  const results: HexCoord[] = [];
  for (let q = -range; q <= range; q++) {
    for (let r = Math.max(-range, -q - range); r <= Math.min(range, -q + range); r++) {
      results.push(new HexCoord(center.q + q, center.r + r));
    }
  }
  return results;
}

/**
 * Get hexes forming a ring at a given radius from center
 */
export function hexRing(center: AxialCoord, radius: number): HexCoord[] {
  if (radius === 0) {
    return [new HexCoord(center.q, center.r)];
  }

  const results: HexCoord[] = [];
  let hex = new HexCoord(
    center.q + HEX_DIRECTIONS[4].q * radius,
    center.r + HEX_DIRECTIONS[4].r * radius
  );

  for (let i = 0; i < 6; i++) {
    for (let j = 0; j < radius; j++) {
      results.push(hex);
      hex = hexNeighbor(hex, i);
    }
  }

  return results;
}

/**
 * Draw a line between two hexes using linear interpolation
 */
export function hexLineDraw(a: AxialCoord, b: AxialCoord): HexCoord[] {
  const n = HexCoord.distance(a, b);
  if (n === 0) {
    return [new HexCoord(a.q, a.r)];
  }

  const results: HexCoord[] = [];
  const aS = -a.q - a.r;
  const bS = -b.q - b.r;

  for (let i = 0; i <= n; i++) {
    const t = i / n;
    const q = a.q + (b.q - a.q) * t;
    const r = a.r + (b.r - a.r) * t;
    results.push(hexRound(q, r));
  }

  return results;
}
