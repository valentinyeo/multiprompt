import test from 'node:test';
import assert from 'node:assert/strict';
import { dots } from './chat-working-proof.mjs';

function frame(centers = [], fill = 200, radius = 3) {
  const image = { width: 200, height: 100, pixels: Buffer.alloc(200 * 100 * 4, 24) };
  for (const [cx, cy] of centers) for (let y = 0; y < 100; y++) for (let x = 0; x < 200; x++) {
    if ((x - cx) ** 2 + (y - cy) ** 2 > radius * radius) continue;
    const n = (y * 200 + x) * 4;
    image.pixels.fill(fill, n, n + 3);
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

test('small dim dots are still found', () => {
  const found = dots(frame([[20.5, 50.5], [28.5, 48.5], [36.5, 50.5]], 70, 2), area);
  assert.equal(found.length, 3);
});

test('Windows screenshot command accepts the driver UTF-8 BOM and rejects absent dots', async () => {
  const fs = await import('node:fs');
  const os = await import('node:os');
  const path = await import('node:path');
  const { spawnSync } = await import('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'inline-dots-'));
  try {
    const image = frame([[20, 48], [30, 50], [40, 50]]);
    const bmp = Buffer.alloc(54 + image.pixels.length);
    bmp.write('BM'); bmp.writeUInt32LE(bmp.length, 2); bmp.writeUInt32LE(54, 10);
    bmp.writeUInt32LE(40, 14); bmp.writeInt32LE(image.width, 18); bmp.writeInt32LE(-image.height, 22);
    bmp.writeUInt16LE(1, 26); bmp.writeUInt16LE(32, 28);
    image.pixels.copy(bmp, 54);
    const file = path.join(dir, 'frame.bmp'), json = path.join(dir, 'area.json'), out = path.join(dir, 'out.json');
    fs.writeFileSync(file, bmp);
    fs.writeFileSync(path.join(dir, 'out.png'), 'existing screenshot');
    fs.writeFileSync(json, '\uFEFF' + JSON.stringify(area));
    const run = () => spawnSync(process.execPath, ['tools/chat-working-proof.mjs', file, json, out, 'busy'], { encoding: 'utf8' });
    const visible = run();
    assert.equal(visible.status, 0, visible.stderr);
    assert.match(visible.stdout, /INLINE_DOTS_VISIBLE/);
    assert.equal(fs.readFileSync(path.join(dir, 'out.png'), 'utf8'), 'existing screenshot');
    frame().pixels.copy(bmp, 54); fs.writeFileSync(file, bmp);
    const absent = run();
    assert.notEqual(absent.status, 0);
    assert.match(absent.stderr, /IGSH-924 missing inline dots/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
