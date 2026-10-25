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
  assert.match(composer, /const redraw = @import\("chat_composer_text.zig"\).suspendNativePaint\(hwnd, msg\)/);
  assert.match(composer, /defer @import\("chat_composer_text.zig"\).resumeNativePaint\(hwnd, msg, redraw\)/);
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

test('IGSH-760 composer paint contract rejects the shipped direct-paint path', () => {
  const { spawnSync } = require('node:child_process');
  const fixed = spawnSync(process.execPath, ['tools/composer-paint-audit.mjs', '--require-buffered'], { cwd: root, encoding: 'utf8' });
  assert.equal(fixed.status, 0, fixed.stdout + fixed.stderr);
  assert.match(fixed.stdout, /COMPOSER PAINT CONTRACT VERIFIED/);
  const broken = spawnSync(process.execPath, ['tools/composer-paint-audit.mjs', '--source=tools/fixtures/IGSH-760', '--require-buffered'], { cwd: root, encoding: 'utf8' });
  assert.notEqual(broken.status, 0);
  assert.match(broken.stderr, /composer clears the visible text area/);
});

test('IGSH-805 buffered composer requests native background erasure before drawing into the new bitmap', () => {
  const composer = read('src/chat_composer.zig');
  const backgroundPrint = /CallWindowProcW\(app_state\.g_chat_composer_orig_proc, hwnd, 0x0318, @intFromPtr\(dc\), 4 \| 8\);\s*var probe:/;
  assert.match(composer, backgroundPrint);
  const broken = composer.replace('0x0318, @intFromPtr(dc), 4 | 8);', '0x0318, @intFromPtr(dc), 4);');
  assert.notEqual(broken, composer);
  assert.throws(() => assert.match(broken, backgroundPrint), assert.AssertionError);
});

function typingFixture() {
  const frames = Array.from({ length: 61 }, (_, index) => {
    const width = 180;
    const height = 32;
    const pixels = Buffer.alloc(width * height * 4, 32);
    for (let y = 8; y < 24; y++) for (let x = 4; x < 48 + Math.floor(index / 3) * 4; x++) {
      if (x % 5 > 2) continue;
      const offset = (y * width + x) * 4;
      pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 220;
    }
    if (index % 2) for (let y = 8; y < 24; y++) {
      const offset = (y * width + 50 + Math.floor(index / 3) * 4) * 4;
      pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 220;
    }
    return { timeMs: index * 20, image: { width, height, pixels } };
  });
  return { frames, metadata: { typingStartMs: 0, typingEndMs: 1200, inkRect: { left: 4, top: 4, right: 40, bottom: 28 }, rowRect: { left: 4, top: 4, right: 176, bottom: 28 } } };
}

test('IGSH-760 steady growing text and a blinking caret pass with measured ink/background evidence', async () => {
  const { evaluateTypingFrames, typingThresholds } = await import('./chat-composer-text-proof.mjs');
  const { frames, metadata: typingMetadata } = typingFixture();
  const summary = evaluateTypingFrames(frames, typingMetadata);
  assert.equal(summary.name, 'IGSH-760 typing frames steady');
  assert.equal(summary.passed, true);
  assert.equal(summary.frames, 61);
  assert.equal(summary.inkSeries.min, summary.inkSeries.max);
  assert.ok(summary.inkSeries.min > typingThresholds.minInk);
  assert.ok(summary.rowInkSeries.max > summary.rowInkSeries.min);
  assert.equal(summary.settledBackground, 0x202020);
  assert.equal(summary.mismatchedFrames.length, 0);
  assert.deepEqual(typingThresholds, { minFrames: 30, minDurationMs: 1000, maxGapMs: 100, minInk: 20, minInkRatio: 0.8, inkContrast: 24, maxColorDelta: 2 });
});

