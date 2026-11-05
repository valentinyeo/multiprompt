const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const root = path.resolve(__dirname, '..');

test('waiting and started echoes use their protocol phase for brightness', () => {
  const source = fs.readFileSync(path.join(root, 'src/chat_render.zig'), 'utf8');
  const match = source.match(/if \((e\.state == \.delivered[^\n]+)\) chatDimQueuedBubble\(hdc, bubble\);/);
  assert.ok(match);
  const expression = match[1]
    .replace('e.state == .delivered', "e.state === 'delivered'")
    .replace('!e.host_confirmed', '!e.host_confirmed')
    .replace('e.delivery_watch.removed_ms == 0', 'e.removed_ms === 0')
    .replace('!std.mem.eql(u8, std.mem.sliceTo(&e.message_phase, 0), "started")', "e.message_phase !== 'started'")
    .replaceAll(' and ', ' && ');
  const dim = new Function('e', `return ${expression};`);
  const echo = { state: 'delivered', host_confirmed: false, removed_ms: 0, message_phase: 'accepted' };
  assert.equal(dim(echo), true);
  assert.equal(dim({ ...echo, message_phase: 'started' }), false);
  assert.equal(dim({ ...echo, host_confirmed: true }), false);
  assert.equal(dim({ ...echo, removed_ms: 1 }), false);
});

test('pixel oracle rejects a missing or dim taken bubble', async () => {
  const { queuedBubble, normalBubble, countMessageBubbles, evaluateFrames } = await import(pathToFileURL(path.join(root, 'tools/chat-accepted-proof.mjs')));
  function image(fill, top) {
    const result = { width: 400, height: 220, pixels: Buffer.alloc(400 * 220 * 4, 24) };
    for (let y = top; y < top + 50; y++) for (let x = 180; x < 370; x++) {
      result.pixels.writeUIntLE(y > top + 15 && y < top + 30 && x % 3 === 0 ? 0xeeeeee : fill, (y * 400 + x) * 4, 3);
    }
    return result;
  }
  const area = { left: 0, right: 400, top: 0, bottom: 220 };
  const bubble = queuedBubble(image(0x323232, 50), area);
  assert.equal(normalBubble(image(0x323232, 50), bubble), false);
  assert.equal(normalBubble(image(0x4d4d4d, 90), bubble), false);
  assert.equal(normalBubble(image(0x4d4d4d, 50), bubble), true);
  const duplicate = image(0x4d4d4d, 50);
  const second = image(0x4d4d4d, 130);
  second.pixels.copy(duplicate.pixels, 130 * 400 * 4, 130 * 400 * 4, 180 * 400 * 4);
  assert.equal(countMessageBubbles(image(0x4d4d4d, 50), area, bubble), 1);
  assert.equal(countMessageBubbles(duplicate, area, bubble), 2);
  const dimDuplicate = image(0x323232, 130);
  dimDuplicate.pixels.copy(duplicate.pixels, 130 * 400 * 4, 130 * 400 * 4, 180 * 400 * 4);
  assert.equal(countMessageBubbles(duplicate, area, bubble), 2);
  const frames = [{ ms: 1050, normal: false, dots: true }, { ms: 1200, normal: true, dots: true }];
  assert.equal(evaluateFrames(frames, 1000), 200);
  assert.throws(() => evaluateFrames([{ ms: 2100, normal: true, dots: true }], 1000));
  assert.throws(() => evaluateFrames([{ ms: 1200, normal: true, dots: false }], 1000));
});
