const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/chat_composer.zig'), 'utf8');
const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
const state = fs.readFileSync(path.join(root, 'src/app_state.zig'), 'utf8');

function fn(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  const end = text.indexOf('\n}', start);
  assert.ok(end > start, name);
  return text.slice(start, end + 2);
}
const names = ['fullWidthShouldResizeConsole', 'shellConsoleVisibilityAllowed', 'shellConsoleShouldBeVisible', 'showShellConsole', 'closeChatView', 'toggleChatView'];

function toggle(text) {
  const start = text.indexOf('        WM_APP_TOGGLE_FULLWIDTH => {');
  const end = text.indexOf('\n        WM_APP_RECONNECT =>', start);
  assert.ok(start >= 0 && end > start);
  return text.slice(start, end).replace('WM_APP_TOGGLE_FULLWIDTH => {', 'fn toggleFullWidth(hwnd: HANDLE) i32 {')
    .replace(/},\s*$/, '}').replaceAll('@import("chat_composer.zig").fullWidthShouldResizeConsole', 'fullWidthShouldResizeConsole');
}

function harness(source) {
  const production = names.map(name => fn(source, name)).join('\n\n')
    .replaceAll('@import("chat_find_ui.zig").close', 'closeFind')
    .replaceAll('@import("chat_session.zig").chatHistoryStreamsKeep', 'chatHistoryStreamsKeep').replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark')
    .replaceAll('@import("window_layout.zig").chatWorkingIndicatorSync', 'syncWorking')
    .replaceAll('@import("console.zig").applyBlackConsoleBackground', 'applyBlackConsoleBackground');
  return `const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
const app_state = @This();
const computer = struct {
    fn selected() bool { return false; }
    fn toggleFullWidth() void {}
};
const HANDLE = ?usize;
const BOOL = i32;
const SW_HIDE = 0;
const SW_SHOW = 5;
const TIMER_CHAT_BROWSER_SWAP = 1;
const TIMER_CHAT_REFRESH = 2;
const ISSUE_440_FULL_WIDTH_CHAT = true;
const chatViewShouldShowForTab = @import("chat_view.zig").shouldShow;
const Shell = struct { disconnected: bool = false, hwnd: HANDLE = 10, pid: u32 = 42, shell_id: u32 = 1, tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0, chat_view_on: bool = true, pinned_top: bool = false, full_width: bool = false, full_width_pending_console_resize: bool = false };
var shells = [_]Shell{ .{}, .{} };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_blocks = [_]struct { role: enum { tool }, tool_open: bool = false }{.{ .role = .tool }};
var g_chat_block_count: usize = 1;
var g_chat_layout_reuse: usize = 0;
var g_chat_active = true;
var g_restoring = false;
var g_startup_progress = false;
var g_search_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_snippet_create_active = false;
var g_inbox_active = false;
var g_all_sessions_active = false;
var g_chat_switch_browser_sid: u32 = 99;
var g_chat_switch_loading = true;
var g_chat_working_applied_len: usize = 1;
var g_chat_screen_status_len: usize = 1;
var g_chat_sel_transcript_focus = true;
var g_voice_mode_active = false;
var g_main_hwnd: HANDLE = 1;
var g_chat_status_hwnd: HANDLE = 2;
var g_chat_transcript_hwnd: HANDLE = 3;
var g_chat_composer_hwnd: HANDLE = 4;
var g_chat_browser_swap: struct { fn cancel(_: *@This()) void {} } = .{};
var visible = [_]bool{false} ** 11;
var theme_resets: usize = 0;
var layouts: usize = 0;
var focuses: usize = 0;
fn ShowWindow(hwnd: HANDLE, cmd: i32) BOOL { visible[hwnd.?] = cmd != SW_HIDE; return 1; }
fn ShowWindowAsync(hwnd: HANDLE, cmd: i32) BOOL { return ShowWindow(hwnd, cmd); }
fn IsWindowVisible(hwnd: HANDLE) BOOL { return @intFromBool(visible[hwnd.?]); }
fn verboseLoggingEnabled() bool { return false; }
fn debugLog(_: []const u8) void {}
fn closeFind(_: bool) void {}
fn chatAcClose() void {}
fn chatDraftFlush() void {}
fn chatReadMark(_: bool) bool { return false; }
fn consumePinnedBrowserEntry(_: u32) void {}
fn cancelPinnedBrowserEntry(_: u32) void {}
fn armPinnedBrowserEntry(_: u32) void {}
var stream_stops: usize = 0;
fn chatHistoryStreamsKeep(shell_id: u32) void { std.debug.assert(shell_id == 0); stream_stops += 1; }
fn syncWorking() void {}
fn chatSelectionClear() void {}
fn KillTimer(_: HANDLE, _: usize) BOOL { return 1; }
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?usize) usize { return 1; }
fn applyBlackConsoleBackground(_: u32) void { theme_resets += 1; }
fn repositionActive() void { layouts += 1; }
fn updateBrowserVisibility() void {}
fn focusActiveShell() void { focuses += 1; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) BOOL { return 1; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn openChatView() void { g_chat_active = true; }
fn saveSession() void {}
${production}
${toggle(main)}
fn prepare(pinned: bool, full: bool) void {
    stream_stops = 0;
    shells[0] = .{ .full_width = full, .pinned_top = pinned };
    shells[1] = .{ .hwnd = 9, .pid = 43, .full_width_pending_console_resize = true };
    active_shell = 0;
    g_chat_active = true;
    g_restoring = false;
    g_startup_progress = false;
    g_search_active = false;
    visible = @splat(false);
    visible[2] = true;
    visible[3] = true;
    visible[4] = true;
    theme_resets = 0;
    layouts = 0;
    focuses = 0;
}
test "IGSH-1655 Alt+C leaves a live chat open without revealing its parking console" {
    prepare(false, false);
    @memcpy(shells[0].tmux_session[0..9], "live-test");
    shells[0].tmux_session_len = 9;
    for (0..2) |_| {
        toggleChatView();
        try std.testing.expect(g_chat_active);
        try std.testing.expect(shells[0].chat_view_on);
    }
    try std.testing.expect(visible[3] and visible[4]);
    try std.testing.expect(!visible[10]);
    try std.testing.expectEqual(@as(usize, 0), stream_stops);
    try std.testing.expectEqual(@as(usize, 0), layouts);
}
test "IGSH-1655 Alt+C still toggles terminal tabs both ways" {
    prepare(false, false);
    @memcpy(shells[0].tmux_session[0..9], "term-test");
    shells[0].tmux_session_len = 9;
    toggleChatView();
    try std.testing.expect(!g_chat_active);
    try std.testing.expect(!shells[0].chat_view_on);
    try std.testing.expect(visible[10]);
    toggleChatView();
    try std.testing.expect(g_chat_active);
    try std.testing.expect(shells[0].chat_view_on);
}
test "close chat reveals native shell without resetting its buffer or font" {
    for ([_]bool{ false, true }) |pinned| {
        for ([_]bool{ false, true }) |full| {
            prepare(pinned, full);
            toggleChatView();
            try std.testing.expect(!g_chat_active);
            try std.testing.expect(visible[10]);
            try std.testing.expect(!visible[2] and !visible[3] and !visible[4]);
            try std.testing.expectEqual(@as(usize, 1), layouts);
            try std.testing.expectEqual(@as(usize, 1), focuses);
            try std.testing.expectEqual(@as(usize, 0), theme_resets);
            try std.testing.expect(!shells[0].full_width_pending_console_resize);
            try std.testing.expect(shells[1].full_width_pending_console_resize);
            try std.testing.expect(!shells[0].chat_view_on);
            try std.testing.expectEqual(pinned, shells[0].pinned_top);
        }
    }
}
test "pending full width resets exactly once on exit for pinned and unpinned tabs in either direction" {
    for ([_]bool{ false, true }) |pinned| {
        for ([_]bool{ false, true }) |full| {
            for ([_]usize{ 1, 2 }) |toggles| {
                prepare(pinned, full);
                for (0..toggles) |_| _ = toggleFullWidth(null);
                try std.testing.expectEqual(@as(usize, 0), theme_resets);
                try std.testing.expect(shells[0].full_width_pending_console_resize);
                try std.testing.expectEqual(if (toggles == 1) !full else full, shells[0].full_width);
                layouts = 0;
                toggleChatView();
                try std.testing.expect(!g_chat_active);
                try std.testing.expect(visible[10]);
                try std.testing.expect(!visible[2] and !visible[3] and !visible[4]);
                try std.testing.expectEqual(@as(usize, 1), layouts);
                try std.testing.expectEqual(@as(usize, 1), focuses);
                try std.testing.expectEqual(@as(usize, 1), theme_resets);
                try std.testing.expect(!shells[0].full_width_pending_console_resize);
                try std.testing.expect(shells[1].full_width_pending_console_resize);
                g_chat_active = true;
                closeChatView();
                try std.testing.expectEqual(@as(usize, 1), theme_resets);
            }
        }
    }
}
test "pending state is consumed for a shell with no process without resetting" {
    prepare(false, false);
    shells[0].pid = 0;
    _ = toggleFullWidth(null);
    try std.testing.expect(shells[0].full_width_pending_console_resize);
    closeChatView();
    try std.testing.expect(!shells[0].full_width_pending_console_resize);
    try std.testing.expectEqual(@as(usize, 0), theme_resets);
    try std.testing.expect(visible[10]);
}
test "closing chat stops receiving and folds steps before revealing the console" {
    prepare(false, false);
    g_chat_blocks[0].tool_open = true;
    closeChatView();
    try std.testing.expect(!g_chat_blocks[0].tool_open);
    try std.testing.expectEqual(@as(usize, 1), stream_stops);
    try std.testing.expect(visible[10]);
}
test "closing behind palette preserves containment until palette is dismissed" {
    prepare(false, false);
    g_search_active = true;
    closeChatView();
    try std.testing.expect(!visible[10]);
    g_search_active = false;
    _ = showShellConsole(0, SW_SHOW, "palette-dismiss");
    try std.testing.expect(visible[10]);
}
`;
}
test('per-shell deferred console resize defaults to false', () => {
  assert.match(state, /full_width_pending_console_resize: bool = false,/);
});

test('production Chat View exits reveal, lay out and focus without ordinary console resets', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-console-return-'));
  require('./fixtures/inline-stubs').writeRoomFrontend(dir);
  const zig = process.env.ZIG || path.join(os.homedir(), 'zig/zig');
  try {
    copyZig(['chat_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (harness(source)).replaceAll('@import("chat_session.zig").chatHistoryStreamsKeep', 'chatHistoryStreamsKeep').replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary').replaceAll('@import("browser_pane.zig").consumePinnedBrowserEntry', 'consumePinnedBrowserEntry').replaceAll('@import("browser_pane.zig").cancelPinnedBrowserEntry', 'cancelPinnedBrowserEntry').replaceAll('@import("browser_pane.zig").armPinnedBrowserEntry', 'armPinnedBrowserEntry'));
    const result = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('Computer takes the full width toggle while it is open', () => {
  assert.match(main, /if \(computer\.selected\(\)\) \{ computer\.toggleFullWidth\(\); return 0; \}/);
});
