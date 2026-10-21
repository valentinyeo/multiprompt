const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const bytes = fs.readFileSync(path.join(root, 'src/fonts/NordwandMono-SemiBold.ttf'));
const tables = new Map();
for (let i = 0; i < bytes.readUInt16BE(4); i++) {
  const offset = 12 + i * 16;
  tables.set(bytes.toString('ascii', offset, offset + 4), bytes.readUInt32BE(offset + 8));
}
const u16 = (table, offset) => bytes.readUInt16BE(tables.get(table) + offset);
const i16 = (table, offset) => bytes.readInt16BE(tables.get(table) + offset);
const unicodeCmaps = [];
const cmap = tables.get('cmap');
for (let i = 0; i < u16('cmap', 2); i++) {
  const record = cmap + 4 + i * 8;
  const platform = bytes.readUInt16BE(record);
  const encoding = bytes.readUInt16BE(record + 2);
  if (platform === 0 || (platform === 3 && [1, 10].includes(encoding))) {
    unicodeCmaps.push(cmap + bytes.readUInt32BE(record + 4));
  }
}

function glyphId(codepoint, subtable = unicodeCmaps[0]) {
  const format = bytes.readUInt16BE(subtable);
  if (format === 4) {
    const count = bytes.readUInt16BE(subtable + 6) / 2;
    const ends = subtable + 14;
    const starts = ends + count * 2 + 2;
    const deltas = starts + count * 2;
    const offsets = deltas + count * 2;
    for (let i = 0; i < count; i++) {
      const start = bytes.readUInt16BE(starts + i * 2);
      if (codepoint < start || codepoint > bytes.readUInt16BE(ends + i * 2)) continue;
      const delta = bytes.readInt16BE(deltas + i * 2);
      const offset = bytes.readUInt16BE(offsets + i * 2);
      if (!offset) return (codepoint + delta) & 0xffff;
      const id = bytes.readUInt16BE(offsets + i * 2 + offset + (codepoint - start) * 2);
      return id === 0 ? 0 : (id + delta) & 0xffff;
    }
    return 0;
  }
  if (format === 12) {
    for (let i = 0; i < bytes.readUInt32BE(subtable + 12); i++) {
      const group = subtable + 16 + i * 12;
      const start = bytes.readUInt32BE(group);
      if (codepoint >= start && codepoint <= bytes.readUInt32BE(group + 4)) {
        return bytes.readUInt32BE(group + 8) + codepoint - start;
      }
    }
    return 0;
  }
  assert.fail(`unsupported Unicode cmap format ${format}`);
}

function glyph(codepoint) {
  const id = glyphId(codepoint);
  assert.ok(id > 0 && id < u16('maxp', 4), `missing U+${codepoint.toString(16).toUpperCase()}`);
  const long = i16('head', 50) === 1;
  const loca = tables.get('loca') + id * (long ? 4 : 2);
  const start = long ? bytes.readUInt32BE(loca) : bytes.readUInt16BE(loca) * 2;
  const end = long ? bytes.readUInt32BE(loca + 4) : bytes.readUInt16BE(loca + 2) * 2;
  assert.ok(end > start, `empty U+${codepoint.toString(16)}`);
  const offset = tables.get('glyf') + start;
  const metric = Math.min(id, u16('hhea', 34) - 1) * 4;
  return {
    id, offset,
    contours: bytes.readInt16BE(offset),
    xMin: bytes.readInt16BE(offset + 2), yMin: bytes.readInt16BE(offset + 4),
    xMax: bytes.readInt16BE(offset + 6), yMax: bytes.readInt16BE(offset + 8),
    advance: u16('hmtx', metric),
  };
}

function contours(codepoint) {
  const g = glyph(codepoint);
  assert.ok(g.contours > 0, 'terminal glyphs must have simple TrueType outlines');
  const ends = Array.from({ length: g.contours }, (_, i) => bytes.readUInt16BE(g.offset + 10 + i * 2));
  let cursor = g.offset + 10 + g.contours * 2;
  cursor += 2 + bytes.readUInt16BE(cursor);
  const flags = [];
  while (flags.length <= ends.at(-1)) {
    const flag = bytes[cursor++];
    const repeat = flag & 8 ? bytes[cursor++] : 0;
    for (let i = 0; i <= repeat; i++) flags.push(flag);
  }
  const coordinates = [];
  for (const [short, same] of [[2, 16], [4, 32]]) {
    let value = 0;
    coordinates.push(flags.map(flag => {
      if (flag & short) value += bytes[cursor++] * (flag & same ? 1 : -1);
      else if (!(flag & same)) { value += bytes.readInt16BE(cursor); cursor += 2; }
      assert.ok(flag & 1, 'terminal outlines must not rely on off-curve control points');
      return value;
    }));
  }
  let start = 0;
  return ends.map(end => {
    const points = coordinates[0].slice(start, end + 1).map((x, i) => [x, coordinates[1][start + i]]);
    start = end + 1;
    return points;
  });
}

