const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
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
  const main = fn(text, 'main');
  assert.match(main, /const hwnd = CreateWindowExW\(\s*0,\s*L\("ZigShell"\)/);
  const outside = text.replace(helper, '').replace(main, main.replace('_ = ShowWindow(hwnd, SW_SHOW);', ''));
  for (const call of outside.matchAll(/(?<![.\w])ShowWindow\(([^,\n]+), (SW_\w+)\)/g)) {
    if (call[2] === 'SW_HIDE') continue;
    assert.ok(['g_urlbar_hwnd', 'hw', 'g_chat_transcript_hwnd', 'g_chat_composer_hwnd', 'target', 'hwnd', 'owner_hwnd'].includes(call[1]), `unguarded reveal: ${call[0]}`);
    if (call[1] === 'hw') assert.ok(fn(text, 'moveBrowserEdgeMask').includes(call[0]), 'hw must be a browser mask');
    if (['target', 'hwnd', 'owner_hwnd'].includes(call[1])) assert.equal(call[2] === 'SW_SHOW' || call[2] === 'SW_SHOWNOACTIVATE', false, 'generic handles cannot reveal consoles');
  }
  const flags = [...text.matchAll(/SetWindowPos\([^;]+SWP_SHOWWINDOW[^;]+;/g)];
  assert.equal(flags.length, 1);
  assert.match(flags[0][0], /^SetWindowPos\(g_chat_ac_hwnd,/);
  const layout = fn(text, 'repositionActive');
  const geometryGuard = layout.indexOf('if (!shellConsoleShouldBeVisible(active_shell)) return;');
  assert.ok(geometryGuard >= 0 && geometryGuard < layout.indexOf('SetWindowPos('));
  const hide = layout.indexOf('SW_HIDE');
  assert.ok(hide >= 0 && hide < layout.indexOf('IsIconic('), 'even minimized frames must hide a re-shown console');
  const repairs = (layout.match(/verifyShellWindowSize\(/g) || []).length;
  assert.ok(repairs > 0);
  assert.equal((text.match(/verifyShellWindowSize\(/g) || []).length, repairs + 1, 'all size repair callers stay within guarded layout');
  const send = fn(text, 'sendLocalChatPromptEx');
  assert.doesNotMatch(send, /g_chat_active\s*=/, 'sending must not disable containment');
  assert.match(send, /!shellConsoleShouldBeVisible\(shell_index\)[^]*pasteTextToShellDirect\(shell_index, text\)/);
  const respawn = fn(text, 'respawnShellInPlace');
  assert.match(respawn, /const saved_chat_view_on = shells\[idx\]\.chat_view_on;/);
  assert.match(respawn, /\.chat_view_on = saved_chat_view_on,/);
  for (const name of ['restoreSession', 'closeAllSessions', 'closeUrlPickerInternal', 'showActiveShellAfterOverlay', 'switchToShell', 'finishStartupShell']) {
    assert.match(fn(text, name), /showShellConsole\(/, `${name} uses the shared show policy`);
  }
  for (const site of ['wndProc.WM_APP_FOCUS', 'wndProc.WM_APP_FOCUS_SHELL', 'wndProc.WM_COPYDATA', 'main.adopt']) {
    assert.ok(text.includes(`"${site}"`), `${site} uses the shared show policy`);
  }
  for (const name of ['reclaimShell', 'spawnShellWithSession', 'startupShellWorker']) {
    const body = fn(text, name);
    assert.ok(body.indexOf('SW_HIDE') < body.indexOf('SetParent('), `${name} hides before reparenting`);
  }
}

test('every console reveal is guarded; a new HWND alias bypass are rejected', () => {
  audit(source);
  assert.throws(() => audit(source + '\nfn leakedRepair() void { verifyShellWindowSize(hwnd, 0, 0, 1, 1); }'));
  assert.throws(() => audit(source + '\nfn leakedConsole() void { _ = ShowWindow(console_alias, SW_SHOW); }'));
  assert.throws(() => audit(source + '\nfn leakedConsole(hwnd: HANDLE) void { _ = ShowWindow(hwnd, SW_SHOW); }'));
  assert.throws(() => audit(source.replace('const hwnd = CreateWindowExW(\n        0,\n        L("ZigShell")', 'const hwnd = CreateWindowExW(\n        0,\n        L("ConsoleWindowClass")')));
  assert.throws(() => audit(source.replace('if (!shellConsoleShouldBeVisible(active_shell)) return;', '')));

});

function harness(text) {
  const production = ['shellConsoleVisibilityAllowed', 'shellConsoleShouldBeVisible', 'showShellConsole', 'closeUrlPickerInternal', 'sendLocalChatPromptEx', 'showActiveShellAfterOverlay'].map(name => fn(text, name)).join('\n\n');
  const pureTests = text.slice(text.indexOf('test "console visibility rejects'), text.indexOf('\nfn openChatView()', text.indexOf('test "console visibility rejects')));
  return `const std = @import("std");
const ReadBoundary = struct { index: ?usize = null, unknown: bool = false };
var g_chat_read_boundary: ReadBoundary = .{};
var g_chat_read_divider_y: i32 = 0;
var g_chat_scrolled_up = false;
fn chatReadBoundary() ReadBoundary { return .{}; }
fn chatReadMark(_: bool) bool { return false; }
const BOOL = i32;
const HANDLE = ?usize;
const SW_HIDE = 0;
const SW_SHOW = 5;
const SW_SHOWNOACTIVATE = 4;
const KEYEVENTF_KEYUP = 2;
const chatViewShouldShowForTab = @import("chat_view.zig").shouldShow;
const Shell = struct { workspace: u32 = 0, disconnected: bool = false, hwnd: HANDLE = null, shell_id: u32 = 0, chat_view_on: bool = false, pinned_top: bool = false };
var shells = [_]Shell{ .{ .hwnd = 1, .shell_id = 42 }, .{ .hwnd = 2, .shell_id = 43 } };
var shell_count: u32 = 2;
var active_shell: u32 = 0;
var g_chat_active = false;
var g_search_from_inbox = false;
var g_search_spawn_ws: u32 = 0;
var g_single_window = false;
var g_active_workspace: u32 = 0;
const g_chat_transcript_hwnd: HANDLE = 101;
const g_chat_composer_hwnd: HANDLE = 102;
var refreshes: usize = 0;
fn closeInbox(_: HANDLE) void { g_inbox_active = false; }
fn refreshChatTranscript(_: bool) void { refreshes += 1; }
fn SetFocus(_: HANDLE) HANDLE { return null; }
var g_restoring = false;
var g_startup_progress = false;
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
const g_chat_transcript_hwnd: HANDLE = 101;
const g_chat_composer_hwnd: HANDLE = 102;
fn layoutChatControls() void {}
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
test "IGSH-1059 overlay close restores chat without a live console" {
    g_chat_active = true;
    shells[0].hwnd = null;
    defer { shells[0].hwnd = 1; g_chat_active = false; }
    visible = false;
    const before = refreshes;
    showActiveShellAfterOverlay();
    try std.testing.expect(visible);
    try std.testing.expectEqual(before + 1, refreshes);
}
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
    visible = true;
    closeUrlPickerInternal(true);
    try std.testing.expect(!visible);
    try std.testing.expect(!g_url_picker_active);
    try std.testing.expectEqualStrings("[chatview] suppressed console show shell=42 from=closeUrlPickerInternal", log[0..log_len]);
    log_len = 0;
    debug_enabled = false;
    _ = showShellConsole(0, SW_SHOW, "focus");
    try std.testing.expectEqual(@as(usize, 0), log_len);
}
test "restore, delayed focus and adoption respect remembered views and pins" {
    g_restoring = true;
    defer g_restoring = false;
    for ([_]bool{ false, true }) |pinned| {
        shells[0].pinned_top = pinned;
        for ([_]bool{ false, true }) |remembered| {
            shells[0].chat_view_on = remembered;
            for ([_]bool{ false, true }) |chat| {
                g_chat_active = chat;
                for ([_][]const u8{ "restoreSession", "wndProc.WM_APP_FOCUS", "wndProc.WM_APP_FOCUS_SHELL", "respawnShellInPlace", "wndProc.WM_COPYDATA", "main.adopt" }) |site| {
                    _ = showShellConsole(0, SW_SHOWNOACTIVATE, site);
                    const want_chat = remembered;
                    try std.testing.expectEqual(!chat and !want_chat, visible);
                }
            }
        }
    }
    g_chat_active = false;
    shells[0].chat_view_on = false;
}
test "ISSUE-611 remembered chat hides during startup but a later per-session shell return works" {
    shells[0].chat_view_on = true;
    g_startup_progress = true;
    _ = showShellConsole(0, SW_SHOW, "main.adopt");
    try std.testing.expect(!visible);
    g_startup_progress = false;
    g_chat_active = true;
    _ = showShellConsole(0, SW_SHOW, "focus");
    try std.testing.expect(!visible);
    g_chat_active = false;
    shells[0].chat_view_on = false;
    _ = showShellConsole(0, SW_SHOW, "closeChatView");
    try std.testing.expect(visible);
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
    copyZig(['chat_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, (harness(source)).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const run = spawnSync(zig, ['test', file, '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(run.status, 0, run.stdout + run.stderr + JSON.stringify({ signal: run.signal, error: run.error?.message }));
    assert.match(run.stderr, /All \d+ tests passed/);
    console.log(run.stderr.trim());
    const broken = source.replace('if (!shellConsoleShouldBeVisible(idx)) {', 'if (false) {');
    assert.notEqual(broken, source);
    fs.writeFileSync(file, (harness(broken)).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const negative = spawnSync(zig, ['test', file, '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(negative.status, 0, 'an unconditional show must fail real execution');
    assert.match(negative.stderr, /URL picker close[^]*FAIL/, JSON.stringify({ status: negative.status, signal: negative.signal, error: negative.error?.message, stdout: negative.stdout }));
    const oldPicker = source.replace(fn(source, 'closeUrlPickerInternal'), fn(source, 'closeUrlPickerInternal').replace('showShellConsole(active_shell, SW_SHOW, "closeUrlPickerInternal")', 'ShowWindow(shells[active_shell].hwnd, SW_SHOW)'));
    assert.notEqual(oldPicker, source);
    fs.writeFileSync(file, (harness(oldPicker)).replaceAll('@import("chat_session.zig").chatReadMark', 'chatReadMark').replaceAll('@import("chat_session.zig").chatReadBoundary', 'chatReadBoundary'));
    const baseline = spawnSync(zig, ['test', file, '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.notEqual(baseline.status, 0, 'a raw-show picker mutation must fail real execution');
    assert.match(baseline.stderr, /URL picker close[^]*FAIL/, JSON.stringify({ status: baseline.status, signal: baseline.signal, error: baseline.error?.message, stdout: baseline.stdout }));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

function chatHandoffHarness(text) {
  const open = fn(text, 'openChatView')
    .replaceAll('@import("focus.zig").parkMainWindowBeforeActiveShellRemoval', 'parkMainWindowBeforeActiveShellRemoval')
    .replaceAll('@import("win32.zig").TIMER_CHAT_BROWSER_SWAP', 'TIMER_CHAT_BROWSER_SWAP')
    .replaceAll('@import("chat_switch.zig").paint_deadline_ms', '30');
  return `const std = @import("std");
const HANDLE = ?usize;
const SW_HIDE = 0;
const SW_SHOW = 5;
const TIMER_CHAT_BROWSER_SWAP = 1;
const g_main_hwnd: HANDLE = 100;
const g_chat_transcript_hwnd: HANDLE = 101;
const g_chat_composer_hwnd: HANDLE = 102;
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var shells = [_]struct { hwnd: HANDLE = 10, shell_id: u32 = 1, chat_view_on: bool = false }{.{}};
var g_chat_browser_swap = struct {
    shell_id: u32 = 1,
    fn request(self: *@This(), id: u32, _: u64) void { self.shell_id = id; }
}{};
var g_chat_switch_started: u64 = 0;
var g_chat_switch_browser_sid: u32 = 0;
var g_chat_switch_content_sid: u32 = 0;
var g_chat_switch_preparing = false;
var g_browser_focus_mode = false;
var g_shell_focused = true;
var g_chat_active = false;
var g_voice_deferred_text: [0]struct { shell_id: u32, len: usize, text: [1]u16 } = .{};
var foreground: HANDLE = 10;
var focused: HANDLE = 10;
var attached = false;
var hidden_while_foreground = false;
var hide_requested = false;
var controls_ready = true;
fn GetTickCount64() u64 { return 1000; }
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?usize) usize { return 1; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn closeWebView2() void {}
fn cancelShellRefocus(_: HANDLE) void {}
fn ensureChatControls() bool { return controls_ready; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn chatDraftBindToActive() void {}
fn chatDeferTranscriptLoad() void {}
fn layoutChatControls() void {}
fn insertTextIntoChatComposer(_: []const u16) void {}
fn verboseLoggingEnabled() bool { return false; }
fn debugLog(_: []const u8) void {}
fn GetForegroundWindow() HANDLE { return foreground; }
fn foregroundHwndIsOurs(hwnd: HANDLE) bool { return hwnd == g_main_hwnd or hwnd == shells[0].hwnd or hwnd == 20; }
fn focusGuard(_: HANDLE) bool { return foregroundHwndIsOurs(foreground); }
fn GetCurrentThreadId() u32 { return 1; }
fn GetWindowThreadProcessId(_: HANDLE, _: ?usize) u32 { return 2; }
fn AttachThreadInput(_: u32, _: u32, attach: i32) i32 { attached = attach != 0; return 1; }
fn SetForegroundWindow(hwnd: HANDLE) i32 {
    if (!focusGuard(hwnd)) return 0;
    if (foreground != g_main_hwnd and !attached) return 0;
    foreground = hwnd;
    return 1;
}
fn SetFocus(hwnd: HANDLE) HANDLE { if (foreground == g_main_hwnd) focused = hwnd; return null; }
fn ShowWindow(_: HANDLE, _: i32) i32 { return 1; }
fn ShowWindowAsync(hwnd: HANDLE, _: i32) i32 {
    hide_requested = true;
    hidden_while_foreground = foreground == hwnd;
    return 1;
}
${fn(text, 'parkMainWindowBeforeActiveShellRemoval')}
${open}
test "IGSH-955 chat takes foreground before asynchronously hiding the console" {
    for ([_]HANDLE{ 10, 20, 100 }) |initial| {
        foreground = initial;
        focused = initial;
        hide_requested = false;
        hidden_while_foreground = false;
        openChatView();
        try std.testing.expect(hide_requested);
        try std.testing.expect(!hidden_while_foreground);
        try std.testing.expectEqual(g_main_hwnd, foreground);
        try std.testing.expectEqual(g_chat_composer_hwnd, focused);
        try std.testing.expect(!attached);
    }
}
test "IGSH-955 background chat restore never takes another app's foreground" {
    foreground = 999;
    focused = 999;
    openChatView();
    try std.testing.expectEqual(@as(HANDLE, 999), foreground);
    try std.testing.expectEqual(@as(HANDLE, 999), focused);
    try std.testing.expect(!attached);
}
test "IGSH-955 failed chat control creation leaves console focus intact" {
    foreground = 10;
    focused = 10;
    hide_requested = false;
    controls_ready = false;
    openChatView();
    try std.testing.expect(!hide_requested);
    try std.testing.expectEqual(@as(HANDLE, 10), foreground);
    try std.testing.expectEqual(@as(HANDLE, 10), focused);
}
`;
}

test('IGSH-955 production chat handoff transfers cross-thread foreground before hiding; preserves background focus', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-handoff-zig-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, chatHandoffHarness(source));
    const result = spawnSync(process.env.ZIG || 'zig', ['test', file, '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, JSON.stringify({ signal: result.signal, error: result.error, stdout: result.stdout, stderr: result.stderr }));
    assert.match(result.stderr, /All 3 tests passed/);
    console.log(result.stderr.trim());
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

test('Alt+W hides native chat children, restores on Escape or Enter, and keeps one-link behavior', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'url-picker-'));
  try {
    const production = ['openUrlPicker', 'closeUrlPickerInternal', 'hideShellsForOverlay'].map(name => fn(source, name)).join('\n');
    fs.writeFileSync(path.join(dir, 'test.zig'), `const std = @import("std");
const HANDLE = ?usize;
const SW_HIDE = 0;
const SW_SHOW = 5;
const SW_SHOWNOACTIVATE = 4;
const SWP_HIDEWINDOW = 128;
const SWP_NOMOVE = 2;
const SWP_NOSIZE = 1;
const SWP_NOZORDER = 4;
const SWP_NOACTIVATE = 16;
const g_main_hwnd: HANDLE = 1;
const g_chat_transcript_hwnd: HANDLE = 2;
const g_chat_composer_hwnd: HANDLE = 3;
const g_chat_status_hwnd: HANDLE = 4;
var g_chat_active = true;
var g_url_picker_active = false;
var g_url_picker_count: u32 = 2;
var g_url_picker_sel: u32 = 0;
var shell_count: u32 = 1;
var active_shell: u32 = 0;
var shells = [_]struct { hwnd: HANDLE = 5 }{.{}};
var visible = [_]bool{false, true, true, true, true, false};
var browser_visible = true;
var focused: HANDLE = null;
var opened: ?u32 = null;
var autocomplete = true;
fn scanUrlsInActiveShell() void {}
fn openUrlByIndex(index: u32) void { opened = index; }
fn ShowWindow(hwnd: HANDLE, command: i32) i32 { if (hwnd) |h| { visible[h] = command != SW_HIDE; } return 1; }
fn SetWindowPos(hwnd: HANDLE, _: HANDLE, _: i32, _: i32, _: i32, _: i32, flags: u32) i32 { if (flags & SWP_HIDEWINDOW != 0) { _ = ShowWindow(hwnd, SW_HIDE); } return 1; }
fn SetFocus(hwnd: HANDLE) HANDLE { focused = hwnd; return null; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn hideActiveBrowser() void { browser_visible = false; }
fn hideAllBrowserChrome() void { browser_visible = false; }
fn closeWebView2() void {}
fn chatAcClose() void { autocomplete = false; }
fn showShellConsole(hwnd: u32, command: i32, _: []const u8) i32 { return ShowWindow(shells[hwnd].hwnd, if (g_chat_active) SW_HIDE else command); }
fn updateBrowserVisibility() void { browser_visible = !g_url_picker_active; }
fn focusActiveShell() void { focused = if (g_chat_active) g_chat_composer_hwnd else shells[active_shell].hwnd; }
fn layoutChatControls() void { _ = ShowWindow(g_chat_status_hwnd, if (g_url_picker_active) SW_HIDE else SW_SHOW); }
${production}
test "chat picker hides every child and autocomplete, then restores without stealing Enter focus" {
    for ([_]bool{ true, false }) |refocus| {
        visible = .{ false, true, true, true, true, false };
        browser_visible = true;
        autocomplete = true;
        openUrlPicker();
        try std.testing.expect(g_url_picker_active);
        try std.testing.expect(!visible[2] and !visible[3] and !visible[4]);
        try std.testing.expect(!browser_visible and !autocomplete);
        try std.testing.expectEqual(g_main_hwnd, focused);
        closeUrlPickerInternal(refocus);
        try std.testing.expect(!g_url_picker_active);
        try std.testing.expect(visible[2] and visible[3] and visible[4]);
        try std.testing.expect(!visible[5] and browser_visible);
        try std.testing.expectEqual(if (refocus) g_chat_composer_hwnd else g_main_hwnd, focused);
    }
}
test "no links leaves chat alone; one link opens directly" {
    g_url_picker_active = false;
    opened = null;
    g_url_picker_count = 0;
    openUrlPicker();
    try std.testing.expect(!g_url_picker_active and opened == null);
    g_url_picker_count = 1;
    openUrlPicker();
    try std.testing.expect(!g_url_picker_active);
    try std.testing.expectEqual(@as(?u32, 0), opened);
}
test "terminal picker hides and restores the shell" {
    g_chat_active = false;
    g_url_picker_count = 2;
    visible[5] = true;
    openUrlPicker();
    try std.testing.expect(!visible[5]);
    closeUrlPickerInternal(true);
    try std.testing.expect(visible[5]);
    try std.testing.expectEqual(shells[0].hwnd, focused);
}
`);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr + JSON.stringify({ signal: result.signal, error: result.error?.message }));
    assert.match(result.stderr, /All 3 tests passed/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

test('link selection uses the approved rounded dark control and outline, never the legacy blue fill', () => {
  const sidebar = fs.readFileSync(path.join(__dirname, '../src/sidebar.zig'), 'utf8');
  const picker = sidebar.slice(sidebar.indexOf('if (app_state.g_url_picker_active and app_state.g_url_picker_count > 0)'));
  const selected = picker.slice(picker.indexOf('if (abs_idx == app_state.g_url_picker_sel)'), picker.indexOf('var draw_buf:'));
  assert.match(selected, /design_tokens\.zig"\)\.ReaderControl/);
  assert.match(selected, /design_tokens\.zig"\)\.ReaderOutline/);
  assert.match(selected, /CreatePen\(0, 1,/);
  assert.match(selected, /drawRoundRect/);
  assert.doesNotMatch(selected, /RGB\(0, 122, 204\)|FillRect/);
});
