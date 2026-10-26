import { test } from 'node:test';
import assert from 'node:assert/strict';
import { measure } from './chat-skill-pill-proof.mjs';

function image(accent, fill, text = true, background = true) {
  const width = 80;
  const height = 30;
  const pixels = Buffer.alloc(width * height * 4, 24);
  for (let y = 8; y < 22; y++) {
    for (let x = 8; x < 65; x++) {
      const rgb = text && y >= 12 && y < 18 && x < 40 ? accent : background ? fill : [24, 24, 24];
      const i = (y * width + x) * 4;
      pixels.set([rgb[2], rgb[1], rgb[0], 255], i);
    }
  }
  return { width, height, pixels };
}
const rect = { left: 0, top: 0, right: 80, bottom: 30 };
for (const [theme, accent, fill] of [['dark', [110, 175, 245], [65, 74, 84]], ['light', [30, 90, 170], [201, 209, 221]]]) {
  test(`${theme} requires both contrasting text and soft pill background`, () => {
    assert.equal(measure(image(accent, fill), rect, accent).pill, true);
    assert.equal(measure(image(accent, fill, false), rect, accent).pill, false);
    assert.equal(measure(image(accent, fill, true, false), rect, accent).pill, false);
    assert.equal(measure(image(accent, fill, false, false), rect, accent).pill, false);
  });
}
test('rejects invalid or unrelated control bounds', () => {
  const frame = image([110, 175, 245], [65, 74, 84]);
  for (const bad of [{ ...rect, left: -1 }, { ...rect, right: 81 }, { ...rect, top: 0.5 }, { ...rect, bottom: 0 }]) assert.throws(() => measure(frame, bad, [110, 175, 245]));
  assert.equal(measure(frame, { left: 66, top: 0, right: 80, bottom: 30 }, [110, 175, 245]).pill, false);
});
