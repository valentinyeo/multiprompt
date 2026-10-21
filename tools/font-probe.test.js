const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = name => fs.readFileSync(path.join(__dirname, '..', name), 'utf8');

test('probe and Chat View share the body and bold creation path without changing shipped defaults', () => {
  const fonts = read('src/fonts.zig');
  assert.match(fonts, /body_weight: i32 = 500/);
  assert.match(fonts, /bold_weight: i32 = 700/);
  assert.match(fonts, /CHAT_QUALITY: w\.DWORD = 4/);
  for (const name of ['chat_render', 'chat_composer', 'font_probe']) {
    assert.match(read(`src/${name}.zig`), /(?:fonts|@import\("fonts.zig"\))\.chat\(/);
  }
  const probe = read('src/font_probe.zig');
  assert.match(probe, /fonts\.register\(\)/);
  assert.match(probe, /defer fonts\.unregister\(\)/);
  assert.match(probe, /\[_\]i32\{ 400, 500 \}/);
  assert.match(probe, /\[_\]u32\{ 4, 5, 6 \}/);
  assert.match(probe, /CreateDIBSection/);
  assert.doesNotMatch(probe, /CreateWindow|ShowWindow|SetForegroundWindow/);
  assert.match(read('build.zig'), /probe\.subsystem = \.Windows/);
  assert.match(probe, /if \(shipped\) \{\s*try render\([^;]*\.\{\}, "gdi"[^;]*;\s*return;/);
});

test('DirectWrite uses the same selected private GDI font and natural symmetric rendering', () => {
  const source = read('tools/font-probe-dwrite.cpp');
  assert.match(source, /CreateFontFaceFromHdc\(dc, &face\)/);
  assert.match(source, /CreateBitmapRenderTarget/);
  assert.match(source, /DWRITE_RENDERING_MODE_NATURAL_SYMMETRIC/);
  assert.match(source, /cleartype \? 1\.0f : 0\.0f/);
  assert.doesNotMatch(source, /CreateWindow|ShowWindow|SetForegroundWindow/);
});
