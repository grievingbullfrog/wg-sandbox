import { describe, it, expect } from 'vitest';
import {
  HexCoord,
  HEX_DIRECTIONS,
  hexNeighbor,
  hexNeighbors,
  hexToPixel,
  pixelToHex,
  hexRound,
  hexesInRange,
  hexRing,
  hexLineDraw,
} from './coord';

describe('HexCoord', () => {
  describe('constructor and from', () => {
    it('creates coordinate with given q and r values', () => {
      const coord = new HexCoord(3, 4);
      expect(coord.q).toBe(3);
      expect(coord.r).toBe(4);
    });

    it('HexCoord.from creates coordinate', () => {
      const coord = HexCoord.from(5, -2);
      expect(coord.q).toBe(5);
      expect(coord.r).toBe(-2);
    });
  });

  describe('s property', () => {
    it('computes cube s coordinate', () => {
      const coord = new HexCoord(3, -1);
      expect(coord.s).toBe(-2);
    });

    it('origin has s = 0', () => {
      const coord = new HexCoord(0, 0);
      // Use == to handle -0 === 0 comparison in JavaScript
      expect(coord.s == 0).toBe(true);
    });

    it('s satisfies q + r + s = 0', () => {
      const coord = new HexCoord(5, -3);
      expect(coord.q + coord.r + coord.s).toBe(0);
    });
  });

  describe('fromCube', () => {
    it('creates coordinate from valid cube coordinates', () => {
      const coord = HexCoord.fromCube(1, -2, 1);
      expect(coord.q).toBe(1);
      expect(coord.r).toBe(-2);
    });

    it('throws error for invalid cube coordinates', () => {
      expect(() => HexCoord.fromCube(1, 1, 1)).toThrow();
    });
  });

  describe('equals', () => {
    it('returns true for equal coordinates', () => {
      const a = new HexCoord(1, 2);
      const b = new HexCoord(1, 2);
      expect(a.equals(b)).toBe(true);
    });

    it('returns false for different coordinates', () => {
      const a = new HexCoord(1, 2);
      const b = new HexCoord(2, 1);
      expect(a.equals(b)).toBe(false);
    });
  });

  describe('toKey and fromKey', () => {
    it('converts coordinate to string key', () => {
      const coord = new HexCoord(3, -2);
      expect(coord.toKey()).toBe('3,-2');
    });

    it('parses key back to coordinate', () => {
      const coord = HexCoord.fromKey('3,-2');
      expect(coord.q).toBe(3);
      expect(coord.r).toBe(-2);
    });

    it('roundtrips correctly', () => {
      const original = new HexCoord(-5, 10);
      const key = original.toKey();
      const parsed = HexCoord.fromKey(key);
      expect(original.equals(parsed)).toBe(true);
    });
  });

  describe('distanceTo and static distance', () => {
    it('distance from hex to itself is 0', () => {
      const a = new HexCoord(3, 4);
      expect(a.distanceTo(a)).toBe(0);
    });

    it('distance to adjacent hex is 1', () => {
      const a = new HexCoord(0, 0);
      const b = new HexCoord(1, 0);
      expect(a.distanceTo(b)).toBe(1);
    });

    it('calculates distance correctly for non-adjacent hexes', () => {
      const a = new HexCoord(0, 0);
      const b = new HexCoord(3, -1);
      expect(HexCoord.distance(a, b)).toBe(3);
    });

    it('distance is symmetric', () => {
      const a = new HexCoord(2, 3);
      const b = new HexCoord(5, -1);
      expect(HexCoord.distance(a, b)).toBe(HexCoord.distance(b, a));
    });
  });

  describe('add', () => {
    it('adds two coordinates', () => {
      const a = new HexCoord(1, 2);
      const b = new HexCoord(3, -1);
      const result = a.add(b);
      expect(result.q).toBe(4);
      expect(result.r).toBe(1);
    });

    it('adding origin has no effect', () => {
      const a = new HexCoord(5, -3);
      const origin = new HexCoord(0, 0);
      const result = a.add(origin);
      expect(result.equals(a)).toBe(true);
    });
  });

  describe('subtract', () => {
    it('subtracts second coordinate from first', () => {
      const a = new HexCoord(4, 1);
      const b = new HexCoord(1, 2);
      const result = a.subtract(b);
      expect(result.q).toBe(3);
      expect(result.r).toBe(-1);
    });

    it('subtracting coordinate from itself gives origin', () => {
      const a = new HexCoord(5, -3);
      const result = a.subtract(a);
      expect(result.q).toBe(0);
      expect(result.r).toBe(0);
    });
  });

  describe('scale', () => {
    it('scales coordinate by positive factor', () => {
      const coord = new HexCoord(2, 3);
      const result = coord.scale(2);
      expect(result.q).toBe(4);
      expect(result.r).toBe(6);
    });

    it('scaling by 1 has no effect', () => {
      const coord = new HexCoord(5, -3);
      const result = coord.scale(1);
      expect(result.equals(coord)).toBe(true);
    });

    it('scaling by 0 gives origin', () => {
      const coord = new HexCoord(5, -3);
      const result = coord.scale(0);
      // Use == to handle -0 === 0 comparison in JavaScript
      expect(result.q == 0).toBe(true);
      expect(result.r == 0).toBe(true);
    });
  });

  describe('toString', () => {
    it('returns readable string representation', () => {
      const coord = new HexCoord(3, -2);
      expect(coord.toString()).toBe('HexCoord(3, -2)');
    });
  });
});

