import test from 'node:test';
import assert from 'node:assert/strict';
import { dots } from './chat-working-proof.mjs';

function frame(centers = []) {
  const image = { width: 200, height: 100, pixels: Buffer.alloc(200 * 100 * 4, 24) };
  for (const [cx, cy] of centers) for (let y = 0; y < 100; y++) for (let x = 0; x < 200; x++) {
    if ((x - cx) ** 2 + (y - cy) ** 2 > 9) continue;
    const n = (y * 200 + x) * 4;
    image.pixels.fill(200, n, n + 3);
  }
  return image;
}
const area = { left: 0, top: 0, right: 200, bottom: 100 };
test('visible three-dot frames are distinguished from idle, one dot and separated text', () => {
  assert.equal(dots(frame(), area), null);
  assert.equal(dots(frame([[20, 50]]), area), null);
  assert.equal(dots(frame([[20, 50], [30, 50]]), area), null);
  assert.equal(dots(frame([[20, 50], [45, 50], [70, 50]]), area), null);
  assert.equal(dots(frame([[20, 20], [30, 40], [40, 60]]), area), null);
  const first = dots(frame([[20, 48], [30, 50], [40, 50]]), area);
  const second = dots(frame([[20, 50], [30, 48], [40, 50]]), area);
  assert.equal(first.length, 3);
  assert.notDeepEqual(first, second);
  assert.throws(() => dots(frame(), { ...area, right: 201 }), /Invalid transcript/);
});