function filled(codepoint, x, y) {
  let winding = 0;
  for (const points of contours(codepoint)) {
    for (let i = 0; i < points.length; i++) {
      const [ax, ay] = points[i];
      const [bx, by] = points[(i + 1) % points.length];
      const cross = (bx - ax) * (y - ay) - (x - ax) * (by - ay);
      if (ay <= y && by > y && cross > 0) winding++;
      if (ay > y && by <= y && cross < 0) winding--;
    }
  }
  return winding !== 0;
}

const codepoints = [
  ...Array.from({ length: 160 }, (_, i) => 0x2500 + i),
  ...Array.from({ length: 4 }, (_, i) => 0xE0B0 + i),
];
const advance = u16('hmtx', Math.min(glyphId(0x20), u16('hhea', 34) - 1) * 4);
const top = u16('OS/2', 74);
const bottom = -u16('OS/2', 76);
const light = glyph(0x7c).xMax - glyph(0x7c).xMin;
const cx = advance / 2;
const cy = Math.round((top + bottom) / 2);

test('all 164 box, block and Powerline characters exist in every Unicode cmap', () => {
  assert.ok(unicodeCmaps.length > 0);
  for (const codepoint of codepoints) {
    for (const subtable of unicodeCmaps) {
      assert.equal(glyphId(codepoint, subtable), glyph(codepoint).id);
    }
  }
});

test('every terminal outline is nonempty, simple, cell-bounded and monospace', () => {
  for (const codepoint of codepoints) {
    const g = glyph(codepoint);
    assert.equal(g.advance, advance, `advance of U+${codepoint.toString(16)}`);
    assert.ok(g.contours > 0);
    assert.ok(g.xMin >= 0 && g.xMax <= advance && g.xMax > g.xMin);
    assert.ok(g.yMin >= bottom && g.yMax <= top && g.yMax > g.yMin);
    contours(codepoint);
  }
});

test('unbroken verticals, full blocks and Powerline arrows touch both Windows cell edges', () => {
  for (const codepoint of [0x2502, 0x2503, 0x2551, 0x2588, 0xE0B0, 0xE0B1, 0xE0B2, 0xE0B3]) {
    assert.equal(glyph(codepoint).yMin, bottom);
    assert.equal(glyph(codepoint).yMax, top);
  }
  for (const codepoint of [0x2500, 0x2501, 0x2550, 0x2588, 0xE0B0, 0xE0B1, 0xE0B2, 0xE0B3]) {
    assert.equal(glyph(codepoint).xMin, 0);
    assert.equal(glyph(codepoint).xMax, advance);
  }
});

test('light strokes match the SemiBold stem, heavy strokes double it, and double rails keep a light gap', () => {
  for (const [codepoint, thickness] of [[0x2500, light], [0x2501, 2 * light]]) {
    assert.equal(glyph(codepoint).yMax - glyph(codepoint).yMin, thickness);
  }
  for (const [codepoint, thickness] of [[0x2502, light], [0x2503, 2 * light]]) {
    assert.equal(glyph(codepoint).xMax - glyph(codepoint).xMin, thickness);
  }
  for (const [x, y] of [[cx, cy - light], [cx, cy + light]]) assert.ok(filled(0x2550, x, y));
  assert.equal(filled(0x2550, cx, cy), false);
  for (const x of [cx - light, cx + light]) assert.ok(filled(0x2551, x, cy));
  assert.equal(filled(0x2551, cx, cy), false);
  assert.equal(glyph(0x2550).yMax - glyph(0x2550).yMin, 3 * light);
  assert.equal(glyph(0x2551).xMax - glyph(0x2551).xMin, 3 * light);
});

test('dashes have two, three or four separated strokes at both weights', () => {
  for (const [first, count] of [[0x2504, 3], [0x2508, 4], [0x254C, 2]]) {
    for (let i = 0; i < 4; i++) {
      const codepoint = first + i;
      const g = glyph(codepoint);
      assert.equal(g.contours, count);
      if (i < 2) assert.equal(g.yMax - g.yMin, light * (1 + i % 2));
      else assert.equal(g.xMax - g.xMin, light * (1 + i % 2));
    }
  }
});

