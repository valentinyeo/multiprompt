const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

function parseFrames(text) {
  const frames = [];
  const byId = new Map();
  for (const line of text.trim().split(/\r?\n/)) {
    const [type, ...v] = line.split('\t');
    if (type === 'frame') {
      const keys = ['id', 'tick', 'active', 'cache', 'dirty', 'scroll', 'height', 'pad', 'opening', 'x', 'y', 'width', 'viewport', 'scrolledUp', 'hold', 'layouts'];
      if (v.length !== keys.length) throw new Error('Incomplete frame header');
      const frame = Object.fromEntries(keys.map((key, i) => [key, Number(v[i])]));
      frame.blocks = [];
      frames.push(frame);
      byId.set(v[0], frame);
    } else if (type === 'block') {
      const [id, index, message, offset, start, length, left, top, right, bottom] = v;
      const frame = byId.get(id);
      if (!frame) throw new Error('Block without frame');
      frame.blocks.push({ index: Number(index), message, offset, start: Number(start), length: Number(length), left: Number(left), top: Number(top), right: Number(right), bottom: Number(bottom) });
    } else if (type === 'end') {
      const frame = byId.get(v[0]);
      if (!frame) throw new Error('End without frame');
      frame.end = Number(v[1]);
    } else throw new Error(`Unknown frame record ${type}`);
  }
  if (!frames.length) throw new Error('No actual paints recorded');
  for (let i = 0; i < frames.length; i++) {
    if (frames[i].id !== i + 1 || !frames[i].end) throw new Error('Missing or incomplete successful paint');
  }
  return frames;
}

function image(directory, frame) {
  const filename = `paint-${String(frame.id).padStart(6, '0')}.bmp`;
  const bytes = fs.readFileSync(path.join(directory, filename));
  if (bytes.toString('ascii', 0, 2) !== 'BM' || bytes.readInt32LE(18) !== frame.width || bytes.readInt32LE(22) !== -frame.viewport || bytes.length !== 54 + frame.width * frame.viewport * 4) throw new Error(`Invalid paint image ${filename}`);
  return bytes;
}

function rows(bytes, frame, block) {
  const found = new Map();
  const left = Math.max(0, block.left - frame.x + 12);
  const right = Math.min(frame.width, block.right - frame.x - 12);
  if (right - left < 32) return found;
  for (let y = Math.max(0, block.top - frame.y + 8); y < Math.min(frame.viewport, block.bottom - frame.y - 8); y++) {
    const row = bytes.subarray(54 + (y * frame.width + left) * 4, 54 + (y * frame.width + right) * 4);
    let changes = 0;
    for (let x = 4; x < row.length; x += 4) if (!row.subarray(x, x + 3).equals(row.subarray(0, 3))) changes++;
    if (changes < 12) continue;
    const hash = crypto.createHash('sha256').update(row).digest('hex');
    if (found.has(hash)) found.set(hash, null);
    else found.set(hash, frame.y + y);
  }
  return found;
}

function movements(previous, current, beforeImage, afterImage) {
  const moved = [];
  const key = b => `${b.message}:${b.offset}:${b.start}`;
  const old = new Map(previous.blocks.map(b => [key(b), b]));
  for (const block of current.blocks) {
    const before = old.get(key(block));
    if (!before) continue;
    const dx = block.left - before.left;
    const dy = block.top - before.top;
    const rowMoves = [];
    if (block.right - block.left === before.right - before.left) {
      const a = rows(beforeImage, previous, before);
      const b = rows(afterImage, current, block);
      for (const [hash, from] of a) {
        const to = b.get(hash);
        if (from != null && to != null && from !== to) rowMoves.push({ from, to, dy: to - from });
      }
    }
    if (dx || dy || rowMoves.length) moved.push({ message: block.message, offset: block.offset, start: block.start, dx, dy, rows: rowMoves });
  }
  if (!current.blocks.some(b => old.has(key(b))) && previous.blocks.length && current.blocks.length) moved.push({ replacedViewport: true, before: previous.blocks[0], after: current.blocks[0] });
  return moved;
}

