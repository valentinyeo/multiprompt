import assert from 'node:assert/strict';
import { test } from 'node:test';
import { inspect, assertBadge } from './chat-reactions-proof.mjs';

const area = { left: 0, top: 0, right: 300, bottom: 300 };
function fixture() {
  const image = { width: 300, height: 300, pixels: Buffer.alloc(300 * 300 * 4) };
  const fill = (left, top, right, bottom, color) => {
    for (let y = top; y < bottom; y++) for (let x = left; x < right; x++) image.pixels.writeUIntLE(color, (y * 300 + x) * 4, 3);
  };
  fill(0, 0, 300, 300, 0x202020);
  fill(20, 10, 250, 45, 0x555555);
  fill(20, 60, 250, 148, 0x444444);
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
  for (const [top, bottom, base] of [[10, 45, 53], [60, 148, 36], [165, 230, 36]]) {
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
  f.fill(20, 60, 250, 148, 0x1e1e1e);
  f.fill(20, 165, 250, 230, 0x1e1e1e);
  f.fill(28, 120, 68, 142, 0x323232);
  f.fill(42, 126, 53, 136, 0xffffff);
  f.fill(260, 245, 291, 276, 0x3a3a3a);
  const frame = inspect(f.image, area);
  assert.deepEqual(frame.agent.map(row => row.top), [60, 165]);
  assertBadge(frame);
  f.fill(20, 245, 250, 280, 0x1e1e1e);
  assert.throws(() => assertBadge(inspect(f.image, area)), assert.AssertionError);
});

test('badge outside the reply is rejected; approved grey badge inside is accepted', () => {
  const f = fixture();
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  assertBadge(inspect(f.image, area));
  f.fill(20, 116, 250, 148, 0x202020);
  f.fill(28, 120, 68, 142, 0x353535);
  f.fill(42, 126, 53, 136, 0xffffff);
  assert.throws(() => assertBadge(inspect(f.image, area)), assert.AssertionError);
});

test('growth proof rejects missing code, wrong reaction target and empty badges', async () => {
  const fs = await import('node:fs');
  assert.ok(fs.existsSync(new URL('./chat-popup-growth-proof.mjs', import.meta.url)), 'growth proof must ship with the menu');
  const { assertSecondBadge, assertPaintedGrowth } = await import('./chat-popup-growth-proof.mjs');
  const second = { left: 20, top: 190, right: 250, bottom: 280, ink: 100 };
  const frame = { agent: [{ left: 20, top: 50, right: 250, bottom: 100, ink: 50 }, { left: 20, top: 110, right: 250, bottom: 180, ink: 100 }, second], user: [{}], dim: [], pill: [{left: 28, top: 250, right: 68, bottom: 272, ink: 30}] };
  assertSecondBadge(frame);
  for (const mutate of [f => { f.pill[0].ink = 0; }, f => { f.pill[0].top = 70; f.pill[0].bottom = 92; }, f => f.agent.splice(1, 1), f => f.user.push({}), f => f.dim.push({})]) {
    const bad = structuredClone(frame); mutate(bad);
    assert.throws(() => assertSecondBadge(bad), assert.AssertionError);
  }
  const f = fixture();
  f.fill(28, 120, 68, 142, 0x444444);
  assert.throws(() => assertPaintedGrowth(f.image, f.image, area, {left: 80, top: 230, right: 280, bottom: 290}), assert.AssertionError);
});
