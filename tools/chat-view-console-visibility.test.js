const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const source = require('./app-source').readAppSource();

function fn(text, name) {
  const start = text.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const code = text.replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\/[^\n]*/g, value => value.replace(/[^\n]/g, ' '));
  const open = code.indexOf('{', start);
  let depth = 1;
  let end = open + 1;
  while (depth && end < text.length) {
    if (code[end] === '{') depth++;
    if (code[end] === '}') depth--;
    end++;
  }
  assert.equal(depth, 0);
  return text.slice(start, end);
}

function audit(text) {
  const helper = fn(text, 'showShellConsole');
  assert.match(helper, /if \(!shellConsoleShouldBeVisible\(idx\)\)/);
  assert.match(helper, /IsWindowVisible[^]*return ShowWindowAsync\(shells\[idx\]\.hwnd, SW_HIDE\);/);
  assert.match(helper, /verboseLoggingEnabled\(\)[^]*\[chatview\] suppressed console show shell=\{d\} from=\{s\}/);
  const outside = text.replace(helper, '');
  for (const call of outside.matchAll(/(?<![.\w])ShowWindow\(([^,\n]+), (SW_\w+)\)/g)) {
    if (call[2] === 'SW_HIDE') continue;
    assert.ok(['g_urlbar_hwnd', 'hw', 'g_chat_transcript_hwnd', 'g_chat_composer_hwnd', 'target', 'hwnd'].includes(call[1]), `unguarded reveal: ${call[0]}`);
    if (call[1] === 'hw') assert.ok(fn(text, 'moveBrowserEdgeMask').includes(call[0]), 'hw must be a browser mask');
    if (call[1] === 'target' || call[1] === 'hwnd') assert.equal(call[2] === 'SW_SHOW' || call[2] === 'SW_SHOWNOACTIVATE', false, 'generic handles cannot reveal consoles');
  }
  const flags = [...text.matchAll(/SetWindowPos\([^;]+SWP_SHOWWINDOW[^;]+;/g)];
  assert.equal(flags.length, 1);
  assert.match(flags[0][0], /^SetWindowPos\(g_chat_ac_hwnd,/);
  const layout = fn(text, 'repositionActive');
  const geometryGuard = layout.indexOf('if (!shellConsoleShouldBeVisible(active_shell)) return;');
  assert.ok(geometryGuard >= 0 && geometryGuard < layout.indexOf('SetWindowPos('));
  const hide = layout.indexOf('SW_HIDE');
  assert.ok(hide >= 0 && hide < layout.indexOf('IsIconic('), 'even minimized frames must hide a re-shown console');
  assert.equal((text.match(/verifyShellWindowSize\(/g) || []).length, 4, 'all size repair callers stay within guarded layout');
  const send = fn(text, 'sendLocalChatPromptEx');
  assert.doesNotMatch(send, /g_chat_active\s*=/, 'sending must not disable containment');
  assert.match(send, /!shellConsoleShouldBeVisible\(shell_index\)[^]*pasteTextToShellDirect\(shell_index, text\)/);
  const respawn = fn(text, 'respawnShellInPlace');
  assert.match(respawn, /const saved_chat_view_on = shells\[idx\]\.chat_view_on;/);
  assert.match(respawn, /\.chat_view_on = saved_chat_view_on,/);
  for (const name of ['restoreSession', 'closeAllSessions', 'closeUrlPickerInternal', 'showActiveShellAfterOverlay', 'switchToShell', 'respawnShellInPlace']) {
    assert.match(fn(text, name), /showShellConsole\(/, `${name} uses the shared show policy`);
  }
  for (const site of ['wndProc.WM_APP_FOCUS', 'wndProc.WM_APP_FOCUS_SHELL', 'wndProc.WM_COPYDATA', 'main.adopt']) {
    assert.ok(text.includes(`"${site}"`), `${site} uses the shared show policy`);
  }
  for (const name of ['reclaimShell', 'spawnShellWithSession', 'respawnShellInPlace']) {
    const body = fn(text, name);
    assert.ok(body.indexOf('SW_HIDE') < body.indexOf('SetParent('), `${name} hides before reparenting`);
  }
}

test('every console reveal is guarded; a new HWND alias bypass are rejected', () => {
  audit(source);
  assert.throws(() => audit(source + '\nfn leakedConsole() void { _ = ShowWindow(console_alias, SW_SHOW); }'));
  assert.throws(() => audit(source.replace('if (!shellConsoleShouldBeVisible(active_shell)) return;', '')));

});

function harness(text) {
  const production = ['chatViewShouldShowForTab', 'shellConsoleVisibilityAllowed', 'shellConsoleShouldBeVisible', 'showShellConsole', 'closeUrlPickerInternal', 'sendLocalChatPromptEx'].map(name => fn(text, name)).join('\n\n');
  const pureTests = text.slice(text.indexOf('test "console visibility rejects'), text.indexOf('\nfn openChatView()', text.indexOf('test "console visibility rejects')));
  return `const std = @import("std");
const BOOL = i32;
const HANDLE = ?usize;
const SW_HIDE = 0;
const SW_SHOW = 5;
const SW_SHOWNOACTIVATE = 4;
const KEYEVENTF_KEYUP = 2;
const ChatViewMode = enum { per_session, everywhere, nowhere };
const Shell = struct { hwnd: HANDLE = null, shell_id: u32 = 0, chat_view_on: bool = false };
var shells = [_]Shell{ .{ .hwnd = 1, .shell_id = 42 }, .{ .hwnd = 2, .shell_id = 43 } };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_active = false;
var g_restoring = false;
var g_startup_progress = false;
var g_chat_view_mode: ChatViewMode = .per_session;
var g_search_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_snippet_create_active = false;
var g_inbox_active = false;
var g_all_sessions_active = false;
const g_main_hwnd: HANDLE = 100;
var visible = true;
var debug_enabled = false;
var log: [512]u8 = undefined;
var log_len: usize = 0;
var direct_pastes: usize = 0;
var entered: usize = 0;
var native_pasted: usize = 0;
var input_ok = true;
fn ShowWindow(_: HANDLE, cmd: i32) BOOL { visible = cmd != SW_HIDE; return 1; }
fn IsWindowVisible(_: HANDLE) BOOL { return @intFromBool(visible); }
fn ShowWindowAsync(hwnd: HANDLE, cmd: i32) BOOL { return ShowWindow(hwnd, cmd); }
fn verboseLoggingEnabled() bool { return debug_enabled; }
fn debugLog(line: []const u8) void { @memcpy(log[0..line.len], line); log_len = line.len; }
fn updateBrowserVisibility() void {}
fn focusActiveShell() void {}
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn pasteTextToShellDirect(_: u32, _: []const u16) bool { direct_pastes += 1; return input_ok; }
fn sendEnterToShell(_: u32) bool { entered += 1; return input_ok; }
fn readClipboardTextWithRetry(_: []u16) usize { return 0; }
fn setUnicodeClipboardTextWithRetry(_: []const u16) bool { return true; }
fn OpenClipboard(_: HANDLE) i32 { return 1; }
fn EmptyClipboard() i32 { return 1; }
fn CloseClipboard() i32 { return 1; }
fn repositionActive() void {}
fn nativePasteToShell(_: u32) bool { native_pasted += 1; return true; }
fn Sleep(_: u32) void {}
fn keybd_event(_: u32, _: u32, _: u32, _: u32) void {}
${production}
${pureTests}
test "all pure decision combinations" {
    for ([_]bool{ false, true }) |active| {
        for ([_]bool{ false, true }) |chat| {
            for ([_]bool{ false, true }) |saved| {
                for ([_]bool{ false, true }) |covered| {
                    try std.testing.expectEqual(active and !chat and !saved and !covered, shellConsoleVisibilityAllowed(active, chat, saved, covered));
                }
            }
        }
    }
}
test "URL picker close cannot put raw SSH console over chat; debug logs identify the site" {
    g_chat_active = true;
    defer g_chat_active = false;
    g_url_picker_active = true;
    debug_enabled = true;
    defer debug_enabled = false;
    visible = true; // simulate conhost having independently re-shown itself
    closeUrlPickerInternal(true);
    try std.testing.expect(!visible);
    try std.testing.expect(!g_url_picker_active);
    try std.testing.expectEqualStrings("[chatview] suppressed console show shell=42 from=closeUrlPickerInternal", log[0..log_len]);
    log_len = 0;
    debug_enabled = false;
    _ = showShellConsole(0, SW_SHOW, "focus");
    try std.testing.expectEqual(@as(usize, 0), log_len);
}
test "restore, delayed focus and adoption respect remembered and global modes" {
    g_restoring = true;
    defer g_restoring = false;
    for ([_]ChatViewMode{ .per_session, .everywhere, .nowhere }) |mode| {
        g_chat_view_mode = mode;
        for ([_]bool{ false, true }) |remembered| {
            shells[0].chat_view_on = remembered;
            for ([_]bool{ false, true }) |chat| {
                g_chat_active = chat;
                for ([_][]const u8{ "restoreSession", "wndProc.WM_APP_FOCUS", "wndProc.WM_APP_FOCUS_SHELL", "respawnShellInPlace", "wndProc.WM_COPYDATA", "main.adopt" }) |site| {
                    _ = showShellConsole(0, SW_SHOWNOACTIVATE, site);
                    const want_chat = mode == .everywhere or (mode == .per_session and remembered);
                    try std.testing.expectEqual(!chat and !want_chat, visible);
                }
            }
        }
    }
    g_chat_view_mode = .per_session;
    g_chat_active = false;
    shells[0].chat_view_on = false;
}
test "Everywhere startup hides before controls exist, but an explicit return to Terminal works" {
    g_chat_view_mode = .everywhere;
    g_startup_progress = true;
    _ = showShellConsole(0, SW_SHOW, "main.adopt");
    try std.testing.expect(!visible);
    g_startup_progress = false;
    g_chat_active = true;
    _ = showShellConsole(0, SW_SHOW, "focus");
    try std.testing.expect(!visible);
    g_chat_active = false;
    _ = showShellConsole(0, SW_SHOW, "closeChatView");
    try std.testing.expect(visible);
    g_chat_view_mode = .per_session;
}
test "inactive, missing and out-of-range shells never qualify; overlays stay hidden" {
    try std.testing.expect(!shellConsoleShouldBeVisible(1));
    try std.testing.expect(!shellConsoleShouldBeVisible(2));
    shells[0].hwnd = null;
    try std.testing.expect(!shellConsoleShouldBeVisible(0));
    shells[0].hwnd = 1;
    for ([_]*bool{ &g_search_active, &g_shortcuts_active, &g_changelog_active, &g_url_picker_active, &g_snippet_create_active, &g_inbox_active, &g_all_sessions_active }) |overlay| {
        overlay.* = true;
        _ = showShellConsole(0, SW_SHOW, "overlay close");
        try std.testing.expect(!visible);
        overlay.* = false;
    }
    _ = showShellConsole(0, SW_SHOW, "terminal");
    try std.testing.expect(visible);
}
test "local Chat View input and Enter keep console hidden without flipping chat state" {
    g_chat_active = true;
    visible = false;
    try std.testing.expect(sendLocalChatPromptEx(0, &.{'x'}, true));
    try std.testing.expect(g_chat_active and !visible);
    try std.testing.expectEqual(@as(usize, 1), direct_pastes);
    try std.testing.expectEqual(@as(usize, 1), entered);
    try std.testing.expect(sendLocalChatPromptEx(0, &.{'y'}, false));
    try std.testing.expectEqual(@as(usize, 1), entered);
    input_ok = false;
    try std.testing.expect(!sendLocalChatPromptEx(0, &.{'z'}, true));
    try std.testing.expectEqual(@as(usize, 1), entered);
    input_ok = true;
    try std.testing.expectEqual(@as(usize, 0), native_pasted);
    g_chat_active = false;
    try std.testing.expect(sendLocalChatPromptEx(0, &.{'t'}, true));
    try std.testing.expectEqual(@as(usize, 1), native_pasted);
    try std.testing.expect(visible);
}
`;
}

test('executed production Zig decision, show, picker-close and input paths pass; an unconditional reveal fails', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-console-zig-'));
  const zig = process.env.ZIG || 'zig';
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, harness(source));
    const run = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(run.status, 0, run.stdout + run.stderr);
    assert.match(run.stderr, /All \d+ tests passed/);
    console.log(run.stderr.trim());
    const broken = source.replace('if (!shellConsoleShouldBeVisible(idx)) {', 'if (false) {');
    assert.notEqual(broken, source);
    fs.writeFileSync(file, harness(broken));
    const negative = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0, 'an unconditional show must fail real execution');
    assert.match(negative.stderr, /URL picker close[^]*FAIL/);
    const oldPicker = source.replace(fn(source, 'closeUrlPickerInternal'), fn(source, 'closeUrlPickerInternal').replace('showShellConsole(active_shell, SW_SHOW, "closeUrlPickerInternal")', 'ShowWindow(shells[active_shell].hwnd, SW_SHOW)'));
    assert.notEqual(oldPicker, source);
    fs.writeFileSync(file, harness(oldPicker));
    const baseline = spawnSync(zig, ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(baseline.status, 0, 'a raw-show picker mutation must fail real execution');
    assert.match(baseline.stderr, /URL picker close[^]*FAIL/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