describe('HEX_DIRECTIONS', () => {
  it('has 6 directions', () => {
    expect(HEX_DIRECTIONS.length).toBe(6);
  });

  it('east direction is correct', () => {
    expect(HEX_DIRECTIONS[0]).toEqual({ q: 1, r: 0 });
  });

  it('west direction is correct', () => {
    expect(HEX_DIRECTIONS[3]).toEqual({ q: -1, r: 0 });
  });
});

describe('hexNeighbor', () => {
  it('gets east neighbor (direction 0)', () => {
    const coord = new HexCoord(0, 0);
    const neighbor = hexNeighbor(coord, 0);
    expect(neighbor.q).toBe(1);
    expect(neighbor.r).toBe(0);
  });

  it('gets west neighbor (direction 3)', () => {
    const coord = new HexCoord(0, 0);
    const neighbor = hexNeighbor(coord, 3);
    expect(neighbor.q).toBe(-1);
    expect(neighbor.r).toBe(0);
  });

  it('handles negative direction wrapping', () => {
    const coord = new HexCoord(0, 0);
    const neighbor = hexNeighbor(coord, -1);
    expect(neighbor.equals(hexNeighbor(coord, 5))).toBe(true);
  });

  it('handles direction > 5 wrapping', () => {
    const coord = new HexCoord(0, 0);
    const neighbor = hexNeighbor(coord, 6);
    expect(neighbor.equals(hexNeighbor(coord, 0))).toBe(true);
  });
});

describe('hexNeighbors', () => {
  it('returns all six neighbors', () => {
    const coord = new HexCoord(0, 0);
    const neighbors = hexNeighbors(coord);
    expect(neighbors.length).toBe(6);
  });

  it('all neighbors are at distance 1', () => {
    const coord = new HexCoord(3, 2);
    const neighbors = hexNeighbors(coord);
    neighbors.forEach((neighbor) => {
      expect(coord.distanceTo(neighbor)).toBe(1);
    });
  });

  it('neighbors are unique', () => {
    const coord = new HexCoord(0, 0);
    const neighbors = hexNeighbors(coord);
    const keys = neighbors.map((n) => n.toKey());
    const uniqueKeys = [...new Set(keys)];
    expect(keys.length).toBe(uniqueKeys.length);
  });
});

describe('hexToPixel (offset coordinates)', () => {
  it('origin maps to (0, 0)', () => {
    const coord = new HexCoord(0, 0);
    const pixel = hexToPixel(coord, 40);
    expect(pixel.x).toBeCloseTo(0, 4);
    expect(pixel.y).toBeCloseTo(0, 4);
  });

  it('returns valid pixel coordinates', () => {
    const coord = new HexCoord(1, 1);
    const pixel = hexToPixel(coord, 40);
    expect(typeof pixel.x).toBe('number');
    expect(typeof pixel.y).toBe('number');
  });

  it('odd rows are shifted right', () => {
    const size = 40;
    const hexWidth = Math.sqrt(3) * size;

    // Even row (r=0): no offset
    const evenRow = hexToPixel({ q: 0, r: 0 }, size);
    expect(evenRow.x).toBeCloseTo(0, 4);

    // Odd row (r=1): shifted right by half hex width
    const oddRow = hexToPixel({ q: 0, r: 1 }, size);
    expect(oddRow.x).toBeCloseTo(hexWidth / 2, 4);

    // Even row (r=2): no offset again
    const evenRow2 = hexToPixel({ q: 0, r: 2 }, size);
    expect(evenRow2.x).toBeCloseTo(0, 4);
  });

  it('produces rectangular grid layout', () => {
    const size = 40;
    const hexWidth = Math.sqrt(3) * size;

    // Hexes in same column should have same x (accounting for row offset)
    const row0col1 = hexToPixel({ q: 1, r: 0 }, size);
    const row2col1 = hexToPixel({ q: 1, r: 2 }, size);
    expect(row0col1.x).toBeCloseTo(row2col1.x, 4);

    // Hexes in same row should be evenly spaced
    const row0col0 = hexToPixel({ q: 0, r: 0 }, size);
    const row0col2 = hexToPixel({ q: 2, r: 0 }, size);
    expect(row0col2.x - row0col0.x).toBeCloseTo(2 * hexWidth, 4);
  });
});