test('IGSH-760 broken double-paint frames fail even when every later frame settles correctly', async () => {
  const { evaluateTypingFrames } = await import('./chat-composer-text-proof.mjs');
  for (const region of ['all', 'prefix', 'trailing']) {
    const { frames, metadata: typingMetadata } = typingFixture();
    const sample = frames[40].image;
    for (let y = 4; y < 28; y++) for (let x = region === 'trailing' ? 40 : 4; x < (region === 'prefix' ? 40 : 176); x++) {
      const offset = (y * sample.width + x) * 4;
      sample.pixels[offset] = sample.pixels[offset + 1] = sample.pixels[offset + 2] = 32;
    }
    const summary = evaluateTypingFrames(frames, typingMetadata);
    assert.equal(summary.passed, false, region);
    assert.equal(summary.samplingPassed, true);
    assert.equal(summary.mismatchedFrames.length, 1);
    assert.equal(summary.mismatchedFrames[0].index, 40);
    assert.deepEqual(summary.mismatchedFrames[0].reasons, ['ink-drop']);
  }
});

test('IGSH-760 row background and border changes fail independently, with a two-channel-level tolerance', async () => {
  const { evaluateTypingFrames } = await import('./chat-composer-text-proof.mjs');
  for (const change of [2, 3, 223]) for (const region of ['background', 'border']) {
    const { frames, metadata: typingMetadata } = typingFixture();
    const sample = frames[20].image;
    if (region === 'border') sample.pixels[(sample.width + 1) * 4] += change;
    else for (let y = 4; y < 28; y++) for (let x = 4; x < 176; x++) {
      const offset = (y * sample.width + x) * 4;
      if (sample.pixels[offset] === 32) sample.pixels[offset] += change;
    }
    const summary = evaluateTypingFrames(frames, typingMetadata);
    assert.equal(summary.passed, change <= 2, `${region} delta ${change}`);
    if (change > 2) assert.ok(summary.mismatchedFrames[0].reasons.includes(region === 'border' ? 'border-background' : 'row-background'));
  }
});

test('IGSH-760 rejects blank, short, stalled or non-typing captures and malformed geometry', async () => {
  const { evaluateTypingFrames } = await import('./chat-composer-text-proof.mjs');
  const { frames, metadata: typingMetadata } = typingFixture();
  for (const samples of [frames.slice(0, 29), frames.slice(10), frames.slice(0, 50), frames.filter((_, index) => index < 10 || index > 20), frames.map(frame => ({ ...frame, timeMs: 0 }))]) {
    assert.equal(evaluateTypingFrames(samples, typingMetadata).passed, false);
  }
  assert.equal(evaluateTypingFrames(frames, { ...typingMetadata, typingEndMs: 900 }).passed, false);
  assert.equal(evaluateTypingFrames(frames, { ...typingMetadata, typingStartMs: 2000, typingEndMs: 4000 }).passed, false);
  assert.throws(() => evaluateTypingFrames([], typingMetadata), /Missing typing frames/);
  assert.throws(() => evaluateTypingFrames(frames, { ...typingMetadata, inkRect: { ...typingMetadata.inkRect, right: 181 } }), /rectangle/);
  for (const frame of frames) frame.image.pixels.fill(32);
  assert.equal(evaluateTypingFrames(frames, typingMetadata).passed, false);
});