function replay(directory, phases) {
  const frames = parseFrames(fs.readFileSync(path.join(directory, 'frames.tsv'), 'utf8'));
  for (const frame of frames) image(directory, frame);
  const observations = [];
  for (const phase of phases) {
    if (!phase.end || phase.end - phase.start < 3000) throw new Error(`Incomplete observation ${phase.name}`);
    const samples = frames.filter(f => f.tick >= phase.start && f.tick <= phase.end && f.active === phase.shell);
    if (!samples.length || !samples.some(f => f.blocks.length && f.cache === phase.shell)) throw new Error(`Missing target paint for ${phase.name}`);
    const painted = samples.filter(f => f.blocks.length);
    if (!/^(open|switch)-/.test(phase.name)) {
      const prior = frames.findLast(f => f.tick < phase.start && f.active === phase.shell && f.blocks.length);
      if (!prior) throw new Error(`Missing pre-action frame for ${phase.name}`);
      painted.unshift(prior);
    }
    const moves = [];
    for (let i = 1; i < painted.length; i++) {
      const a = painted[i - 1];
      const b = painted[i];
      const changes = movements(a, b, image(directory, a), image(directory, b));
      if (changes.length) moves.push({ from: a.id, to: b.id, tick: b.tick, sinceFirstPaint: b.tick - painted[0].tick, scrollBefore: a.scroll, scrollAfter: b.scroll, changes });
    }
    const wrongSession = painted.filter(f => f.cache !== phase.shell).map(f => f.id);
    observations.push({ ...phase, paints: samples.map(f => f.id), first: painted[0].id, moves, wrongSession, status: phase.policy === 'stable' && (moves.length || wrongSession.length) ? 'failed' : 'passed' });
  }
  if (!observations.length) throw new Error('No user actions observed');
  return { status: observations.some(p => p.status === 'failed') ? 'failed' : 'passed', frameCount: frames.length, observations };
}

