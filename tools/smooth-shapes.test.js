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
  assert.match(fill, /for \(specs\) \|corner\| \{[^]*?var corners/);
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
  const transcript = body(source('chat_render.zig'), 'ensureTranscriptBackbuffer');
  for (const paint of [main, transcript]) {
    assert.match(paint, /CreateDIBSection/);
    assert.match(paint, /\.height = -(?:h|height)\b/);
    assert.doesNotMatch(paint, /CreateCompatibleBitmap/);
  }
});


test('IGSH-1149 clipped gradient strips build only corners that can reach painted pixels', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clipped-corners-'));
  const code = `
const std = @import("std");
const HANDLE = ?*anyopaque;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const RoundGeometry = struct { x: f32, y: f32, width: f32, height: f32, diameter_x: f32, diameter_y: f32 };
var clip = RECT{ .left = 0, .top = 0, .right = 200, .bottom = 100 };
var fills: usize = 0;
const w = struct {
    fn CreateSolidBrush(_: u32) HANDLE { return @ptrFromInt(1); }
    fn DeleteObject(_: HANDLE) i32 { return 1; }
    fn FillRect(_: HANDLE, _: *const RECT, _: HANDLE) i32 { return 1; }
    fn RectVisible(_: HANDLE, rc: *const RECT) i32 {
        return @intFromBool(rc.right > clip.left and rc.left < clip.right and rc.bottom > clip.top and rc.top < clip.bottom);
    }
};
const Api = struct {
    create_path: *const fn (i32, *HANDLE) i32 = create,
    delete_path: *const fn (HANDLE) i32 = one,
    start_figure: *const fn (HANDLE) i32 = one,
    close_figure: *const fn (HANDLE) i32 = one,
    add_path_arc: *const fn (HANDLE, f32, f32, f32, f32, f32, f32) i32 = arc,
    add_path_line: *const fn (HANDLE, f32, f32, f32, f32) i32 = line,
    fn create(_: i32, path: *HANDLE) i32 { path.* = @ptrFromInt(1); return 0; }
    fn one(_: HANDLE) i32 { return 0; }
    fn arc(_: HANDLE, _: f32, _: f32, _: f32, _: f32, _: f32, _: f32) i32 { return 0; }
    fn line(_: HANDLE, _: f32, _: f32, _: f32, _: f32) i32 { return 0; }
};
const app_state = struct { var g_gdip_api: Api = .{}; };
const Canvas = struct {
    hdc: HANDLE = @ptrFromInt(1),
    fn fill(_: *Canvas, _: HANDLE, _: u32) bool { fills += 1; return true; }
    ${body(source('smooth.zig'), 'fillRounded')}
};
test "native gradient clip retains visible corners and skips invisible paths" {
    var canvas: Canvas = .{};
    const g = RoundGeometry{ .x = 0, .y = 0, .width = 200, .height = 100, .diameter_x = 20, .diameter_y = 20 };
    try std.testing.expect(canvas.fillRounded(@ptrFromInt(1), g, 0xffffff));
    try std.testing.expectEqual(@as(usize, 4), fills);
    fills = 0;
    clip.top = 20; clip.bottom = 80;
    try std.testing.expect(canvas.fillRounded(@ptrFromInt(1), g, 0xffffff));
    try std.testing.expectEqual(@as(usize, 0), fills);
    fills = 0;
    clip.top = 0; clip.bottom = 10;
    try std.testing.expect(canvas.fillRounded(@ptrFromInt(1), g, 0xffffff));
    try std.testing.expectEqual(@as(usize, 2), fills);
    fills = 0;
    clip.left = 190; clip.top = 90; clip.bottom = 100;
    try std.testing.expect(canvas.fillRounded(@ptrFromInt(1), g, 0xffffff));
    try std.testing.expectEqual(@as(usize, 1), fills);
}
`;
  try {
    fs.writeFileSync(path.join(dir, 'corners.zig'), code);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'corners.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});


test('IGSH-1149 transcript paint resources survive repeated frames and release on growth or destruction', () => {
  const os = require('node:os');
  const { spawnSync } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'transcript-paint-'));
  try {
    const render = source('chat_render.zig');
    assert.match(body(render, 'chatTranscriptWndProc'), /ensureTranscriptBackbuffer\(hdc, w, h\)/);
    assert.match(body(render, 'chatTranscriptWndProc'), /WM_DESTROY => \{\s*resetTranscriptBackbuffer\(\)/);
    const fields = render.slice(render.indexOf('var transcript_paint_dc:'), render.indexOf('fn resetTranscriptBackbuffer('));
    const code = `
const std = @import("std");
const HANDLE = ?*anyopaque;
var allocated: usize = 0;
var deleted: usize = 0;
var dc_deleted: usize = 0;
var fail_bitmap = false;
fn CreateCompatibleDC(_: HANDLE) HANDLE { return @ptrFromInt(1); }
fn DeleteDC(_: HANDLE) i32 { dc_deleted += 1; return 1; }
fn DeleteObject(_: HANDLE) i32 { deleted += 1; return 1; }
fn SelectObject(_: HANDLE, _: HANDLE) HANDLE { return @ptrFromInt(2); }
${fields}
${body(render, 'resetTranscriptBackbuffer')}
${body(render, 'ensureTranscriptBackbuffer')}
test "reuse, resize, failed allocation and teardown" {
    try std.testing.expect(ensureTranscriptBackbuffer(null, 0, 100) == null);
    for (0..120) |_| try std.testing.expect(ensureTranscriptBackbuffer(null, 700, 500) != null);
    try std.testing.expectEqual(@as(usize, 1), allocated);
    try std.testing.expectEqual(@as(usize, 0), deleted);
    try std.testing.expect(ensureTranscriptBackbuffer(null, 900, 500) != null);
    try std.testing.expectEqual(@as(usize, 2), allocated);
    try std.testing.expectEqual(@as(usize, 1), deleted);
    resetTranscriptBackbuffer();
    try std.testing.expectEqual(@as(usize, 2), deleted);
    try std.testing.expectEqual(@as(usize, 2), dc_deleted);
    resetTranscriptBackbuffer();
    try std.testing.expectEqual(@as(usize, 2), deleted);
    fail_bitmap = true;
    try std.testing.expect(ensureTranscriptBackbuffer(null, 900, 500) == null);
    try std.testing.expectEqual(@as(usize, 3), dc_deleted);
    fail_bitmap = false;
    try std.testing.expect(ensureTranscriptBackbuffer(null, 900, 500) != null);
    resetTranscriptBackbuffer();
    try std.testing.expectEqual(@as(usize, 3), deleted);
}
`;
    fs.writeFileSync(path.join(dir, 'paint.zig'), code);
    fs.writeFileSync(path.join(dir, 'win32.zig'), `
const main = @import("paint.zig");
pub const BITMAPINFO = struct { header: struct { width: i32, height: i32 } };
pub fn CreateDIBSection(_: ?*anyopaque, _: *const BITMAPINFO, _: i32, _: *?*anyopaque, _: ?*anyopaque, _: i32) ?*anyopaque {
    if (main.fail_bitmap) return null;
    main.allocated += 1;
    return @ptrFromInt(3);
}
`);
    fs.writeFileSync(path.join(dir, 'paint.zig'), code.replace('var allocated:', 'pub var allocated:').replace('var fail_bitmap', 'pub var fail_bitmap'));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'paint.zig')], { encoding: 'utf8', timeout: 60000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