test('IGSH-760 capture rectangles intersect the screen crop before becoming bitmap-local half-open bounds', async () => {
  const { runInNewContext } = require('node:vm');
  const { evaluateTypingFrames } = await import('./chat-composer-text-proof.mjs');
  const control = read('.claude/skills/verify-multiprompt/control.ps1');
  const rectangles = (row, prefixRow, typingCrop) => Object.fromEntries(['inkRect', 'rowRect'].map(name => {
    const assignment = control.match(new RegExp(`\\$${name} = @\\{([^}]+)\\}`));
    assert.ok(assignment, name);
    const rect = Object.fromEntries([...assignment[1].matchAll(/(left|top|right|bottom)\s*=\s*([^;]+)/g)].map(([, key, expression]) => [key, runInNewContext(expression.replace(/\[Math\]::(Min|Max)/g, (_, method) => `Math.${method.toLowerCase()}`).replace(/\$(row|prefixRow|typingCrop)\b/g, '$1'), { row, prefixRow, typingCrop })]));
    return [name, rect];
  }));
  const actual = rectangles([105, 201, 432, 227], [105, 201, 159, 227], { Left: 100, Top: 200, Right: 512, Bottom: 223 });
  assert.deepEqual(actual, { inkRect: { left: 5, top: 1, right: 59, bottom: 23 }, rowRect: { left: 5, top: 1, right: 332, bottom: 23 } });
  assert.deepEqual(rectangles([-95, -99, 232, -73], [-95, -99, -41, -73], { Left: -100, Top: -100, Right: 312, Bottom: -77 }), actual);
  const { frames, metadata: typingMetadata } = typingFixture();
  const clipped = rectangles([99, 199, 285, 240], [99, 199, 140, 240], { Left: 100, Top: 200, Right: 280, Bottom: 232 });
  assert.deepEqual(clipped, { inkRect: { left: 0, top: 0, right: 40, bottom: 32 }, rowRect: { left: 0, top: 0, right: 180, bottom: 32 } });
  assert.equal(evaluateTypingFrames(frames, { ...typingMetadata, ...clipped }).passed, true);
  for (const name of ['inkRect', 'rowRect']) {
    assert.throws(() => evaluateTypingFrames(frames, { ...typingMetadata, [name]: { ...typingMetadata[name], bottom: 33 } }), /Invalid typing rectangle/);
  }
  const outside = rectangles([300, 200, 400, 232], [300, 200, 340, 232], { Left: 100, Top: 200, Right: 280, Bottom: 232 });
  assert.throws(() => evaluateTypingFrames(frames, { ...typingMetadata, ...outside }), /Invalid typing rectangle/);
});

