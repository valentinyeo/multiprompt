const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function image(smooth, empty = false) {
  const width = 300;
  const height = 24;
  const pixels = Buffer.alloc(width * height * 4, 255);
  if (!empty) for (let y = 4; y < 20; y++) for (let x = 4; x < 296; x++) {
    const column = x % 8;
    if (column > 4) continue;
    const value = smooth && (column === 0 || column === 4) ? 128 : 0;
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
  assert.match(main, /SetTextColor\(dc, if \(@import\("chat_composer_text.zig"\).enabled\(\)\) app_state.g_chat_input_color else customColorOr\("text", themeConsoleFg\(\)\)\)/);
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
  for (const token of ['100, 125, 150', '96, 120, 144', 'ensureChatFont()', 'painter.paint(edit, dc', '0x0318', 'IGSH_731', 'hardEdgeFraction * 0.75', 'composer-{d}-{d}-{s}.bmp', 'composer-{d}-{d}-{s}.json']) assert.ok(proof.includes(token), token);
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