test('square arc substitutes and diagonals reach the correct cell edges', () => {
  for (const [codepoint, dx, dy] of [[0x256D, 1, -1], [0x256E, -1, -1], [0x256F, -1, 1], [0x2570, 1, 1]]) {
    assert.ok(filled(codepoint, dx > 0 ? advance - 1 : 1, cy));
    assert.ok(filled(codepoint, cx, dy > 0 ? top - 1 : bottom + 1));
    assert.equal(filled(codepoint, dx > 0 ? 1 : advance - 1, cy), false);
    assert.equal(filled(codepoint, cx, dy > 0 ? bottom + 1 : top - 1), false);
  }
  for (const codepoint of [0x2571, 0x2572, 0x2573]) {
    const g = glyph(codepoint);
    assert.deepEqual([g.xMin, g.yMin, g.xMax, g.yMax], [0, bottom, advance, top]);
    assert.ok(filled(codepoint, cx, cy));
  }
  assert.ok(filled(0x2571, advance / 4, bottom + (top - bottom) / 4));
  assert.equal(filled(0x2572, advance / 4, bottom + (top - bottom) / 4), false);
  assert.ok(filled(0x2572, advance / 4, top - (top - bottom) / 4));
});

test('double corners preserve two connected bends rather than solid junctions', () => {
  for (const [codepoint, dx, dy] of [[0x2554, 1, -1], [0x2557, -1, -1], [0x255A, 1, 1], [0x255D, -1, 1]]) {
    assert.equal(filled(codepoint, cx, cy), false);
    assert.ok(filled(codepoint, cx - dx * light, cy - dy * light));
    assert.ok(filled(codepoint, cx + dx * light, cy + dy * light));
    assert.equal(filled(codepoint, cx, cy + dy * light), false);
  }
});

test('mixed single/double tees leave the rail gap open while crosses keep the single stroke continuous', () => {
  for (const codepoint of [0x255F, 0x2562, 0x2564, 0x2567]) assert.equal(filled(codepoint, cx, cy), false);
  for (const codepoint of [0x255E, 0x2561, 0x2565, 0x2568, 0x256A, 0x256B]) assert.ok(filled(codepoint, cx, cy));
});

test('eighth blocks, quadrants and 25/50/75 percent shades have the expected filled area', () => {
  const area = codepoint => Math.abs(contours(codepoint).reduce((sum, points) => sum + points.reduce((s, [x, y], i) => {
    const [nx, ny] = points[(i + 1) % points.length];
    return s + x * ny - nx * y;
  }, 0) / 2, 0));
  const cell = advance * (top - bottom);
  for (let i = 1; i <= 8; i++) assert.ok(Math.abs(area(0x2580 + i) / cell - i / 8) < 0.001);
  for (let i = 1; i <= 7; i++) assert.ok(Math.abs(area(0x2590 - i) / cell - i / 8) < 0.001);
  for (let i = 1; i <= 3; i++) assert.ok(Math.abs(area(0x2590 + i) / cell - i / 4) < 0.001);
  for (const [codepoint, fraction] of [[0x2596, 0.25], [0x2599, 0.75], [0x259A, 0.5], [0x259F, 0.75]]) {
    assert.ok(Math.abs(area(codepoint) / cell - fraction) < 0.001);
  }
});

test('solid and thin Powerline arrows point in opposite directions without filling the thin interior', () => {
  assert.ok(filled(0xE0B0, advance / 4, cy));
  assert.ok(filled(0xE0B2, advance * 3 / 4, cy));
  assert.equal(filled(0xE0B1, advance / 4, cy), false);
  assert.equal(filled(0xE0B3, advance * 3 / 4, cy), false);
  assert.ok(filled(0xE0B1, advance - light / 2, cy));
  assert.ok(filled(0xE0B3, light / 2, cy));
});

test('committed font matches the SHA-256 of the reproducible generator output', () => {
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), '4e12ff22bac2b17554dfbaa6f4b80ea66e56adbf5d868c8fe573a69c15e419e2');
});

test('both CI build test steps include the dependency-free terminal glyph regression', () => {
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(build, /const terminal_glyph_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/terminal-glyphs\.test\.js" \}\);/);
  assert.match(build, /test_step\.dependOn\(&terminal_glyph_tests\.step\)/);
  assert.match(build, /vps_test_step\.dependOn\(&terminal_glyph_tests\.step\)/);
});
