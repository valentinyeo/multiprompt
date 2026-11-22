import test from 'node:test';
import assert from 'node:assert/strict';
import { measureStatus } from './chat-sending-status-proof.mjs';

function frame(status = false, blank = false) {
  const image = { width: 400, height: 240, pixels: Buffer.alloc(400 * 240 * 4) };
  const paint = (x, y, color) => image.pixels.writeUIntLE(color, (y * 400 + x) * 4, 3);
  for (let y = 0; y < 240; y++) for (let x = 0; x < 400; x++) paint(x, y, 0x181818);
  if (!blank) {
    for (let y = 30; y < 90; y++) for (let x = 180; x < 376; x++) paint(x, y, 0x4d4d4d);
    for (let y = 58; y < 72; y++) for (let x = 200; x < 350; x += 3) paint(x, y, 0xeeeeee);
  }
  if (status) for (let x = 280; x < 370; x++) paint(x, 100, 0xaaaaaa);
  return image;
}
const rect = { left: 0, top: 0, width: 400, height: 240 };
test('normal sent bubble has no status ink', () => assert.equal(measureStatus(frame(), rect).statusInk, 0));
test('old sending clock or any status ink fails', () => assert.throws(() => measureStatus(frame(true), rect), /IGSH-931 ordinary message status/));
test('blank capture cannot prove removal', () => assert.throws(() => measureStatus(frame(false, true), rect), /outgoing bubble/));
test('bubble without text cannot prove a message', () => {
  const image = frame();
  for (let y = 30; y < 90; y++) for (let x = 180; x < 376; x++) image.pixels.writeUIntLE(0x4d4d4d, (y * 400 + x) * 4, 3);
  assert.throws(() => measureStatus(image, rect), /message text/);
});

test('delivered queued bubble is measured at its existing half opacity', () => {
  const image = frame();
  for (let y = 30; y < 90; y++) for (let x = 180; x < 376; x++) {
    const offset = (y * 400 + x) * 4;
    if (image.pixels.readUIntLE(offset, 3) === 0x4d4d4d) image.pixels.writeUIntLE(0x323232, offset, 3);
  }
  assert.equal(measureStatus(image, rect, true).statusInk, 0);
  assert.throws(() => measureStatus(image, rect), /outgoing bubble/);
});

test('bottom-pinned bubble can end at the viewport edge', () => {
  const image = frame();
  image.pixels.copy(image.pixels, 30 * image.width * 4, 0, 210 * image.width * 4);
  assert.equal(measureStatus(image, { ...rect, height: 120 }).statusInk, 0);
});
