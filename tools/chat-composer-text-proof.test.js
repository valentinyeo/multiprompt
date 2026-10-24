const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function image(smooth, empty = false, hardGlyphs = 0) {
  const width = 300;
  const height = 24;
  const pixels = Buffer.alloc(width * height * 4, 255);
  if (!empty) for (let y = 4; y < 20; y++) for (let x = 4; x < 296; x++) {
    const column = x % 8;
    if (column > 4) continue;
    const hard = (y - 4) * 37 + Math.floor(x / 8) < hardGlyphs;
    const value = smooth && !hard && (column === 0 || column === 4) ? 128 : 0;
    const i = (y * width + x) * 4;
    pixels[i] = pixels[i + 1] = pixels[i + 2] = value;
  }
  return { width, height, pixels };
}

const metadata = { fontSmoothing: false, rect: { left: 0, top: 0, right: 300, bottom: 24 } };

test('IGSH-731 live oracle accepts smooth glyphs and rejects aliased red control without weakening threshold', async () => {
  const { evaluateLive, threshold } = await import('./chat-composer-text-proof.mjs');
  assert.equal(threshold, 0.18);
  const smooth = evaluateLive(image(true), metadata);
  const hard = evaluateLive(image(false), metadata);
  assert.equal(smooth.passed, true);
  assert.equal(hard.passed, false);
  assert.ok(smooth.measurement.hardEdgeFraction < hard.measurement.hardEdgeFraction);
  assert.equal(evaluateLive(image(true), { ...metadata, fontSmoothing: true }).passed, false);
  assert.equal(evaluateLive(image(true, true), metadata).passed, false);
  assert.throws(() => evaluateLive(image(true), { ...metadata, rect: { ...metadata.rect, right: 301 } }), /rectangle/);
});

