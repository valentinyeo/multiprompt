const { test } = require('node:test');
const assert = require('node:assert/strict');

function scene(gap = 0) {
  const width = 200, height = 100;
  const underlay = { width, height, pixels: Buffer.alloc(width * height * 4) };
  const put = (image, x, y, color) => {
    const at = (y * width + x) * 4;
    for (let i = 0; i < 3; i++) image.pixels[at + i] = color;
  };
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) put(underlay, x, y, x % 7 < 3 && y % 5 < 2 ? 210 : 16);
  put(underlay, 0, 0, 16);
  const frame = { width, height, pixels: Buffer.from(underlay.pixels) };
  const metadata = { pill: { left: 65, top: 20, right: 135, bottom: 50 }, window: { left: 0, top: 0, right: width, bottom: height } };
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const cx = Math.max(80, Math.min(120, x + 0.5));
    const d = Math.hypot(x + 0.5 - cx, y + 0.5 - 35);
    if (d <= 15 + gap) put(frame, x, y, d <= 15 ? 48 : 16);
  }
  for (let y = 28; y < 41; y++) for (let x = 95; x < 104; x++) put(frame, x, y, 230);
  return { frame, underlay, metadata };
}

test('title pixel oracle accepts text around the actual pill shape', async () => {
  const { evaluateTitle } = await import('./title-pill-proof.mjs');
  const s = scene();
  const result = evaluateTitle(s.frame, s.underlay, s.metadata);
  assert.equal(result.changed, 0);
  for (const key of ['ringInk', 'leftInk', 'rightInk', 'titleInk']) assert.ok(result[key] > 20, key);
});

test('title pixel oracle rejects the real six-pixel clearing pattern', async () => {
  const { evaluateTitle } = await import('./title-pill-proof.mjs');
  const s = scene(6);
  assert.ok(evaluateTitle(s.frame, s.underlay, s.metadata).changed > 20);
});

test('title pixel oracle rejects unreadable text and invalid geometry', async () => {
  const { evaluateTitle } = await import('./title-pill-proof.mjs');
  const s = scene();
  for (let y = 28; y < 41; y++) for (let x = 95; x < 104; x++) {
    const at = (y * s.frame.width + x) * 4;
    s.frame.pixels.fill(48, at, at + 3);
  }
  assert.equal(evaluateTitle(s.frame, s.underlay, s.metadata).titleInk, 0);
  assert.throws(() => evaluateTitle(s.frame, s.underlay, { ...s.metadata, window: { ...s.metadata.window, right: 999 } }), /Invalid title geometry/);
});
