const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const load = () => import('./chat-code-font-proof.mjs');
const width = 120;
const height = 90;
const rows = { left: 10, top: 10, right: 110, bottom: 70 };
const code = { left: 10, top: 72, right: 110, bottom: 88 };
const directories = [];
test.after(() => {
  for (const directory of directories) fs.rmSync(directory, { recursive: true, force: true });
});

function bmp(paint) {
  const pixels = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const [r, g, b] = paint(x, y);
      const i = (y * width + x) * 4;
      pixels[i] = b;
      pixels[i + 1] = g;
      pixels[i + 2] = r;
      pixels[i + 3] = 255;
    }
  }
  const header = Buffer.alloc(54);
  header.write('BM', 0, 'latin1');
  header.writeUInt32LE(54 + pixels.length, 2);
  header.writeUInt32LE(54, 10);
  header.writeUInt32LE(40, 14);
  header.writeInt32LE(width, 18);
  header.writeInt32LE(-height, 22);
  header.writeUInt16LE(1, 26);
  header.writeUInt16LE(32, 28);
  return Buffer.concat([header, pixels]);
}

function rowPainter(smooth) {
  const backgrounds = [[28, 64, 40], [74, 32, 36], [36, 36, 36]];
  return (x, y) => {
    if (y < rows.top || y >= rows.bottom || x < rows.left || x >= rows.right) return [20, 20, 20];
    const background = backgrounds[Math.floor((y - rows.top) / 20)];
    const inRow = (y - rows.top) % 20;
    const column = (x - rows.left) % 8;
    if (inRow < 5 || inRow > 14 || column > 5) return background;
    const coverage = smooth && (column === 0 || column === 5) ? 0.5 : 1;
    return background.map(channel => Math.round(channel + (230 - channel) * coverage));
  };
}

function fixture(overrides = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh678-'));
  directories.push(directory);
  const base = { ticket: 'IGSH-678', width, height, face: 'Nordwand Mono MP SemiBold', code_em: 11, previous_code_em: 13, body_em: 14, diff_rows: rows, code, added_background: 0x28401c, removed_background: 0x24204a };
  const dwrite = { ...base, dwrite_enabled: true, diff_glyph_runs: 5, diff_fallback_runs: 0, code_glyph_runs: 3, code_fallback_runs: 0, ...overrides.dwrite };
  const gdi = { ...base, dwrite_enabled: false, diff_glyph_runs: 0, diff_fallback_runs: 5, code_glyph_runs: 0, code_fallback_runs: 3, ...overrides.gdi };
  fs.writeFileSync(path.join(directory, 'chat-code-proof-dwrite.json'), JSON.stringify(dwrite));
  fs.writeFileSync(path.join(directory, 'chat-code-proof-gdi.json'), JSON.stringify(gdi));
  fs.writeFileSync(path.join(directory, 'chat-code-proof-dwrite.bmp'), bmp(rowPainter(overrides.dwriteHard !== true)));
  fs.writeFileSync(path.join(directory, 'chat-code-proof-gdi.bmp'), bmp(rowPainter(false)));
  return directory;
}

test('IGSH-678 painter proof passes for Nordwand two points smaller with smooth DirectWrite diff rows and writes 4x crops', async () => {
  const { evaluate } = await load();
  const directory = fixture();
  const summary = evaluate(directory);
  assert.equal(summary.passed, true, JSON.stringify(summary, null, 2));
  assert.deepEqual(summary.checks.map(check => check.name), ['IGSH-678 painter code font', 'IGSH-678 painter diff rows on DirectWrite', 'IGSH-678 painter diff edges smoother than GDI']);
  const edges = summary.checks[2];
  assert.ok(edges.directWrite.hardEdgeFraction < edges.gdi.hardEdgeFraction);
  for (const file of ['chat-code-diff-4x.png', 'chat-code-diff-gdi-4x.png', 'chat-code-block-4x.png', 'chat-code-render.png', 'chat-code-render-gdi.png']) {
    const png = fs.readFileSync(path.join(directory, file));
    assert.equal(png.toString('latin1', 1, 4), 'PNG');
  }
  const crop = fs.readFileSync(path.join(directory, 'chat-code-diff-4x.png'));
  assert.equal(crop.readUInt32BE(16), (rows.right - rows.left) * 4);
  assert.equal(crop.readUInt32BE(20), (rows.bottom - rows.top) * 4);
});

test('IGSH-678 painter proof fails when diff rows fall back to GDI', async () => {
  const { evaluate } = await load();
  const summary = evaluate(fixture({ dwrite: { diff_fallback_runs: 3 } }));
  assert.equal(summary.passed, false);
  assert.equal(summary.checks.find(check => check.name === 'IGSH-678 painter diff rows on DirectWrite').passed, false);
});

test('IGSH-678 painter proof fails when DirectWrite edges are as hard as GDI', async () => {
  const { evaluate } = await load();
  const summary = evaluate(fixture({ dwriteHard: true }));
  assert.equal(summary.passed, false);
  assert.equal(summary.checks.find(check => check.name === 'IGSH-678 painter diff edges smoother than GDI').passed, false);
});

test('IGSH-678 painter proof fails on the previous size or another face', async () => {
  const { evaluate } = await load();
  assert.equal(evaluate(fixture({ dwrite: { code_em: 13 } })).checks[0].passed, false);
  assert.equal(evaluate(fixture({ dwrite: { face: 'Consolas' } })).checks[0].passed, false);
});
