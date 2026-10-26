import test from 'node:test';
import assert from 'node:assert/strict';
import { queuedBubble, normalBubble, evaluateFrames } from './chat-accepted-proof.mjs';

function frame(fill = 0x323232) {
  const image = { width: 400, height: 200, pixels: Buffer.alloc(400 * 200 * 4, 24) };
  for (let y = 50; y < 100; y++) for (let x = 180; x < 370; x++) {
    image.pixels.writeUIntLE(y > 65 && y < 80 && x % 3 === 0 ? 0xeeeeee : fill, (y * 400 + x) * 4, 3);
  }
  return image;
}
const area = { left: 0, right: 400, top: 0, bottom: 200 };
test('queued pixels stay dim; accepted pixels retain text at normal brightness', () => {
  const bubble = queuedBubble(frame(), area);
  assert.equal(normalBubble(frame(), bubble), false);
  assert.equal(normalBubble(frame(0x4d4d4d), bubble), true);
  assert.throws(() => queuedBubble(frame(0x181818), area), /visibly dimmed/);
  const blank = frame(0x4d4d4d);
  for (let y = 50; y < 100; y++) for (let x = 180; x < 370; x++) blank.pixels.writeUIntLE(0x4d4d4d, (y * 400 + x) * 4, 3);
  assert.equal(normalBubble(blank, bubble), false);
});
test('acceptance requires normal brightness within one second, together with working dots', () => {
  const frames = [{ ms: 1100, normal: false, dots: true }, { ms: 1400, normal: true, dots: true }, { ms: 1600, normal: true, dots: true }];
  assert.equal(evaluateFrames(frames, 1000), 400);
  assert.throws(() => evaluateFrames(frames.map(f => ({ ...f, normal: false })), 1000), /remains dimmed/);
  assert.throws(() => evaluateFrames(frames.map(f => ({ ...f, ms: f.ms + 1001 })), 1000), /over one second/);
  assert.throws(() => evaluateFrames(frames.map(f => ({ ...f, dots: false })), 1000), /working dots/);
  assert.throws(() => evaluateFrames([...frames, { ms: 1800, normal: false, dots: true }], 1000), /dimmed again/);
});
