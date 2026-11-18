const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const main = fs.readFileSync(path.join(__dirname, '../src/main.zig'), 'utf8');
const start = main.indexOf('        0x02A3 => {');
const end = main.indexOf('        WM_MOUSEMOVE => {', start);
assert.ok(start >= 0 && end > start);
const leave = main.slice(start, end)
  .replace('        0x02A3 => {', 'fn mouseLeave(hwnd: usize) i32 {')
  .replace(/\},\s*$/, '}')
  .replaceAll('@import("usage_card.zig").updateHoverSuppression', 'updateHoverSuppression')
  .replaceAll('@import("sidebar.zig").thawSidebarOrder', 'thawSidebarOrder');

test('SOFT-2713 leaving into an inline editor does not starve painting', (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-focus-paint-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }));
  fs.writeFileSync(path.join(dir, 'repro.zig'), String.raw`
const std = @import("std");
const POINT = struct { x: i32, y: i32 };
const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
const TRACKMOUSEEVENT = struct { cbSize: usize, dwFlags: u32, hwndTrack: usize, dwHoverTime: u32 };
const app_state = struct {
    var g_hide_sidebar = false;
    var g_status_card_hover = false;
    var g_sidebar_hover: ?u32 = null;
    var g_room_hover: ?u32 = null;
    var g_workspace_hover: ?u32 = null;
    var g_inbox_button_hover = false;
    var g_chat_title_inbox_hover = false;
    var g_chat_stop_hover = false;
};
var pointer: POINT = .{ .x = 100, .y = 120 };
var frozen = true;
var queued_leaves: usize = 0;
fn updateHoverSuppression() void {}
fn SIDEBAR_W() i32 { return 300; }
fn GetCursorPos(point: *POINT) i32 { point.* = pointer; return 1; }
fn ScreenToClient(_: usize, _: *POINT) i32 { return 1; }
fn GetClientRect(_: usize, rect: *RECT) i32 {
    rect.* = .{ .left = 0, .top = 0, .right = 1000, .bottom = 650 };
    return 1;
}
fn TrackMouseEvent(_: *TRACKMOUSEEVENT) i32 { queued_leaves += 1; return 1; }
fn InvalidateRect(_: usize, _: ?*const RECT, _: i32) i32 { return 1; }
fn thawSidebarOrder() bool { const was = frozen; frozen = false; return was; }
` + leave + String.raw`
test "leaving the parent for a sidebar editor keeps the order without another leave" {
    _ = mouseLeave(1);
    try std.testing.expect(frozen);
    try std.testing.expectEqual(@as(usize, 0), queued_leaves);
    pointer.y = 700;
    _ = mouseLeave(1);
    try std.testing.expect(!frozen);
    try std.testing.expectEqual(@as(usize, 0), queued_leaves);
}
`);
  const result = spawnSync(process.env.ZIG || 'zig', [
    'test', 'repro.zig', '-j1', '-fno-llvm', '-fno-lld',
    '--cache-dir', path.join(dir, 'cache'),
    '--global-cache-dir', process.env.ZIG_GLOBAL_CACHE_DIR || path.join(dir, 'global-cache'),
  ], { cwd: dir, encoding: 'utf8', timeout: 120000 });
  assert.equal(result.status, 0, JSON.stringify(result));
});
