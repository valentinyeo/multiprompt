const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const { spawnSync } = require('node:child_process');

const dots = fs.readFileSync(path.join(__dirname, '../src/chat_working_dots.zig'), 'utf8');
const render = fs.readFileSync(path.join(__dirname, '../src/chat_render.zig'), 'utf8');

function sliceFn(source, name) {
  const start = source.search(new RegExp(`\\n(?:pub )?fn ${name}\\(`));
  assert.ok(start >= 0, `${name} must exist in the working-dots render path`);
  return source.slice(start + 1, source.indexOf('\n}', start) + 2);
}

test('SOFT-2642 the working row follows the content when the top pad changes', () => {
  assert.match(sliceFn(render, 'chatSetTopPad'), /if \(g_working_rect\) \|\*rect\| \{\n\s+rect\.top \+= delta;\n\s+rect\.bottom \+= delta;/);
  assert.match(sliceFn(render, 'chatWorkingSync'), /@import\("chat_working_dots\.zig"\)\.sync\(g_working_rect, chatWorkingDotsVisible\(\)\);/);
  assert.match(render, /@import\("chat_working_dots\.zig"\)\.paint\(mem_dc, paint, GetTickCount64\(\), g_working_rect, chatWorkingDotsVisible\(\)\);/);
});

function runPainter(before) {
  const fixture = fs.readFileSync(path.join(__dirname, 'fixtures/SOFT-2642/chat-working-before.zig'), 'utf8');
  const functions = before
    ? ['chatWorkingSync', 'chatPaintWorking', 'chatPaintWorkingDots'].map(name => sliceFn('\n' + fixture, name)).join('\n')
    : ['screenRect', 'repaintRegion', 'overlaps', 'sync', 'paint', 'paintDots'].map(name => sliceFn(dots, name)).join('\n');
  const entry = before
    ? 'fn paintFrame(hdc: HANDLE, _: RECT, now: u64) void { chatPaintWorking(hdc, now); }'
    : `var painted_rect: ?RECT = null;
fn chatWorkingSync() void { sync(g_working_rect, chatWorkingDotsVisible()); }
fn paintFrame(hdc: HANDLE, area: RECT, now: u64) void { paint(hdc, area, now, g_working_rect, chatWorkingDotsVisible()); }`;
  const source = `
const std = @import("std");
const HANDLE = usize;
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const WORKING_DOT_SIZE = 4;
const WORKING_DOT_STEP = 8;
const WORKING_DOT_ALPHA: u8 = 102;
const CHAT_AGENT_PAD_X = 4;
var g_chat_transcript_hwnd: ?HANDLE = 1;
var g_chat_scroll_y: i32 = 0;
var g_working_rect: ?RECT = .{ .left = 8, .top = 40, .right = 110, .bottom = 68 };
var visible = true;
var pending: ?RECT = null;
var clip: RECT = .{ .left = 0, .top = 0, .right = 128, .bottom = 400 };
var pixels: [400][128]bool = @splat(@splat(false));
fn uiScaled(n: i32) i32 { return n; }
fn themeConsoleBg() u32 { return 0; }
fn themeConsoleFg() u32 { return 255; }
fn customColorOr(_: []const u8, color: u32) u32 { return color; }
fn blend(_: u32, _: u32, _: u8) u32 { return 102; }
fn chatWorkingDotsVisible() bool { return visible; }
fn chatViewClientRect(rc: *RECT) void { rc.* = .{ .left = 0, .top = 0, .right = 128, .bottom = 400 }; }
fn chatRelayoutPreservingScroll(_: i32, _: i32) void { if (!visible) g_working_rect = null; }
fn InvalidateRect(_: ?HANDLE, area: ?*const RECT, _: i32) i32 {
    const rc = if (area) |r| r.* else RECT{ .left = 0, .top = 0, .right = 128, .bottom = 400 };
    if (pending) |old| pending = .{
        .left = @min(old.left, rc.left), .top = @min(old.top, rc.top),
        .right = @max(old.right, rc.right), .bottom = @max(old.bottom, rc.bottom),
    } else pending = rc;
    return 1;
}
fn fillEllipse(_: HANDLE, rc: RECT, _: u32) void {
    var y = @max(rc.top, clip.top);
    while (y < @min(rc.bottom, clip.bottom)) : (y += 1) {
        var x = @max(rc.left, clip.left);
        while (x < @min(rc.right, clip.right)) : (x += 1) pixels[@intCast(y)][@intCast(x)] = true;
    }
}
fn flush(now: u64) void {
    const rc = pending orelse return;
    pending = null;
    clip = rc;
    var y = @max(0, rc.top);
    while (y < @min(400, rc.bottom)) : (y += 1) {
        var x = @max(0, rc.left);
        while (x < @min(128, rc.right)) : (x += 1) pixels[@intCast(y)][@intCast(x)] = false;
    }
    paintFrame(1, rc, now);
}
fn expectOneIndicator() !void {
    var bands: usize = 0;
    var previous = false;
    var columns: [128]bool = @splat(false);
    for (pixels) |row_pixels| {
        var ink = false;
        for (row_pixels, 0..) |pixel, x| {
            ink = ink or pixel;
            columns[x] = columns[x] or pixel;
        }
        if (ink and !previous) bands += 1;
        previous = ink;
    }
    try std.testing.expectEqual(@as(usize, 1), bands);
    var dots_count: usize = 0;
    previous = false;
    for (columns) |ink| {
        if (ink and !previous) dots_count += 1;
        previous = ink;
    }
    try std.testing.expectEqual(@as(usize, 3), dots_count);
}
${entry}
${functions.replaceAll('app_state.', '').replaceAll('@import("chat_render.zig").', '').replaceAll('@import("chat_session.zig").', '').replaceAll('@import("chat_scrollbar.zig").', '').replaceAll('@import("smooth.zig").', '')}
test "SOFT-2642 repeated layout moves and ticks leave exactly one three-dot indicator" {
    chatWorkingSync();
    flush(0);
    try expectOneIndicator();
    for ([_]i32{ 40, 90, 140, 190, 140, 90, 40, 40 }) |top| {
        g_working_rect.?.top = top;
        g_working_rect.?.bottom = top + 28;
        for (0..6) |tick| {
            chatWorkingSync();
            chatWorkingSync();
            flush(@as(u64, @intCast(tick)) * 250);
            try expectOneIndicator();
        }
    }
    for ([_]i32{ -40, -80, 0, 10, 0 }) |scroll| {
        g_chat_scroll_y = scroll;
        chatWorkingSync();
        flush(500);
        try expectOneIndicator();
    }
    visible = false;
    chatWorkingSync();
    flush(750);
    for (pixels) |row_pixels| for (row_pixels) |pixel| try std.testing.expect(!pixel);
}
`;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'soft-2642-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, source);
    return spawnSync(process.env.ZIG || 'zig', ['test', file], { encoding: 'utf8', timeout: 60000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('SOFT-2642 the production painter keeps one indicator through repeated moves and scrolls', () => {
  const result = runPainter(false);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('SOFT-2642 the same repaint regression rejects the master painter', () => {
  const result = runPainter(true);
  assert.equal(result.status, 1, result.stdout + result.stderr);
  assert.match(result.stderr, /expected 1, found 2/);
});
