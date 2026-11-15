const test = require('node:test');
const assert = require('node:assert/strict');
const { discoverFeatures } = require('./verify-features.cjs');
const { validateSelection } = require('./pr-verifier.cjs');

test('SOFT-2441 the PR verifier can select the reaction emoji journey', () => {
  const available = discoverFeatures().available;
  assert.ok(available.includes('reaction-emoji'));
  assert.deepEqual(validateSelection({ features: ['reaction-emoji'], compare_base: true }, available).features, ['reaction-emoji']);
});

function image(emojiSize = 14, color = 0xffcc4d, target = 'both') {
  const width = 140, height = 60;
  const pixels = Buffer.alloc(width * height * 4);
  const fill = (left, top, w, h, value) => {
    for (let y = top; y < top + h; y++) for (let x = left; x < left + w; x++) pixels.writeUInt32LE(value, (y * width + x) * 4);
  };
  for (const [name, left] of [['reaction', 10], ['react', 62]]) {
    const change = target === 'both' || target === name;
    fill(left, 20, change ? emojiSize : 14, change ? emojiSize : 14, change ? color : 0xffcc4d);
  }
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

for (const target of ['reaction', 'react']) {
  for (const [name, size, color] of [['tiny', 7, 0xffcc4d], ['monochrome', 14, 0xcccccc], ['missing', 0, 0xffcc4d]]) {
    test(`SOFT-2441 rejects ${name} ${target} emoji independently`, async () => {
      const { assertEmojiPixels } = await import('./reaction-emoji-pixels.mjs');
      assert.throws(() => assertEmojiPixels(image(size, color, target), geometry), new RegExp(`${target} must be a full-size colour`));
    });
  }
}

test('SOFT-2441 reply and more controls must remain visible', async () => {
  const { assertEmojiPixels } = await import('./reaction-emoji-pixels.mjs');
  const frame = image();
  for (let y = 0; y < frame.height; y++) frame.pixels.fill(0, (y * frame.width + 90) * 4, (y * frame.width + frame.width) * 4);
  assert.throws(() => assertEmojiPixels(frame, geometry), /reply.*more/);
});