describe('pixelToHex', () => {
  it('origin pixel maps to origin hex', () => {
    const coord = pixelToHex(0, 0, 40);
    expect(coord.q).toBe(0);
    expect(coord.r).toBe(0);
  });

  it('is inverse of hexToPixel', () => {
    const original = new HexCoord(3, 2);
    const pixel = hexToPixel(original, 40);
    const result = pixelToHex(pixel.x, pixel.y, 40);
    expect(result.equals(original)).toBe(true);
  });
});

describe('hexRound', () => {
  it('rounds fractional coordinates to nearest hex', () => {
    const result = hexRound(0.1, 0.1);
    expect(result.q).toBe(0);
    expect(result.r).toBe(0);
  });

  it('rounds to integer coordinates', () => {
    const result = hexRound(2.7, 1.3);
    expect(Number.isInteger(result.q)).toBe(true);
    expect(Number.isInteger(result.r)).toBe(true);
  });
});

describe('hexesInRange', () => {
  it('range 0 returns only the center hex', () => {
    const center = new HexCoord(0, 0);
    const hexes = hexesInRange(center, 0);
    expect(hexes.length).toBe(1);
    expect(hexes[0].equals(center)).toBe(true);
  });

  it('range 1 returns 7 hexes (center + 6 neighbors)', () => {
    const center = new HexCoord(0, 0);
    const hexes = hexesInRange(center, 1);
    expect(hexes.length).toBe(7);
  });

  it('range 2 returns 19 hexes', () => {
    const center = new HexCoord(0, 0);
    const hexes = hexesInRange(center, 2);
    // Formula: 3n^2 + 3n + 1 for range n
    // For n=2: 3*4 + 3*2 + 1 = 19
    expect(hexes.length).toBe(19);
  });

  it('all returned hexes are within the specified range', () => {
    const center = new HexCoord(5, 3);
    const range = 3;
    const hexes = hexesInRange(center, range);
    hexes.forEach((hex) => {
      expect(center.distanceTo(hex)).toBeLessThanOrEqual(range);
    });
  });

  it('hexes are unique', () => {
    const center = new HexCoord(0, 0);
    const hexes = hexesInRange(center, 3);
    const keys = hexes.map((h) => h.toKey());
    const uniqueKeys = [...new Set(keys)];
    expect(keys.length).toBe(uniqueKeys.length);
  });
});

describe('hexRing', () => {
  it('ring of radius 0 returns only the center', () => {
    const center = new HexCoord(0, 0);
    const ring = hexRing(center, 0);
    expect(ring.length).toBe(1);
    expect(ring[0].equals(center)).toBe(true);
  });

  it('ring of radius 1 returns 6 hexes', () => {
    const center = new HexCoord(0, 0);
    const ring = hexRing(center, 1);
    expect(ring.length).toBe(6);
  });

  it('ring of radius 2 returns 12 hexes', () => {
    const center = new HexCoord(0, 0);
    const ring = hexRing(center, 2);
    // Formula: 6n for radius n > 0
    expect(ring.length).toBe(12);
  });

  it('all hexes in ring are at exact distance from center', () => {
    const center = new HexCoord(3, -2);
    const radius = 3;
    const ring = hexRing(center, radius);
    ring.forEach((hex) => {
      expect(center.distanceTo(hex)).toBe(radius);
    });
  });
});

describe('hexLineDraw', () => {
  it('line from hex to itself returns single hex', () => {
    const a = new HexCoord(0, 0);
    const line = hexLineDraw(a, a);
    expect(line.length).toBe(1);
    expect(line[0].equals(a)).toBe(true);
  });

  it('line to adjacent hex returns 2 hexes', () => {
    const a = new HexCoord(0, 0);
    const b = new HexCoord(1, 0);
    const line = hexLineDraw(a, b);
    expect(line.length).toBe(2);
  });

  it('line includes start and end hexes', () => {
    const a = new HexCoord(0, 0);
    const b = new HexCoord(3, 0);
    const line = hexLineDraw(a, b);

    expect(line.some((h) => h.equals(a))).toBe(true);
    expect(line.some((h) => h.equals(b))).toBe(true);
  });

  it('line length equals distance + 1', () => {
    const a = new HexCoord(0, 0);
    const b = new HexCoord(3, 0);
    const line = hexLineDraw(a, b);
    expect(line.length).toBe(HexCoord.distance(a, b) + 1);
  });

  it('consecutive hexes in line are adjacent', () => {
    const a = new HexCoord(0, 0);
    const b = new HexCoord(3, -2);
    const line = hexLineDraw(a, b);

    for (let i = 0; i < line.length - 1; i++) {
      expect(line[i].distanceTo(line[i + 1])).toBe(1);
    }
  });
});
