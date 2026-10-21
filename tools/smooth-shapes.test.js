const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const source = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const body = (text, name) => {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const lineStart = text.lastIndexOf('\n', start) + 1;
  const indent = text.slice(lineStart, start).match(/^\s*/)[0];
  const end = text.indexOf(`\n${indent}}`, start);
  assert.ok(end > start, `${name} closing brace`);
  return text.slice(start, end + indent.length + 2);
};
const rawCalls = text => [...text.matchAll(/\b(RoundRect|Ellipse|Polygon|Pie)\s*\(/g)];

test('ISSUE-444 raw curved shapes exist only in the shared smooth fallback', () => {
  const violations = [];
  for (const file of fs.readdirSync(path.join(root, 'src')).filter(file => file.endsWith('.zig'))) {
    if (file === 'smooth.zig') continue;
    const text = source(file);
    for (const match of rawCalls(text)) {
      const line = text.slice(0, match.index).split('\n').length;
      const declaration = text.split('\n')[line - 1];
      if (file === 'win32.zig' && /pub extern "gdi32" fn /.test(declaration)) continue;
      violations.push(`${file}:${line}: ${match[1]}`);
    }
  }
  assert.deepEqual(violations, [], violations.join('\n'));
});

test('ISSUE-444 inbox background and glyph and Send button use smooth shapes', () => {
  const inbox = body(source('drawing.zig'), 'paintInboxButton');
  assert.doesNotMatch(inbox, /drawNativeLine|\bRoundRect\s*\(/);
  assert.match(inbox, /canvas\.strokePolyline/);
  assert.match(inbox, /drawRoundRect/);
  const send = body(source('window_layout.zig'), 'paintChatButton');
  assert.doesNotMatch(send, /\bRoundRect\s*\(/);
  assert.match(send, /smooth\.zig/);
  assert.match(body(source('drawing.zig'), 'drawNativeLine'), /strokePenLine/);
});

test('ISSUE-444 shared loader enables antialiasing, half pixels, round strokes and clipping', () => {
  const smooth = source('smooth.zig');
  for (const symbol of ['GdipSetSmoothingMode', 'GdipSetPixelOffsetMode', 'GdipSetClipHrgn']) assert.ok(smooth.includes(symbol), symbol);
  assert.match(smooth, /set_smoothing\(self\.graphics, 4\)/);
  assert.match(smooth, /set_pixel_offset\(self\.graphics, 4\)/);
  assert.match(smooth, /set_pen_caps\(pen, 2, 2, 0\)/);
  assert.match(smooth, /set_pen_join\(pen, 2\)/);
  assert.match(smooth, /GetClipRgn/);
  assert.match(source('chat_render.zig'), /const gdipLoad = @import\("smooth.zig"\)\.gdipLoad/);
  assert.doesNotMatch(source('chat_render.zig'), /fn gdipLoad\(/);
});

test('ISSUE-444 big rounded fills use GDI interiors and only small corner paths', () => {
  const fill = body(source('smooth.zig'), 'fillRounded');
  assert.match(fill, /g\.width \* g\.height <= 4096/);
  assert.match(fill, /w\.FillRect/);
  assert.match(fill, /for \(specs\) \|corner\| \{\s*var corners/);
  assert.match(fill, /self\.fill\(corners, color\)/);
  assert.doesNotMatch(fill.slice(fill.indexOf('const api')), /self\.fill\(path/);
  assert.match(source('smooth.zig'), /paint_hdc == hdc/);
  assert.match(source('main.zig'), /beginPaintCanvas\(\)/);
  assert.match(source('chat_render.zig'), /Canvas\.init\(mem_dc\)/);
});

test('ISSUE-444 raw call oracle catches qualified calls and whitespace', () => {
  assert.equal(rawCalls('RoundRect(dc); w.Ellipse (dc); api.Polygon\n(dc); Pie(dc);').length, 4);
  assert.equal(rawCalls('drawRoundRect(dc); drawEllipse(dc); fillPolygon(dc);').length, 0);
});

test('ISSUE-444 main graphics live with the backbuffer rather than each paint', () => {
  const drawing = source('drawing.zig');
  const ensure = body(drawing, 'ensurePaintBackbuffer');
  const begin = body(drawing, 'beginPaintCanvas');
  const reset = body(drawing, 'resetPaintBackbuffer');
  assert.match(ensure, /g_paint_w >= w and app_state\.g_paint_h >= h/);
  assert.equal((ensure.match(/Canvas\.init\(mem_dc\)/g) || []).length, 1);
  assert.match(ensure, /paint_canvas\.deactivate\(\)/);
  assert.match(begin, /paint_canvas\.activate\(\)/);
  assert.doesNotMatch(begin, /Canvas\.init/);
  assert.ok(reset.indexOf('paint_canvas.deinit()') >= 0);
  assert.ok(reset.indexOf('paint_canvas.deinit()') < reset.indexOf('DeleteObject'));
  assert.doesNotMatch(source('main.zig'), /Canvas\.init\(mem_dc\)/);
});

test('ISSUE-444 main and transcript backbuffers expose DIB pixels to the shared graphics', () => {
  const main = body(source('drawing.zig'), 'ensurePaintBackbuffer');
  const transcript = body(source('chat_render.zig'), 'chatTranscriptWndProc');
  for (const paint of [main, transcript]) {
    assert.match(paint, /CreateDIBSection/);
    assert.match(paint, /\.height = -(?:h|height)\b/);
    assert.doesNotMatch(paint, /CreateCompatibleBitmap/);
  }
});
