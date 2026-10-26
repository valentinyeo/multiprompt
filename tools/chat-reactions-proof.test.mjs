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
  fill(20, 60, 250, 116, 0x444444);
  fill(20, 165, 250, 230, 0x444444);
  fill(28, 120, 68, 142, 0x585858);
  fill(42, 126, 53, 136, 0xffffff);
  return { image, fill };
}

test('real filled badge attached below the first reply accepted', () => {
  assertBadge(inspect(fixture().image, area));
});
for (const [name, mutate] of [
  ['missing badge', f => f.fill(28, 120, 68, 142, 0x444444)],
  ['empty painted pill', f => f.fill(42, 126, 53, 136, 0x585858)],
  ['badge moved to second same-prefix reply', f => { f.fill(28, 120, 68, 142, 0x444444); f.fill(28, 205, 68, 227, 0x585858); f.fill(42, 211, 53, 221, 0xffffff); }],
  ['extra normal reaction bubble', f => f.fill(20, 245, 250, 280, 0x555555)],
  ['extra pending reaction bubble', f => f.fill(20, 245, 250, 280, 0x3a3a3a)],
]) test(`reject ${name}`, () => {
  const f = fixture(); mutate(f);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});


test('gradient fills remain one bubble; shared pill shade does not split user rows', () => {
  const f = fixture();
  for (const [top, bottom, base] of [[10, 45, 53], [60, 116, 36], [165, 230, 36]]) {
    for (let step = 0; step < 8; step++) {
      const shade = 32 + base + 8 - Math.trunc(8 * step / 7);
      f.fill(20, top + Math.trunc((bottom - top) * step / 8), 250, top + Math.trunc((bottom - top) * (step + 1) / 8), shade * 0x010101);
    }
  }
  assertBadge(inspect(f.image, area));
});

test('rounded-edge shades cannot substitute for a painted badge glyph', () => {
  const f = fixture();
  f.fill(42, 126, 53, 136, 0x585858);
  f.fill(28, 120, 31, 142, 0x484848);
  assert.throws(() => assertBadge(inspect(f.image, area)));
});
