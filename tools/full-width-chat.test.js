const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const source = require('./app-source').readAppSource();

function body(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return text.slice(start, text.indexOf('\n}', start) + 2);
}

function toggle(text) {
  const start = text.indexOf('        WM_APP_TOGGLE_FULLWIDTH => {');
  assert.ok(start >= 0);
  const end = text.indexOf('\n        WM_APP_RECONNECT =>', start);
  assert.ok(end > start);
  return text.slice(start, end).replace('WM_APP_TOGGLE_FULLWIDTH => {', 'fn toggleFullWidth(hwnd: HANDLE) i32 {').replace(/},\s*$/, '}').replaceAll('@import("chat_composer.zig").fullWidthShouldResizeConsole', 'fullWidthShouldResizeConsole');
}

function content(text) {
  const layout = body(text, 'chatViewLayout');
  return layout.slice(layout.indexOf('    const full_width ='), layout.indexOf('    const content_top ='));
}

function harness(handler, geometry = content(source)) {
  return `const std = @import("std");
const chat_style = @import("chat_style.zig");
const app_state = @This();
const HANDLE = ?usize;
const ISSUE_440_FULL_WIDTH_CHAT = true;
const chatViewShouldShowForTab = @import("chat_view.zig").shouldShow;
var shells = [_]struct { pid: u32 = 42, full_width: bool = false, full_width_pending_console_resize: bool = false, pinned_top: bool = false }{ .{}, .{} };
var active_shell: u32 = 0;
var shell_count: u32 = 2;
var g_chat_active = false;
var resizes: usize = 0;
var saves: usize = 0;
var layouts: usize = 0;
var browser = false;
fn applyBlackConsoleBackground(_: u32) void { resizes += 1; }
fn repositionActive() void { layouts += 1; }
fn saveSession() void { saves += 1; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn browserSlotReserved() bool { return browser; }
fn browserSplitPermilleForActiveShell() u16 { return 350; }
var scale: i32 = 100;
fn uiScaled(value: i32) i32 { return @divTrunc(value * scale, 100); }
${body(source, 'fullWidthShouldResizeConsole')}
${handler}
fn chatColumn(width: i32) struct { left: i32, width: i32 } {
    const slot = .{ .left = @as(i32, 220), .right = 220 + width };
${geometry}
    return .{ .left = left, .width = right - left };
}
test "production reading column and full width stay inside the shared pane" {
    for ([_]i32{100, 150}) |dpi| {
        scale = dpi;
        for ([_]bool{false, true}) |docked| {
            browser = docked;
            for ([_]i32{0, 40, 600, 1700}) |width| {
                shells[0].full_width = true;
                const full = chatColumn(width);
                try std.testing.expectEqual(@as(i32, 220), full.left);
                try std.testing.expectEqual(width, full.width);
                shells[0].full_width = false;
                const normal = chatColumn(width);
                const want = @min(width, @max(@divTrunc(width * 350, 1000), uiScaled(760)));
                try std.testing.expectEqual(want, normal.width);
                try std.testing.expectEqual(220 + @divTrunc(width - want, 2), normal.left);
                try std.testing.expect(normal.left >= full.left and normal.left + normal.width <= full.left + full.width);
            }
        }
    }
}
test "ISSUE-440 production toggle changes only width and saves twice" {
    for ([_]bool{ false, true }) |pinned| {
        for ([_]bool{ false, true }) |remembered| {
            g_chat_active = chatViewShouldShowForTab(remembered);
            const chat = g_chat_active;
            shells[0].full_width = false;
            shells[0].full_width_pending_console_resize = false;
            shells[1].full_width_pending_console_resize = false;
            shells[0].pinned_top = pinned;
            shells[1].full_width = true;
            resizes = 0;
            saves = 0;
            layouts = 0;
            try std.testing.expectEqual(@as(i32, 0), toggleFullWidth(null));
            try std.testing.expect(shells[0].full_width);
            try std.testing.expectEqual(chat, shells[0].full_width_pending_console_resize);
            try std.testing.expectEqual(@as(i32, 0), toggleFullWidth(null));
            try std.testing.expect(!shells[0].full_width);
            try std.testing.expectEqual(chat, shells[0].full_width_pending_console_resize);
            try std.testing.expect(!shells[1].full_width_pending_console_resize);
            try std.testing.expectEqual(if (chat) @as(usize, 0) else 2, resizes);
            try std.testing.expectEqual(@as(usize, 2), saves);
            try std.testing.expectEqual(@as(usize, 2), layouts);
            try std.testing.expectEqual(chat, g_chat_active);
            try std.testing.expectEqual(pinned, shells[0].pinned_top);
            try std.testing.expect(shells[1].full_width);
        }
    }
    shells[0].pid = 0;
    resizes = 0;
    _ = toggleFullWidth(null);
    try std.testing.expectEqual(@as(usize, 0), resizes);
}

`;
}

test('ISSUE-440 executes the production toggle without resetting the Chat View console', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh440-'));
  try {
    copyZig(['chat_style.zig', 'chat_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    const zig = process.env.ZIG || path.join(os.homedir(), 'zig/zig');
    function run(handler, geometry) {
      fs.writeFileSync(file, harness(handler, geometry));
      return spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    }
    const result = run(toggle(source));
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    const oldHandler = toggle(source).replace('fullWidthShouldResizeConsole(g_chat_active)', 'true');
    assert.notEqual(oldHandler, toggle(source));
    const old = run(oldHandler);
    assert.notEqual(old.status, 0);
    assert.match(old.stderr, /production toggle[^]*FAIL/);
    const deadToggle = content(source).replace('if (full_width) slot.right - slot.left else uiScaled(760)', 'uiScaled(760)');
    const dead = run(toggle(source), deadToggle.replace(/    const full_width =[^\n]+\n/, ''));
    assert.notEqual(dead.status, 0);
    assert.match(dead.stderr, /production reading column[^]*FAIL/);
    console.log('ISSUE-440 old console reset and dead width toggle rejected');
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('ISSUE-440 palette, restoration and terminal return retain the same independent view and width state', () => {
  const palette = source.slice(source.indexOf('if (target == SEARCH_FULLWIDTH_OFFSET)'), source.indexOf('if (target == SEARCH_HIDESIDEBAR_OFFSET)'));
  assert.match(palette, /showActiveShellAfterOverlay\(\);[^]*WM_APP_TOGGLE_FULLWIDTH/);
  assert.doesNotMatch(palette, /closeChatView|toggleChatView|chat_view_lock\s*=/);
  const restore = body(source, 'restoreBrowserStateFromSavedTab');
  for (const field of ['chat_view_on = tab.cv', 'full_width = tab.fw']) assert.ok(restore.includes(field));
  const close = body(source, 'closeChatView');
  assert.match(close, /if \(ISSUE_440_FULL_WIDTH_CHAT and shells\[active_shell\]\.full_width_pending_console_resize\)/);
  assert.match(close, /full_width_pending_console_resize = false;[^]*applyBlackConsoleBackground/);
  assert.ok(close.indexOf('applyBlackConsoleBackground') < close.indexOf('showShellConsole'));
  assert.match(body(source, 'respawnShellInPlace'), /\.full_width = saved_full_width/);
  assert.ok(body(source, 'repositionActive').indexOf('if (g_chat_active)') < body(source, 'repositionActive').indexOf('activePaneContentRect(rc)'));
  assert.match(body(source, 'chatViewLayout'), /activePaneContentRect\(rc\)/);
});
