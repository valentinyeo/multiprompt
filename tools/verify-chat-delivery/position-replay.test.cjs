const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parseFrames, movements, replay } = require('./position-replay.cjs');

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
