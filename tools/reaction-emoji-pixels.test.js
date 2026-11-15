const test = require('node:test');
const assert = require('node:assert/strict');

function image(emojiSize = 14, color = 0xffcc4d) {
  const width = 140, height = 60;
  const pixels = Buffer.alloc(width * height * 4);
  const fill = (left, top, w, h, value) => {
    for (let y = top; y < top + h; y++) for (let x = left; x < left + w; x++) pixels.writeUInt32LE(value, (y * width + x) * 4);
  };
  for (const left of [10, 62]) fill(left, 20, emojiSize, emojiSize, color);
  fill(96, 25, 8, 3, 0x777777);
  fill(124, 25, 4, 2, 0x777777);
  return { width, height, pixels };
}

const geometry = {
  bodyEm: 14,
  pill: { left: 4, top: 14, right: 34, bottom: 42 },
  actions: { left: 56, top: 14, right: 140, bottom: 42 },
};

test('SOFT-2441 full-size colour reactions and hover emoji pass', async () => {
  const { assertEmojiPixels } = await import('./reaction-emoji-pixels.mjs');
  const result = assertEmojiPixels(image(), geometry);
  assert.equal(result.reaction.height, 14);
  assert.equal(result.react.height, 14);
});

for (const [name, size, color] of [['tiny', 7, 0xffcc4d], ['monochrome', 14, 0xcccccc], ['missing', 0, 0xffcc4d]]) {
  test(`SOFT-2441 rejects ${name} reaction or react emoji`, async () => {
    const { assertEmojiPixels } = await import('./reaction-emoji-pixels.mjs');
    assert.throws(() => assertEmojiPixels(image(size, color), geometry), /full-size colour/);
  });
}

test('SOFT-2441 reply and more controls must remain visible', async () => {
  const { assertEmojiPixels } = await import('./reaction-emoji-pixels.mjs');
  const frame = image();
  for (let y = 0; y < frame.height; y++) frame.pixels.fill(0, (y * frame.width + 90) * 4, (y * frame.width + frame.width) * 4);
  assert.throws(() => assertEmojiPixels(frame, geometry), /reply.*more/);
});