if (require.main === module && process.argv.length === 5) {
  const [directory, phases, output] = process.argv.slice(2);
  try {
    const result = replay(directory, JSON.parse(fs.readFileSync(phases, 'utf8').replace(/^\uFEFF/, '')));
    fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
    console.log(JSON.stringify({ status: result.status, frames: result.frameCount, movements: result.observations.map(p => ({ name: p.name, status: p.status, moved: p.moves.length })) }));
    if (result.status !== 'passed') process.exitCode = 1;
  } catch (error) {
    fs.writeFileSync(output, JSON.stringify({ status: 'incomplete', error: error.message }) + '\n');
    throw error;
  }
}
 else {
const { test } = require('node:test');
const assert = require('node:assert/strict');
const os = require('node:os');

test('SOFT-2557 real opening scroll keeps short content at the same screen position', { skip: process.env.GITHUB_ACTIONS !== 'true' }, t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'short-opening-scroll-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const source = fs.readFileSync(path.join(__dirname, '../../src/chat_history.zig'), 'utf8');
  const open = source.slice(source.indexOf('pub fn openScroll('), source.indexOf('pub const MISSING_RETRY_MS'));
  const native = `const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
${open}
test "short opening never bottom-aligns late history over already painted messages" {
    try std.testing.expectEqual(@as(i32, 0), openScroll(184, 556, 52, .{}, 0, null));
    try std.testing.expectEqual(@as(i32, 0), openScroll(364, 556, 52, .{}, 0, 0));
    try std.testing.expectEqual(@as(i32, 0), openScroll(668, 556, 52, .{}, 0, 0));
    try std.testing.expectEqual(@as(i32, 112), openScroll(668, 556, 52, .{}, 0, 900));
}
`;
  fs.writeFileSync(path.join(directory, 'test.zig'), native);
  const { spawnSync } = require('node:child_process');
  const result = spawnSync(process.env.ZIG_EXE || process.env.ZIG || 'zig', ['test', '-j1', 'test.zig'], { cwd: directory, encoding: 'utf8', timeout: 90000 });
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

function bitmap(width, height, textY) {
  const image = Buffer.alloc(54 + width * height * 4, 255);
  image.write('BM');
  image.writeInt32LE(width, 18);
  image.writeInt32LE(-height, 22);
  for (let x = 16; x < 40; x++) {
    const offset = 54 + (textY * width + x) * 4;
    image[offset] = x;
    image[offset + 1] = 0;
    image[offset + 2] = 0;
  }
  return image;
}
const block = { index: 0, message: '18446744073709551614', offset: '900', start: 0, length: 50, left: 0, top: 0, right: 80, bottom: 80 };
const first = { id: 1, tick: 100, active: 2, cache: 2, dirty: 1, scroll: 0, height: 1000, pad: 20, opening: 99, x: 0, y: 0, width: 80, viewport: 80, scrolledUp: 1, hold: 1, layouts: 1, blocks: [block] };
const second = { ...first, id: 2, tick: 180, dirty: 0, blocks: [block] };
const imageA = bitmap(80, 80, 20);
const imageB = bitmap(80, 80, 28);

test('detects a text line moving inside an unchanged first block', () => {
  const changed = movements(first, second, imageA, imageB);
  assert.equal(changed.length, 1);
  assert.equal(changed[0].message, '18446744073709551614');
  assert.equal(changed[0].dy, 0);
  assert.deepEqual(changed[0].rows, [{ from: 20, to: 28, dy: 8 }]);
});

test('checks lower visible messages when the first message stays still', () => {
  const lower = { ...block, message: '22', top: 30, bottom: 70 };
  const changes = movements({ ...first, blocks: [block, lower] }, { ...second, blocks: [block, { ...lower, top: 38, bottom: 78 }] }, imageA, imageA);
  assert.equal(changes.length, 1);
  assert.equal(changes[0].message, '22');
  assert.equal(changes[0].dy, 8);
});

function tsv(frame) {
  const header = ['frame', ...['id', 'tick', 'active', 'cache', 'dirty', 'scroll', 'height', 'pad', 'opening', 'x', 'y', 'width', 'viewport', 'scrolledUp', 'hold', 'layouts'].map(k => frame[k])].join('\t');
  const blocks = frame.blocks.map(b => ['block', frame.id, ...['index', 'message', 'offset', 'start', 'length', 'left', 'top', 'right', 'bottom'].map(k => b[k])].join('\t')).join('\n');
  return `${header}\n${blocks}\nend\t${frame.id}\t${frame.tick + 1}\n`;
}

test('retains unfinished frames instead of starting at content-ready', () => {
  assert.equal(parseFrames(tsv(first) + tsv(second))[0].dirty, 1);
  assert.throws(() => parseFrames(tsv(second)), /Missing or incomplete/);
  assert.throws(() => parseFrames(tsv(first).replace(/end\t.*/, '')), /incomplete/);
});

test('fails the dirty first paint movement and reports expected follow-bottom moves', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'position-proof-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, 'frames.tsv'), tsv(first) + tsv(second));
  fs.writeFileSync(path.join(directory, 'paint-000001.bmp'), imageA);
  fs.writeFileSync(path.join(directory, 'paint-000002.bmp'), imageB);
  const phase = { name: 'open-long-session', start: 99, end: 3200, shell: 2, policy: 'stable' };
  const result = replay(directory, [phase]);
  assert.equal(result.status, 'failed');
  assert.equal(result.observations[0].first, 1);
  assert.equal(result.observations[0].moves[0].sinceFirstPaint, 80);
  const follow = replay(directory, [{ ...phase, policy: 'follow-bottom' }]);
  assert.equal(follow.status, 'passed');
  assert.equal(follow.observations[0].moves.length, 1);
  fs.unlinkSync(path.join(directory, 'paint-000002.bmp'));
  assert.throws(() => replay(directory, [phase]), /ENOENT/);
});

test('fails stale session content even if the next target frame does not move', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'position-proof-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, 'frames.tsv'), tsv({ ...first, cache: 1 }) + tsv(second));
  fs.writeFileSync(path.join(directory, 'paint-000001.bmp'), imageA);
  fs.writeFileSync(path.join(directory, 'paint-000002.bmp'), imageA);
  const result = replay(directory, [{ name: 'switch-1', start: 99, end: 3200, shell: 2, policy: 'stable' }]);
  assert.equal(result.status, 'failed');
  assert.deepEqual(result.observations[0].wrongSession, [1]);
});

test('compares the first received paint with the actual pre-arrival frame', t => {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'position-proof-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  fs.writeFileSync(path.join(directory, 'frames.tsv'), tsv(first) + tsv(second));
  fs.writeFileSync(path.join(directory, 'paint-000001.bmp'), imageA);
  fs.writeFileSync(path.join(directory, 'paint-000002.bmp'), imageB);
  const result = replay(directory, [{ name: 'receive-while-reading', start: 150, end: 3200, shell: 2, policy: 'stable' }]);
  assert.equal(result.status, 'failed');
  assert.equal(result.observations[0].moves[0].from, 1);
  assert.equal(result.observations[0].moves[0].to, 2);
});

}
