import test from 'node:test';
import assert from 'node:assert/strict';
import { noteBands } from './chat-notes-proof.mjs';

const frame = { scale: 1, transcript: { left: 10, top: 10, width: 380, height: 580 } };
function image(gap = 32, extra = 0, count = 5) {
  const width = 400;
  const height = 600;
  const pixels = Buffer.alloc(width * height * 4);
  for (let row = 0; row < count; row++) {
    const top = 30 + row * gap + (row > 0 ? extra : 0);
    for (let y = top; y < top + 8; y++) {
      for (let x = 40; x < 240; x += 3) pixels.writeUIntLE(0x787c84, (y * width + x) * 4, 3);
    }
  }
  return { width, height, pixels };
}

test('five compact dim rows are detected from painted pixels', () => {
  assert.equal(noteBands(image(), frame).rows.length, 5);
});
test('blank or missing runner rows cannot pass', () => {
  assert.throws(() => noteBands(image(32, 0, 0), frame), /five compact runner rows/);
  assert.throws(() => noteBands(image(32, 0, 4), frame), /five compact runner rows/);
});
test('tall messages fail the collapsed contract', () => {
  assert.throws(() => noteBands(image(80), frame), /full bubbles/);
});
test('expansion and collapse must change body space', () => {
  assert.throws(() => noteBands(image(), frame, true), /body disappeared/);
  assert.equal(noteBands(image(32, 220), frame, true).expanded, true);
  assert.throws(() => noteBands(image(32, 220), frame), /full bubbles/);
});
