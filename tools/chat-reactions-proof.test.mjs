import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import { inspect, assertBadge } from './chat-reactions-proof.mjs';
import * as proof from './chat-reactions-proof.mjs';

const area = { left: 0, top: 0, right: 300, bottom: 300 };
function fixture() {
  const image = { width: 300, height: 300, pixels: Buffer.alloc(300 * 300 * 4) };
  const fill = (left, top, right, bottom, color) => {
    for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) image.pixels.writeUIntLE(color, (y * 300 + x) * 4, 3);
  };
  fill(0, 0, 300, 300, 0x202020);
  fill(20, 10, 250, 45, 0x555555);
  fill(20, 60, 250, 150, 0x444444);
  fill(20, 165, 250, 230, 0x444444);
  fill(28, 120, 68, 142, 0x585858);
  fill(42, 126, 53, 136, 0xffffff);
  return { image, fill };
}

test('real filled badge inside the first reply accepted', () => {
  assertBadge(inspect(fixture().image, area));
});
for (const [name, mutate] of [
  ['missing badge', f => f.fill(28, 120, 68, 142, 0x444444)],
  ['empty painted pill', f => f.fill(42, 126, 53, 136, 0x585858)],
  ['badge moved to second same-prefix reply', f => { f.fill(28, 120, 68, 142, 0x444444); f.fill(28, 205, 68, 227, 0x585858); f.fill(42, 211, 53, 221, 0xffffff); }],
  ['extra assistant reaction answer', f => f.fill(20, 245, 250, 280, 0x444444)],
  ['extra normal reaction bubble', f => f.fill(20, 245, 250, 280, 0x555555)],
  ['extra pending reaction bubble', f => f.fill(20, 245, 250, 280, 0x3a3a3a)],
]) test(`reject ${name}`, () => {
  const f = fixture(); mutate(f);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});


test('gradient fills remain one bubble; shared pill shade does not split user rows', () => {
  const f = fixture();
  for (const [top, bottom, base] of [[10, 45, 53], [60, 150, 36], [165, 230, 36]]) {
    for (let step = 0; step < 8; step++) {
      const shade = 32 + base + 8 - Math.trunc(8 * step / 7);
      f.fill(20, top + Math.trunc((bottom - top) * step / 8), 250, top + Math.trunc((bottom - top) * (step + 1) / 8), shade * 0x010101);
    }
  }
  f.fill(28, 120, 68, 142, 0x585858);
  f.fill(42, 126, 53, 136, 0xffffff);
  assertBadge(inspect(f.image, area));
});

test('rounded-edge shades cannot substitute for a painted badge glyph', () => {
  const f = fixture();
  f.fill(42, 126, 53, 136, 0x585858);
  f.fill(28, 120, 31, 142, 0x484848);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});


test('small composer buttons overlapping the transcript are not queued reaction bubbles', () => {
  const f = fixture();
  f.fill(260, 245, 291, 276, 0x414141);
  assertBadge(inspect(f.image, area));
});

test('approved reader colours identify assistant replies, not the user or composer buttons', () => {
  const f = fixture();
  f.fill(0, 0, 300, 300, 0x101010);
  f.fill(120, 0, 220, 10, 0x1e1e1e);
  f.fill(0, 285, 300, 300, 0x1e1e1e);
  f.fill(20, 10, 250, 45, 0x3a3a3a);
  f.fill(20, 60, 250, 150, 0x1e1e1e);
  f.fill(20, 165, 250, 230, 0x1e1e1e);
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  f.fill(260, 245, 291, 276, 0x3a3a3a);
  const frame = inspect(f.image, area);
  assert.deepEqual(frame.agent.map(row => row.top), [60, 165]);
  assertBadge(frame);
  f.fill(20, 245, 250, 280, 0x1e1e1e);
  assert.throws(() => assertBadge(inspect(f.image, area)), assert.AssertionError);
});

test('reject a detached badge below its message', () => {
  const f = fixture();
  f.fill(20, 116, 250, 150, 0x202020);
  f.fill(28, 120, 68, 142, 0x585858);
  f.fill(42, 126, 53, 136, 0xffffff);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});

test('approved reader colors still identify the enclosed reaction', () => {
  const f = fixture();
  f.fill(0, 0, 300, 300, 0x101010);
  f.fill(20, 10, 250, 45, 0x3a3a3a);
  f.fill(20, 60, 250, 150, 0x1e1e1e);
  f.fill(20, 165, 250, 230, 0x1e1e1e);
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  assertBadge(inspect(f.image, area));
});

test('floating title is not the first reply after the setup prompt', () => {
  const f = fixture();
  f.fill(200, 5, 296, 40, 0x444444);
  const frame = inspect(f.image, area);
  assert.equal(frame.agent.length, 2);
  assert.equal(frame.agent[0].top, 60);
  assertBadge(frame);
});

test('native three-dot more glyph is visible; a missing glyph still fails', () => {
  assert.equal(typeof proof.assertHoverActions, 'function');
  const image = { width: 400, height: 200, pixels: Buffer.alloc(400 * 200 * 4) };
  const ink = (x, y) => image.pixels.writeUIntLE(0x8a8a8a, (y * image.width + x) * 4, 3);
  for (const x of [262, 290]) for (let dx = 0; dx < 2; dx++) for (let dy = 0; dy < 4; dy++) ink(x + dx, 130 + dy);
  for (const x of [320, 323, 326]) { ink(x, 136); ink(x, 137); }
  const first = { left: 20, right: 250, bottom: 150 };
  assert.equal(proof.assertHoverActions(image, first).moreX, 326);
  for (const x of [320, 323, 326]) for (const y of [136, 137]) image.pixels.writeUIntLE(0, (y * image.width + x) * 4, 3);
  assert.throws(() => proof.assertHoverActions(image, first), /hover action 2 is painted/);
});


test('reaction proof measures the painted transcript, excluding the floating composer', () => {
  const driver = fs.readFileSync(new URL('./verify-chat-delivery/reactions.ps1', import.meta.url), 'utf8');
  assert.match(driver, /frame transcript/);
  assert.match(driver, /ScreenPoint\(\$main, 0, 0\)/);
  assert.match(driver, /Save \$area "\$caseDir\/area.json"/);
  const f = fixture();
  f.fill(20, 245, 250, 280, 0x444444);
  assert.throws(() => assertBadge(inspect(f.image, area)));
  assertBadge(inspect(f.image, { ...area, bottom: 235 }));
});
