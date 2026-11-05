import test from 'node:test';
import assert from 'node:assert/strict';
import { queuedBubble, normalBubble, evaluateFrames } from './chat-accepted-proof.mjs';

function frame(fill = 0x4d4d4d) {
  const image = { width: 400, height: 200, pixels: Buffer.alloc(400 * 200 * 4, 24) };
  for (let y = 50; y < 100; y++) for (let x = 180; x < 370; x++) {
    image.pixels.writeUIntLE(y > 65 && y < 80 && x % 3 === 0 ? 0xeeeeee : fill, (y * 400 + x) * 4, 3);
  }
  return image;
}
const area = { left: 0, right: 400, top: 0, bottom: 200 };
test('queued pixels already have normal fill and readable text', () => {
  const bubble = queuedBubble(frame(), area);
  assert.equal(normalBubble(frame(), bubble), true);
  assert.equal(normalBubble(frame(0x323232), bubble), false);
  assert.throws(() => queuedBubble(frame(0x323232), area), /normal bubble/);
  assert.throws(() => queuedBubble(frame(0x181818), area), /normal bubble/);
  const blank = frame(0x4d4d4d);
  for (let y = 50; y < 100; y++) for (let x = 180; x < 370; x++) blank.pixels.writeUIntLE(0x4d4d4d, (y * 400 + x) * 4, 3);
  assert.equal(normalBubble(blank, bubble), false);
});
test('every frame stays normal with working dots and acceptance is observed promptly', () => {
  const frames = [{ ms: 900, normal: true, dots: true }, { ms: 1100, normal: true, dots: true }, { ms: 1600, normal: true, dots: true }];
  assert.equal(evaluateFrames(frames, 1000), 100);
  assert.throws(() => evaluateFrames([{ ...frames[0], normal: false }, ...frames.slice(1)], 1000), /normal in every frame/);
  assert.throws(() => evaluateFrames([...frames, { ms: 1800, normal: false, dots: true }], 1000), /normal in every frame/);
  assert.throws(() => evaluateFrames(frames.map(f => ({ ...f, ms: f.ms + 2000 })), 1000), /within one second/);
  assert.throws(() => evaluateFrames([{ ...frames[0], dots: false }, ...frames.slice(1)], 1000), /working dots/);
  assert.throws(() => evaluateFrames(frames, NaN), /timestamp/);
  assert.throws(() => evaluateFrames([], 1000), /within one second/);
});
