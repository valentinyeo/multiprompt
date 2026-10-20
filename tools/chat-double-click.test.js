const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const clipboard = fs.readFileSync('src/clipboard.zig', 'utf8');
function body(name) {
  const start = clipboard.indexOf(`pub fn ${name}(`);
  assert.ok(start >= 0, name);
  return clipboard.slice(start, clipboard.indexOf('\n}', start) + 2);
}
function runHarness(unsafe = false) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh355-'));
  try {
    copyZig(['dblclick_toggle.zig'], dir);
    fs.writeFileSync(path.join(dir, 'win32.zig'), `
const t = @import("test.zig");
pub const WM_KEYDOWN = 0x100;
pub const WM_KEYUP = 0x101;
pub fn ReadConsoleOutputCharacterW(_: usize, out: [*]u16, len: u32, cell: t.COORD, read: *u32) i32 {
    if (t.fail_read) return 0;
    for (0..len) |i| out[i] = t.cells[@as(usize, @intCast(cell.y)) * 8 + @as(usize, @intCast(cell.x)) + i];
    read.* = len;
    return 1;
}
`);
    let code = body('consoleCellAtScreenPoint') + '\n' + body('shellDoubleClickAtScreenPoint');
    code = code.replaceAll('@import("chat_composer.zig").toggleChatView()', 'toggleChatView()');
    if (unsafe) code = code.replace('if (!toggle.shellCellBlank(c)) return;', 'if (!toggle.shellCellBlank(c) and false) return;');
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const app_state = @This();
pub const HANDLE = ?usize;
pub const DWORD = u32;
pub const POINT = struct { x: i32, y: i32 };
pub const RECT = struct { left: i32, top: i32, right: i32, bottom: i32 };
pub const COORD = struct { x: i16, y: i16 };
pub const CONSOLE_SCREEN_BUFFER_INFO = struct { dwSize: COORD, srWindow: RECT };
pub const CONSOLE_SELECTION_INFO = struct { dwFlags: u32, srSelection: struct { Left: i16, Top: i16, Right: i16, Bottom: i16 } };
var g_chat_active = false;
var g_chat_view_mode: enum { nowhere, per_session } = .per_session;
var active_shell: usize = 0;
var shell_count: usize = 1;
var shells = [_]struct { shell_id: u32 = 7, pid: u32 = 99, hwnd: HANDLE = 1 }{.{}};
pub var cells: [32]u16 = @splat(' ');
pub var fail_read = false;
var selected: CONSOLE_SELECTION_INFO = .{ .dwFlags = 0, .srSelection = .{ .Left = 1, .Top = 1, .Right = 3, .Bottom = 1 } };
var attached = false;
var escape_posts: usize = 0;
fn FreeConsole() i32 { attached = false; return 1; }
fn AttachConsole(_: u32) i32 { attached = true; return 1; }
fn GetStdHandle(_: u32) HANDLE { return 1; }
const STD_OUTPUT_HANDLE = 0;
const fixture_info: CONSOLE_SCREEN_BUFFER_INFO = .{ .dwSize = .{ .x = 8, .y = 4 }, .srWindow = .{ .left = 1, .top = 1, .right = 6, .bottom = 3 } };
fn GetConsoleScreenBufferInfo(_: usize, out: *CONSOLE_SCREEN_BUFFER_INFO) i32 { out.* = fixture_info; return 1; }
fn ScreenToClient(_: HANDLE, pt: *POINT) i32 { pt.x -= 100; pt.y -= 200; return 1; }
fn GetClientRect(_: HANDLE, rc: *RECT) i32 { rc.* = .{ .left = 0, .top = 0, .right = 60, .bottom = 60 }; return 1; }
fn GetConsoleSelectionInfo(out: *CONSOLE_SELECTION_INFO) i32 { out.* = selected; return 1; }
fn PostMessageW(_: HANDLE, _: u32, key: usize, _: isize) i32 {
    std.debug.assert(selected.dwFlags != 0 and key == 0x1b);
    escape_posts += 1; return 1;
}
fn toggleChatView() void { std.debug.assert(!attached); g_chat_active = true; }
fn debugLog(_: []const u8) void {}
${code}
test "production mapping honors viewport offsets and rejects outside points" {
    const cell = consoleCellAtScreenPoint(1, 115, 225, fixture_info).?;
    try std.testing.expectEqual(@as(i16, 2), cell.x);
    try std.testing.expectEqual(@as(i16, 2), cell.y);
    try std.testing.expect(consoleCellAtScreenPoint(1, 99, 220, fixture_info) == null);
    try std.testing.expect(consoleCellAtScreenPoint(1, 120, 199, fixture_info) == null);
    try std.testing.expect(consoleCellAtScreenPoint(1, 160, 220, fixture_info) == null);
}
test "production empty cell opens without Escape when there is no selection" {
    g_chat_active = false; selected.dwFlags = 0; escape_posts = 0;
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(g_chat_active);
    try std.testing.expectEqual(@as(usize, 0), escape_posts);
}
test "production blank selection alone receives Escape; text selection never toggles" {
    g_chat_active = false; selected.dwFlags = 3; escape_posts = 0;
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(g_chat_active);
    try std.testing.expectEqual(@as(usize, 2), escape_posts);
    g_chat_active = false; escape_posts = 0; cells[10] = 'W';
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(!g_chat_active);
    try std.testing.expectEqual(@as(usize, 0), escape_posts);
    cells[10] = ' ';
}
test "production refuses stale sessions, disabled Chat, nonblank cells and failed reads" {
    selected.dwFlags = 0; g_chat_active = false;
    shellDoubleClickAtScreenPoint(8, 115, 225);
    try std.testing.expect(!g_chat_active);
    g_chat_view_mode = .nowhere;
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(!g_chat_active);
    g_chat_view_mode = .per_session; cells[18] = 0x4e2d;
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(!g_chat_active);
    cells[18] = ' '; fail_read = true;
    shellDoubleClickAtScreenPoint(7, 115, 225);
    try std.testing.expect(!g_chat_active);
    fail_read = false;
}
`);
    return spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig')], { encoding: 'utf8', timeout: 120000 });
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('ISSUE-355 executes production console mapping and selection safety', () => {
  const result = runHarness();
  assert.equal(result.status, 0, result.stdout + result.stderr);
});
test('ISSUE-355 oracle rejects clearing a nonblank selection', () => {
  const result = runHarness(true);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /FAIL.*TestUnexpectedResult/);
});
test('ISSUE-355 routes physical double clicks without attaching or swallowing in the hook', () => {
  const source = fs.readFileSync('src/shortcuts.zig', 'utf8');
  const hook = source.slice(source.indexOf('fn staleAltMouseHookProc('), source.indexOf('fn installPermanentInputThreadHooks('));
  const toggle = hook.slice(0, hook.indexOf('    if (nCode == HC_ACTION and (wp == WM_LBUTTONDOWN'));
  assert.match(toggle, /LLMHF_INJECTED/);
  assert.match(toggle, /pointOverActiveShell/);
  assert.match(toggle, /WM_LBUTTONUP/);
  assert.match(toggle, /WM_APP_SHELL_DOUBLE_CLICK/);
  assert.doesNotMatch(toggle, /AttachConsole|return 1/);
  const render = fs.readFileSync('src/chat_render.zig', 'utf8');
  const dbl = render.slice(render.indexOf('        WM_LBUTTONDBLCLK =>'), render.indexOf('        WM_RBUTTONDOWN =>'));
  for (const hit of ['chatToolAt', 'chatTranscriptCopyAt', 'chatImageAt', 'chatTranscriptLinkAt']) assert.ok(dbl.indexOf(hit) < dbl.indexOf('toggle.chatTargetBlank'));
  assert.match(dbl, /g_chat_sel_active/);
  assert.match(dbl, /g_chat_echo_layout/);
  assert.match(dbl, /toggleChatView\(\)/);
  assert.match(dbl, /chatTranscriptMouseDown/);
});
function checkCheapHook(source) {
  const hook = source.slice(source.indexOf('fn staleAltMouseHookProc('));
  const cheap = hook.slice(0, hook.indexOf('        const eligible ='));
  assert.match(cheap, /\(wp == WM_LBUTTONDOWN or wp == WM_LBUTTONUP or wp == win.WM_MOUSEMOVE\)\)/);
  assert.match(cheap, /if \(wp != WM_LBUTTONDOWN and app_state\.g_shell_double_click_first == null and\s+app_state\.g_shell_double_click_pending == null\) break :double_click;\s+const ms:/);
  assert.match(cheap, /toggle\.trackedMouseAction\(wp == win.WM_MOUSEMOVE, within\) == \.clear/);
  assert.match(cheap, /if \(wp == win.WM_MOUSEMOVE or \(app_state\.g_shell_double_click_first == null and\s+app_state\.g_shell_double_click_pending == null\)\) break :double_click;/);
  assert.doesNotMatch(cheap, /pointOverActiveShell|WindowFromPoint|GetParent|IsWindowVisible|GetAsyncKeyState/);
}
test('ISSUE-355 hook filters events and exits mouse moves before window/key eligibility', () => {
  checkCheapHook(fs.readFileSync('src/shortcuts.zig', 'utf8'));
});
test('ISSUE-355 cost oracle rejects mouse moves falling through to eligibility', () => {
  const source = fs.readFileSync('src/shortcuts.zig', 'utf8');
  assert.throws(() => checkCheapHook(source.replace('if (wp == win.WM_MOUSEMOVE or (', 'if (false or (')), /AssertionError/);
});