test('IGSH-760 capture is concurrent screen BitBlt during owned keyboard input, not a forced settled repaint', () => {
  const control = read('.claude/skills/verify-multiprompt/control.ps1');
  const capture = control.slice(control.indexOf('    public static Dictionary<string, object> ComposerTypingFrames('), control.indexOf('    public static int[] ReadSwitchScreenPatch('));
  for (const token of ['GetAncestor(composer, 2) != owner', 'GetForegroundWindow() != owner', 'GetFocusedWindow(owner) != composer', 'Text(text.Substring(0, 12))', 'new Thread(', 'BitBlt(target, 0, 0, width, height, screen, crop.Left, crop.Top, 0x00CC0020)', 'finalFrame = stop.WaitOne(2)', 'if (finalFrame) break', 'sampler.Start()', 'Text(text.Substring(12))', 'stop.Set(); sampler.Join()', 'EditText(composer) != text']) assert.ok(capture.includes(token), token);
  assert.doesNotMatch(capture.replace(/"[^"\n]*"/g, ''), /DwmFlush\(|PrintWindow\(|SendMessage|WM_PAINT/);
  assert.ok(capture.indexOf('sampler.Start()') < capture.indexOf('Text(text.Substring(12))'));
  assert.ok(capture.indexOf('Text(text.Substring(12))') < capture.indexOf('stop.Set(); sampler.Join()'));
  const journey = control.slice(control.indexOf("        'chat-composer-text' {"), control.indexOf("        'chat-code-font' {"));
  for (const token of ["name = 'IGSH-760 typing frames steady'", "Assert-ChatTyping $sentence 'composer-typing-burst' {", '[VerifyNative]::ComposerTypingFrames(', "Save-Json $burst 'composer-typing.json'", '$Evidence --typing', '$typingCheck[$property.Name] = $property.Value', 'if (-not $typingCheck.passed)']) assert.ok(journey.includes(token), token);
  assert.ok(journey.indexOf('if (-not $typingCheck.passed)') < journey.indexOf('if (-not $composerCheck.passed)'));
  const feature = read('.claude/skills/verify-multiprompt/features/chat-composer-text.md');
  for (const token of ['IGSH-760 typing frames steady', 'v0.28.860', '0.8', 'mismatchedFrames', '30']) assert.ok(feature.includes(token), token);
});

test('IGSH-760 CLI remeasures burst BMPs and writes a failing summary/exit status for the red control', () => {
  const { spawnSync } = require('node:child_process');
  const os = require('node:os');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'composer-typing-oracle-'));
  const { frames, metadata: typingMetadata } = typingFixture();
  const writeFrame = index => {
    const sample = frames[index].image;
    const header = Buffer.alloc(54);
    header.write('BM');
    header.writeUInt32LE(54 + sample.pixels.length, 2);
    header.writeUInt32LE(54, 10);
    header.writeUInt32LE(40, 14);
    header.writeInt32LE(sample.width, 18);
    header.writeInt32LE(-sample.height, 22);
    header.writeUInt16LE(1, 26);
    header.writeUInt16LE(32, 28);
    fs.writeFileSync(path.join(directory, `composer-typing-${String(index).padStart(4, '0')}.bmp`), Buffer.concat([header, sample.pixels]));
  };
  const run = () => spawnSync(process.execPath, [path.join(__dirname, 'chat-composer-text-proof.mjs'), directory, '--typing'], { encoding: 'utf8', timeout: 10000 });
  const summaryFile = path.join(directory, 'composer-typing-summary.json');
  try {
    fs.writeFileSync(path.join(directory, 'composer-typing.json'), '\uFEFF' + JSON.stringify({ ...typingMetadata, timesMs: frames.map(frame => frame.timeMs) }));
    frames.forEach((_, index) => writeFrame(index));
    const green = run();
    assert.equal(green.status, 0, green.stdout + green.stderr);
    assert.equal(JSON.parse(fs.readFileSync(summaryFile)).passed, true);
    frames[20].image.pixels.fill(32);
    writeFrame(20);
    const red = run();
    assert.equal(red.status, 1, red.stdout + red.stderr);
    const summary = JSON.parse(fs.readFileSync(summaryFile));
    assert.equal(summary.name, 'IGSH-760 typing frames steady');
    assert.equal(summary.passed, false);
    assert.equal(summary.samplingPassed, true);
    assert.equal(summary.mismatchedFrames[0].index, 20);
    assert.equal(summary.inkSeries.min, 0);
    fs.unlinkSync(path.join(directory, 'composer-typing-0020.bmp'));
    assert.equal(run().status, 1);
    assert.match(JSON.parse(fs.readFileSync(summaryFile)).error, /ENOENT/);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
});

test('IGSH-760 ink loss boundary accepts at least eighty percent and rejects one pixel below the boundary', async () => {
  const { evaluateTypingFrames } = await import('./chat-composer-text-proof.mjs');
  for (const extraLoss of [0, 1]) {
    const { frames, metadata: typingMetadata } = typingFixture();
    const baseline = frames.at(-1).image;
    const inkOffsets = [];
    const rect = typingMetadata.inkRect;
    for (let y = rect.top; y < rect.bottom; y++) for (let x = rect.left; x < rect.right; x++) {
      const offset = (y * baseline.width + x) * 4;
      if (baseline.pixels[offset] !== 32) inkOffsets.push(offset);
    }
    const sample = frames[20].image;
    const remaining = Math.ceil(inkOffsets.length * 0.8) - extraLoss;
    for (const offset of inkOffsets.slice(remaining)) sample.pixels[offset] = sample.pixels[offset + 1] = sample.pixels[offset + 2] = 32;
    const summary = evaluateTypingFrames(frames, typingMetadata);
    assert.equal(summary.passed, extraLoss === 0);
    if (extraLoss) assert.ok(summary.mismatchedFrames[0].inkRatio < 0.8);
  }
});