test('IGSH-731 source connects native EDIT geometry, hidden native ink, repaint and DirectWrite cache', () => {
  const painter = read('src/chat_composer_text.zig');
  const composer = read('src/chat_composer.zig');
  const main = read('src/main.zig');
  const dwrite = read('src/dwrite_text.zig');
  for (const token of ['0x00D6', '0x00B0', '0x00CE', '0x00BB', 'GetSysColor(13)', 'GetSysColor(14)', 'HideCaret(hwnd)', 'ShowCaret(hwnd)', 'drawPositioned', '0x010D...0x010F']) assert.ok(painter.includes(token), token);
  assert.ok(main.includes('SetTextColor(dc, if (@import("chat_composer_text.zig").enabled() and !@import("chat_composer_text.zig").native_paint) app_state.g_chat_input_color else customColorOr("text", themeConsoleFg()))'));
  assert.match(composer, /defer @import\("chat_composer_text.zig"\).invalidateAfter\(hwnd, msg\)/);
  assert.match(composer, /chat_composer_text.zig"\).paint\(hwnd, dc/);
  const api = dwrite.slice(dwrite.indexOf('pub fn drawPositioned'), dwrite.indexOf('\nfn paint('));
  for (const token of ['fontFace(hdc)', 'ensureTarget(', 'drawGlyphRun', 'params.?', 'advances']) assert.ok(api.includes(token), token);
  assert.doesNotMatch(api, /max_units|enabled\(\)/);
  assert.match(painter, /switch defaults on and only zero/);
});

test('IGSH-731 Windows proof uses production painter and every scale/DPI with the real native fallback', () => {
  const proof = read('src/chat_composer_text_proof.zig');
  assert.match(read('src/chat_composer_text.zig'), /@import\("chat_composer_text_proof.zig"\)/);
  for (const token of ['100, 125, 150', '96, 120, 144', 'ensureChatFont()', 'painter.paint(edit, dc', '0x0318', 'IGSH_731', 'try std.testing.expect(measurements[1].hardEdgeFraction < measurements[0].hardEdgeFraction);', 'try std.testing.expect(measurements[1].hardEdgeFraction <= 0.15);', 'try std.testing.expect(measurements[1].partialPixels > 0);', 'composer-{d}-{d}-{s}.bmp', 'composer-{d}-{d}-{s}.json']) assert.ok(proof.includes(token), token);
  const workflow = read('.github/workflows/verify.yml');
  const control = read('.claude/skills/verify-multiprompt/control.ps1');
  assert.ok(workflow.includes("'chat-composer-text'"));
  assert.ok(workflow.includes('node tools/chat-composer-text-proof.mjs evidence --native'));
  assert.ok(control.indexOf('[VerifyNative]::FontSmoothing($false)') < control.indexOf('$bytes = [IO.File]::ReadAllBytes($Exe)'));
  assert.ok(control.includes('[VerifyNative]::FontSmoothing([bool]$originalFontSmoothing)'));
  assert.match(control, /'chat-composer-text' \{[\s\S]*?Alt\+C[\s\S]*?Assert-ChatTyping \$sentence[\s\S]*?composerCheck.measurement = \$summary.measurement/);
  assert.ok(read('.claude/skills/verify-multiprompt/features/README.md').includes('chat-composer-text.md'));
  assert.ok(read('.claude/skills/verify-multiprompt/features/chat-composer-text.md').includes('v0.28.858'));
});

test('IGSH-731 native oracle remeasures all nine image pairs and rejects hard or forged evidence', async () => {
  const os = require('node:os');
  const { evaluateNative } = await import('./chat-composer-text-proof.mjs');
  const { edgeHardness } = await import('./chat-code-font-proof.mjs');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'composer-edge-oracle-'));
  const write = (scale, dpi, mode, smooth, hardGlyphs = 0) => {
    const sample = image(smooth, false, hardGlyphs);
    const header = Buffer.alloc(54);
    header.write('BM');
    header.writeUInt32LE(54 + sample.pixels.length, 2);
    header.writeUInt32LE(54, 10);
    header.writeUInt32LE(40, 14);
    header.writeInt32LE(sample.width, 18);
    header.writeInt32LE(-sample.height, 22);
    header.writeUInt16LE(1, 26);
    header.writeUInt16LE(32, 28);
    const stem = path.join(directory, `composer-${scale}-${dpi}-${mode}`);
    fs.writeFileSync(`${stem}.bmp`, Buffer.concat([header, sample.pixels]));
    fs.writeFileSync(`${stem}.json`, JSON.stringify({ ticket: 'IGSH-731', ui_scale: scale, dpi, direct_write: mode === 'dwrite', font_smoothing: false, font_px: 16, measurement: edgeHardness(sample, metadata.rect, 1) }));
  };
  try {
    for (const scale of [100, 125, 150]) for (const dpi of [96, 120, 144]) for (const mode of ['gdi', 'dwrite']) write(scale, dpi, mode, mode === 'dwrite');
    const accepted = evaluateNative(directory);
    assert.equal(accepted.passed, true);
    assert.equal(accepted.checks.length, 9);
    write(125, 120, 'gdi', true, 80);
    write(125, 120, 'dwrite', true, 70);
    const smallImprovement = evaluateNative(directory);
    assert.equal(smallImprovement.passed, true);
    const pair = smallImprovement.checks.find(check => check.gdi.measurement.hardEdgeFraction < 0.2);
    assert.ok(pair.dwrite.measurement.hardEdgeFraction >= pair.gdi.measurement.hardEdgeFraction * 0.75);
    write(125, 120, 'dwrite', true, 80);
    assert.equal(evaluateNative(directory).passed, false);
    write(125, 120, 'gdi', false);
    write(125, 120, 'dwrite', true, 100);
    const rough = evaluateNative(directory);
    assert.ok(rough.checks.some(check => check.dwrite.measurement.partialPixels > 0 && check.dwrite.measurement.hardEdgeFraction > 0.15 && check.dwrite.measurement.hardEdgeFraction < check.gdi.measurement.hardEdgeFraction));
    assert.equal(rough.passed, false);
    write(125, 120, 'dwrite', false);
    assert.equal(evaluateNative(directory).passed, false);
    write(125, 120, 'dwrite', true);
    const file = path.join(directory, 'composer-150-144-dwrite.json');
    const forged = JSON.parse(fs.readFileSync(file));
    forged.measurement.edges += 1;
    fs.writeFileSync(file, JSON.stringify(forged));
    assert.equal(evaluateNative(directory).passed, false);
    fs.unlinkSync(file);
    assert.throws(() => evaluateNative(directory), /ENOENT/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
