const { copyZig } = require('./zig-copy');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name), 'utf8');
const consoleSource = read('console.zig');
const chat = read('chat_composer.zig');
const main = read('main.zig');
const workspace = read('workspaces.zig');

function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  const end = source.indexOf('\n}', start);
  assert.ok(start >= 0 && end > start, name);
  return source.slice(start, end + 2);
}

function between(source, start, end) {
  const a = source.indexOf(start);
  const b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} ... ${end}`);
  return source.slice(a, b);
}

function handler(name, next, signature) {
  return between(main, `        ${name} => {`, `        ${next} =>`)
    .replace(`${name} => {`, `fn ${signature} {`).replace(/},\s*$/, '}');
}

function creation(name, signature) {
  const body = fn(consoleSource, name);
  const block = between(body, '    if (CreateProcessW(', '    var style = GetWindowLongPtrW(').replace('    if (cmd_hwnd != null) {\n', '');
  return `fn ${signature} bool {
    const title_id: usize = 1;
    var si = std.mem.zeroes(STARTUPINFOW);
    var pi = std.mem.zeroes(PROCESS_INFORMATION);
    const cmd_ptr = L("shell");
    ${name === 'spawnShellWithSession' ? 'const cwd_ptr = null;' : ''}
    ${block}
    installConsole(pi.dwProcessId, kind, slot);
    return true;
  }`;
}

function harness() {
  const core = ['applyThemedConsoleFont', 'applyBlackConsoleBackground', 'applyConsoleThemeToAllShells',
    'mainWindowDpi', 'syncMainWindowDpi', 'baseFont96', 'viewportGrowthNeedsRemoteRedraw',
    'normalizeAttachedConsoleViewport', 'normalizeConsoleFont', 'fontGenStale', 'nextStaleFontShell',
    'staleFontShellCount', 'fontSyncMarkAllStale', 'fontSyncActiveNow', 'fontSyncShell',
    'fontSyncTimerTick', 'settleConsoleGeometry', 'reclaimShell', 'registerBundledConsoleFonts',
    'unregisterBundledConsoleFonts'].map(name => fn(consoleSource, name)).join('\n');
  const visibility = ['fullWidthShouldResizeConsole', 'chatViewShouldShowForTab', 'shellConsoleVisibilityAllowed',
    'shellConsoleShouldBeVisible', 'showShellConsole', 'closeChatView', 'toggleChatView']
    .map(name => fn(chat, name)).join('\n');
  const bundled = between(consoleSource, 'pub const BundledConsoleFonts = struct {', '\npub fn registerBundledConsoleFonts');
  const tab = between(fn(consoleSource, 'switchToShell'), '                _ = showShellConsole(idx, SW_SHOW, "switchToShell");', '\n            }');
  const layoutSync = between(read('window_layout.zig'), '    if (fontGenStale(', '\n    const nudge');
  const poll = between(read('shell_poll.zig'), '        if (i == app_state.active_shell', '\n\n        if (local_cmd_shell)');
  const production = (core + visibility + bundled + '\n' +
    creation('spawnShellWithSession', 'spawnSession(kind: ShellKind, slot: usize)') + '\n' +
    creation('respawnShellInPlace', 'reconnectSession(kind: ShellKind, slot: usize)') + '\n' +
    fn(workspace, 'switchToWorkspace') + '\n' + fn(workspace, 'starredShellVisible') + '\n' +
    fn(workspace, 'refreshStarredWorkspace') + '\n' + fn(read('inbox.zig'), 'inboxPublishesShell') + '\n' +
    fn(workspace, 'pickWorkspaceTarget').replace(/\bshells\b/g, 'candidates') + '\n' +
    handler('WM_APP_TOGGLE_FULLWIDTH', 'WM_APP_RECONNECT', 'toggleFullWidth(hwnd: HANDLE) i32') + '\n' +
    handler('WM_DPICHANGED', 'WM_MOVE', 'dpiChanged(hwnd: HANDLE, wp: usize, lp: isize) i32') + '\n' +
    handler('WM_APP_FONT_BIGGER', 'WM_APP_FONT_SMALLER', 'zoomBigger(hwnd: HANDLE) i32') + '\n' +
    handler('WM_APP_FONT_SMALLER', 'WM_APP_FONT_RESET', 'zoomSmaller(hwnd: HANDLE) i32') + '\n' +
    handler('WM_APP_FONT_RESET', 'WM_APP_NEW_TAB_DEFAULT', 'zoomReset(hwnd: HANDLE) i32') + `
fn switchToShell(idx: u32) void {
    ${between(fn(consoleSource, 'switchToShell'), '    app_state.active_shell = idx;', '\n    parkStrayBrowserPanes')}
    ${tab}
}
fn repositionActive() void {
    if (g_chat_active or active_shell >= shell_count) return;
    ${layoutSync}
}
fn pollFonts() void {
    for (0..shell_count) |i| {
        const det_pid = shells[i].pid;
        ${poll}
    }
}
`).replaceAll('@import("fonts.zig")', 'font_policy')
    .replaceAll('@import("win32.zig")', 'win32')
    .replaceAll('@import("chat_find_ui.zig").close', 'closeFind')
    .replaceAll('@import("window_layout.zig").chatWorkingIndicatorSync', 'syncWorking')
    .replaceAll('@import("console.zig").', '')
    .replaceAll('@import("inbox.zig").', '')
    .replaceAll('@import("chat_composer.zig").closeChatView', 'closeChatView')
    .replaceAll('@import("chat_composer.zig").fullWidthShouldResizeConsole', 'fullWidthShouldResizeConsole');
  const fontConstants = read('fonts.zig').split('\n').filter(line => /^pub const (?:SHELL_FACE|SHELL_WEIGHT|MONO_FACE|MONO_SEMIBOLD) =/.test(line)).join('\n');
  return prelude + `\nconst font_policy = struct { ${fontConstants} };\n` + production + tests;
}

const prelude = String.raw`
const std = @import("std");
const app_state = @This();
const win32 = @This();
fn L(comptime text: []const u8) [*:0]const u16 { return std.unicode.utf8ToUtf16LeStringLiteral(text); }
const HANDLE = ?usize;
const BOOL = i32;
const DWORD = u32;
const WORD = u16;
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
const ChatViewMode = enum { per_session, everywhere, nowhere };
const COORD = struct { x: i16 = 9, y: i16 = 18 };
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 1200, bottom: i32 = 540 };
const SMALL_RECT = struct { left: i16 = 0, top: i16 = 0, right: i16 = 99, bottom: i16 = 29 };
const CONSOLE_FONT_INFOEX = struct { cbSize: u32 = 0, nFont: u32 = 0, dwFontSize: COORD = .{}, FontFamily: u32 = 54, FontWeight: u32 = 400, FaceName: [32]u16 = @splat(0) };
const CONSOLE_SCREEN_BUFFER_INFOEX = struct { cbSize: u32 = 0, dwSize: COORD = .{ .x = 100, .y = 100 }, srWindow: SMALL_RECT = .{}, ColorTable: [16]u32 = @splat(0), wAttributes: u16 = 7 };
const PROCESS_INFORMATION = struct { dwProcessId: u32 = 0, hThread: HANDLE = null, hProcess: HANDLE = null };
const STARTUPINFOW = struct { cb: u32 = 0 };
const Shell = struct {
    hwnd: HANDLE = null, process: HANDLE = null, pid: u32 = 0, kind: ShellKind = .cmd,
    shell_id: u32 = 0, full_width: bool = false, console_font_logged: bool = false,
    base_font_h: i16 = 0, base_font_w: i16 = 0, base_font_dpi: i32 = 96,
    base_font_face: [32]u16 = makeFace("Courier New"), base_font_family: u32 = 0, base_font_weight: u32 = 700,
    font_gen: u32 = 0, workspace: u8 = 0, last_active: u64 = 0, last_viewed: u64 = 0,
    chat_view_on: bool = false, chat_shell_override: bool = true, full_width_pending_console_resize: bool = false,
    hidden: bool = false, inbox_archived: bool = false, needs_attention: bool = false, disconnected: bool = false,
    favorite: bool = false, inbox_excluded: bool = false,
};
const empty_shell: Shell = .{};
const MAX_SHELLS = 8;
const LOOK_UNIFIED = true;
const ISSUE_441 = true;
const ISSUE_440_FULL_WIDTH_CHAT = true;
const ISSUE_373_SHELL_OVERRIDE = true;
const DEV_SHELL_COLS = 100;
const SW_HIDE = 0;
const SW_SHOW = 5;
const PROCESS_QUERY_INFORMATION = 1;
const PROCESS_TERMINATE = 2;
const PROCESS_SYNCHRONIZE = 4;
const STILL_ACTIVE = 259;
const CREATE_NEW_CONSOLE = 1;
const STD_OUTPUT_HANDLE = 0;
const GWL_STYLE = 0;
const WS_CAPTION = 1;
const WS_THICKFRAME = 2;
const WS_BORDER = 4;
const WS_CHILD = 8;
const SWP_FRAMECHANGED = 1;
const SWP_NOZORDER = 2;
const SWP_NOMOVE = 4;
const SWP_NOSIZE = 8;
const SWP_NOACTIVATE = 16;
const TIMER_FONT_SYNC = 1;
const FONT_SYNC_TICK_MS = 20;
const TIMER_CHAT_BROWSER_SWAP = 2;
const TIMER_CHAT_REFRESH = 3;
const CHAT_FONT_DEFAULT_PT = 16;
const GENERIC_READ = 1;
const GENERIC_WRITE = 2;
const FILE_SHARE_READ = 1;
const OPEN_EXISTING = 1;
const CREATE_ALWAYS = 2;
const FILE_ATTRIBUTE_NORMAL = 0;
const INVALID_HANDLE_VALUE_PTR: HANDLE = 9999;
const SPAWN_TITLES = [_][*:0]const u16{L("zero"), L("one")};
var shells: [MAX_SHELLS]Shell = @splat(.{});
var shell_count: u32 = 0;
var active_shell: u32 = 0;
var next_shell_id: u32 = 1;
var g_main_hwnd: HANDLE = 1;
var g_job: HANDLE = null;
var g_main_monitor_dpi: u32 = 96;
var g_console_font_override: i16 = 0;
var g_dev_console_cell_w: i32 = 9;
var g_dev_theme: struct { console_font_height: i32 = 18, console_palette: [16]u32 = @splat(0) } = .{};
var g_dev_saved_console_theme_valid = false;
var g_dev_saved_console_palette: [16]u32 = @splat(0);
var g_dev_saved_console_attr: u16 = 7;
var g_dev_saved_console_font: CONSOLE_FONT_INFOEX = .{};
var g_light_theme = false;
var g_font_gen: u32 = 1;
var g_font_sync_started: u64 = 0;
var g_font_sync_done: usize = 0;
var g_monitor_transition: struct { active: bool = false, expected_valid: bool = false, expected_frame: RECT = .{} } = .{};
var g_chat_view_mode: ChatViewMode = .per_session;
var g_chat_active = false;
var g_restoring = false;
var g_startup_progress = false;
var g_search_active = false;
var g_shortcuts_active = false;
var g_changelog_active = false;
var g_url_picker_active = false;
var g_snippet_create_active = false;
var g_inbox_active = false;
var g_all_sessions_active = false;
var g_chat_switch_browser_sid: u32 = 0;
var g_chat_switch_loading = false;
var g_chat_working_applied_len: usize = 0;
var g_chat_screen_status_len: usize = 0;
var g_chat_sel_transcript_focus = false;
var g_voice_mode_active = false;
var g_chat_status_hwnd: HANDLE = null;
var g_chat_transcript_hwnd: HANDLE = null;
var g_chat_composer_hwnd: HANDLE = null;
var g_chat_font_pt: u32 = 16;
var g_chat_browser_swap: struct { shell_id: u32 = 0, fn cancel(_: *@This()) void {} } = .{};
var g_browser_focus_mode = false;
var g_single_window = true;
var g_starred_workspace = false;
var g_starred_last_shell: u32 = 0;
var g_inbox_step_context_active = false;
const TIMER_INBOX_REFRESH = 1;
var g_lws_count: u32 = 2;
var g_ws_snoozed: [2]bool = @splat(false);
var g_active_workspace: u8 = 0;
var g_account_applying = false;
var g_ws_last_shell: [2]u32 = @splat(0);
var g_focus_user_action_tick: u64 = 0;
var g_sidebar_scroll: i32 = 0;
var g_nudge_repaint = false;
const Console = struct { live: bool = false, font: CONSOLE_FONT_INFOEX = .{ .FaceName = makeFace("Courier New") }, buffer: CONSOLE_SCREEN_BUFFER_INFOEX = .{}, last_requested: [32]u16 = @splat(0) };
var consoles: [32]Console = @splat(.{});
var attached: usize = 0;
var next_pid: u32 = 2;
var latest_pid: u32 = 0;
var registered_fonts: [8][]const u8 = undefined;
var registered_font_count: usize = 0;
var last_written: []const u8 = &.{};
var registrations: usize = 0;
var removals: usize = 0;
var writes: usize = 0;
var resets: usize = 0;
var redraws: usize = 0;
var read_failures: usize = 0;
var fail_set = false;
var reject_shell_font = false;
var fail_attach = false;
var fail_registration = false;
var selection_errors: usize = 0;
var test_pane_h: i32 = 540;
var geometry_pending = false;
var events: [256]enum { register, create, reset, font, expose } = undefined;
var event_count: usize = 0;
fn event(e: @TypeOf(events[0])) void { events[event_count] = e; event_count += 1; }
fn makeFace(comptime text: []const u8) [32]u16 { var result: [32]u16 = @splat(0); for (text, 0..) |c, i| result[i] = c; return result; }
fn FreeConsole() BOOL { attached = 0; return 1; }
fn AttachConsole(pid: DWORD) BOOL { if (fail_attach or pid >= consoles.len or !consoles[pid].live) return 0; attached = pid; return 1; }
fn GetStdHandle(_: u32) HANDLE { return if (attached != 0) attached else null; }
fn GetCurrentConsoleFontEx(_: HANDLE, _: i32, font: *CONSOLE_FONT_INFOEX) BOOL { if (read_failures > 0) { read_failures -= 1; return 0; } font.* = consoles[attached].font; return 1; }
fn SetCurrentConsoleFontEx(_: HANDLE, _: i32, font: *CONSOLE_FONT_INFOEX) BOOL {
    event(.font); writes += 1;
    if (fail_set) return 0;
    const c = &consoles[attached]; c.font = font.*; c.font.dwFontSize.x = 9; c.last_requested = font.FaceName;
    if (reject_shell_font or !gdiSelects(std.mem.sliceTo(&font.FaceName, 0))) c.font.FaceName = makeFace("Courier New");
    return 1;
}
fn GetConsoleScreenBufferInfoEx(_: HANDLE, info: *CONSOLE_SCREEN_BUFFER_INFOEX) BOOL { info.* = consoles[attached].buffer; return 1; }
fn SetConsoleScreenBufferInfoEx(_: HANDLE, info: *CONSOLE_SCREEN_BUFFER_INFOEX) BOOL {
    event(.reset); resets += 1; consoles[attached].buffer = info.*;
    consoles[attached].buffer.srWindow.bottom -= 1;
    consoles[attached].font.FaceName = makeFace("Courier New"); consoles[attached].font.dwFontSize.y = 8;
    return 1;
}
fn GetClientRect(_: HANDLE, rc: *RECT) BOOL { rc.* = .{ .bottom = test_pane_h }; return 1; }
fn FillConsoleOutputAttribute(_: HANDLE, _: WORD, _: DWORD, _: COORD, written: *DWORD) BOOL { written.* = 0; return 1; }
fn SIDEBAR_W() i32 { return 200; }
fn devThemeOn() bool { return false; }
fn ensureDevThemeInitialized() void {}
fn themeConsoleBg() u32 { return 0; }
fn themeConsoleFg() u32 { return 7; }
fn verboseLoggingEnabled() bool { return false; }
fn debugLog(text: []const u8) void { if (std.mem.indexOf(u8, text, "selection failed") != null) selection_errors += 1; }
fn requestRemoteTmuxPaneRedraw(_: u32) void { redraws += 1; }
fn shellProcessAliveForRead(i: usize) bool { return shells[i].pid != 0 and consoles[shells[i].pid].live; }
fn GetTickCount64() u64 { return 1; }
fn SetTimer(_: HANDLE, _: usize, _: u32, _: ?usize) usize { return 1; }
fn KillTimer(_: HANDLE, _: usize) BOOL { return 1; }
fn GetDpiForWindow(_: HANDLE) u32 { return g_main_monitor_dpi; }
fn resetGdiCache() void {}
fn beginMonitorTransitionAtCurrent(_: HANDLE, _: enum { detected_crossing }) void {}
fn armMonitorTransitionTimer(_: HANDLE) void {}
fn armConsoleGeometrySettle(_: HANDLE) void { geometry_pending = true; }
fn OpenProcess(_: u32, _: i32, pid: u32) HANDLE { return pid; }
fn GetExitCodeProcess(_: HANDLE, code: *u32) BOOL { code.* = STILL_ACTIVE; return 1; }
fn CloseHandle(_: HANDLE) BOOL { return 1; }
fn findConsoleWindowByPid(pid: u32) HANDLE { return pid; }
fn findWindowByClassAndPid(pid: u32, _: []const u8) HANDLE { return pid; }
fn SetParent(hwnd: HANDLE, _: HANDLE) HANDLE { return hwnd; }
fn ShowWindow(hwnd: HANDLE, cmd: i32) BOOL { if (cmd != SW_HIDE and hwnd != null) event(.expose); return 1; }
fn IsWindowVisible(_: HANDLE) BOOL { return 0; }
fn ShowWindowAsync(hwnd: HANDLE, cmd: i32) BOOL { return ShowWindow(hwnd, cmd); }
fn GetWindowLongPtrW(_: HANDLE, _: i32) isize { return 0; }
fn SetWindowLongPtrW(_: HANDLE, _: i32, _: isize) isize { return 0; }
fn SetWindowPos(_: HANDLE, _: HANDLE, _: i32, _: i32, _: i32, _: i32, _: u32) BOOL { return 1; }
fn AssignProcessToJobObject(_: HANDLE, _: HANDLE) BOOL { return 1; }
fn registerShellExitWait(_: usize) void {}
fn CreateProcessW(_: ?usize, _: [*:0]const u16, _: ?usize, _: ?usize, _: i32, _: u32, _: ?usize, _: ?usize, _: *STARTUPINFOW, pi: *PROCESS_INFORMATION) BOOL {
    event(.create); latest_pid = next_pid; next_pid += 1; consoles[latest_pid] = .{ .live = true };
    pi.* = .{ .dwProcessId = latest_pid, .hThread = latest_pid, .hProcess = latest_pid }; return 1;
}
fn FindWindowW(_: ?usize, _: [*:0]const u16) HANDLE { return latest_pid; }
fn Sleep(_: u32) void {}
fn TerminateProcess(pid: HANDLE, _: u32) BOOL { consoles[pid.?].live = false; return 1; }
fn isRemoteShellKind(kind: ShellKind) bool { return kind == .vps or kind == .vps2 or kind == .tmux; }
fn sshSpawnFailed() void {}
fn installConsole(pid: u32, kind: ShellKind, slot: usize) void {
    shells[slot] = .{ .pid = pid, .process = pid, .hwnd = pid, .kind = kind, .shell_id = pid };
    shell_count = @max(shell_count, @as(u32, @intCast(slot + 1)));
}
fn GetEnvironmentVariableW(_: [*:0]const u16, buf: []u16, _: usize) u32 { buf[0] = 'X'; return 1; }
fn CreateDirectoryW(_: [*:0]const u16, _: ?usize) BOOL { return 1; }
fn CreateFileW(_: [*:0]const u16, access: u32, _: u32, _: ?usize, _: u32, _: u32, _: HANDLE) HANDLE { return if (access == GENERIC_READ) INVALID_HANDLE_VALUE_PTR else 500; }
fn GetFileSizeEx(_: HANDLE, size: *i64) BOOL { size.* = 0; return 1; }
fn WriteFile(_: HANDLE, data: []const u8, len: usize, written: *u32, _: ?usize) BOOL { last_written = data; written.* = @intCast(len); return 1; }
fn AddFontResourceExW(_: [*:0]const u16, flags: u32, _: ?usize) i32 {
    event(.register); if (fail_registration) return 0;
    registrations += 1;
    if (flags == 0) { registered_fonts[registered_font_count] = last_written; registered_font_count += 1; }
    return 1;
}
fn sfntTable(file: []const u8, tag: *const [4]u8) []const u8 {
    if (file.len < 12) return &.{};
    for (0..std.mem.readInt(u16, file[4..6], .big)) |i| {
        const record = file[12 + i * 16 ..][0..16];
        if (!std.mem.eql(u8, record[0..4], tag)) continue;
        return file[std.mem.readInt(u32, record[8..12], .big)..][0..std.mem.readInt(u32, record[12..16], .big)];
    }
    return &.{};
}
fn gdiFamily(file: []const u8, face: []const u16) bool {
    const name = sfntTable(file, "name");
    if (name.len < 6) return false;
    const strings = name[std.mem.readInt(u16, name[4..6], .big)..];
    for (0..std.mem.readInt(u16, name[2..4], .big)) |i| {
        const record = name[6 + i * 12 ..][0..12];
        if (std.mem.readInt(u16, record[0..2], .big) != 3 or std.mem.readInt(u16, record[6..8], .big) != 1) continue;
        const text = strings[std.mem.readInt(u16, record[10..12], .big)..][0..std.mem.readInt(u16, record[8..10], .big)];
        if (text.len != face.len * 2) continue;
        for (face, 0..) |c, j| {
            if (std.mem.readInt(u16, text[j * 2 ..][0..2], .big) != c) break;
        } else return true;
    }
    return false;
}
fn gdiSelects(face: []const u16) bool {
    for (registered_fonts[0..registered_font_count]) |file| {
        const os2 = sfntTable(file, "OS/2");
        if (os2.len < 86 or std.mem.readInt(u32, os2[78..82], .big) & 1 == 0) continue;
        if (gdiFamily(file, face)) return true;
    }
    return false;
}
fn RemoveFontResourceExW(_: [*:0]const u16, _: u32, _: ?usize) BOOL { removals += 1; return 1; }
fn closeFind(_: bool) void {}
fn chatAcClose() void {}
fn chatDraftFlush() void {}
fn syncWorking() void {}
fn chatSelectionClear() void {}
fn updateBrowserVisibility() void {}
fn focusActiveShell() void {}
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) BOOL { return 1; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn openChatView() void { g_chat_active = true; }
fn saveSession() void {}
fn loadInboxModel() void {}
fn chatBenchEnabled() bool { return false; }
fn chatViewOwnsInput() bool { return g_chat_active; }
fn resetFontCache() void {}
fn layoutChatControls() void {}
fn chatRefreshAfterFontChange() void {}
fn isTabHidden(i: u32) bool { return shells[i].hidden; }
fn switchToShellByUser(i: u32) void { switchToShell(i); }
fn hideBrowserFloatingChrome() void {}
fn parkStrayBrowserPanes(_: HANDLE) void {}
fn updateMainWindowTitle() void {}
fn browserPaneActive() bool { return false; }
fn armBrowserVisibilitySettle(_: u32) void {}
fn prepare() BundledConsoleFonts {
    shells = @splat(.{}); shell_count = 0; active_shell = 0; next_pid = 2;
    consoles = @splat(.{}); attached = 0; registered_font_count = 0; last_written = &.{}; registrations = 0; removals = 0;
    event_count = 0; writes = 0; resets = 0; redraws = 0; read_failures = 0;
    fail_set = false; reject_shell_font = false; fail_attach = false; fail_registration = false; selection_errors = 0;
    g_console_font_override = 0; g_main_monitor_dpi = 96; g_font_gen = 1; g_font_sync_done = 0;
    g_chat_active = false; g_chat_view_mode = .per_session; g_active_workspace = 0;
    g_starred_workspace = false; g_starred_last_shell = 0; g_inbox_step_context_active = false;
    test_pane_h = 540; geometry_pending = false; g_monitor_transition = .{};
    return registerBundledConsoleFonts();
}
fn drain() void {
    if (geometry_pending) { geometry_pending = false; settleConsoleGeometry(g_main_hwnd); }
    var ticks: usize = 0;
    while (nextStaleFontShell() != null and ticks < MAX_SHELLS * 2) : (ticks += 1) fontSyncTimerTick(g_main_hwnd);
    pollFonts();
}
const SHELL_FONT = "Nordwand Mono MP SemiBold";
fn expectShellFont() !void {
    for (&consoles, 0..) |*c, pid| {
        if (!c.live) continue;
        try std.testing.expect(AttachConsole(@intCast(pid)) != 0);
        var actual: CONSOLE_FONT_INFOEX = .{};
        try std.testing.expect(GetCurrentConsoleFontEx(GetStdHandle(0), 0, &actual) != 0);
        try std.testing.expectEqualSlices(u16, std.mem.span(L(SHELL_FONT)), std.mem.sliceTo(&actual.FaceName, 0));
        try std.testing.expectEqual(makeFace(SHELL_FONT), c.last_requested);
        try std.testing.expectEqual(@as(u32, 600), actual.FontWeight);
        try std.testing.expectEqual(@as(u32, 54), actual.FontFamily);
        _ = FreeConsole();
    }
}
fn seedWrong(i: usize, height: i16) void {
    const pid = shells[i].pid;
    consoles[pid].font.FaceName = makeFace("Courier New"); consoles[pid].font.dwFontSize.y = height;
    shells[i].base_font_h = 18; shells[i].base_font_w = 9;
    shells[i].base_font_face = makeFace("Courier New"); shells[i].base_font_family = 0; shells[i].base_font_weight = 700;
}
`;

const tests = String.raw`
test "ISSUE-456 fake GDI rejects a face without the ANSI code page and selects the bundled shell font" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    consoles[2] = .{ .live = true }; _ = AttachConsole(2);
    var requested: CONSOLE_FONT_INFOEX = .{ .FaceName = makeFace(SHELL_FONT) };
    try std.testing.expectEqual(@as(i32, 1), SetCurrentConsoleFontEx(2, 0, &requested));
    try std.testing.expectEqual(makeFace(SHELL_FONT), consoles[2].font.FaceName);
    var without_code_pages = font_policy.MONO_SEMIBOLD.*;
    @memset(@constCast(sfntTable(&without_code_pages, "OS/2"))[78..86], 0);
    registered_fonts[0] = &without_code_pages;
    _ = SetCurrentConsoleFontEx(2, 0, &requested);
    try std.testing.expectEqual(makeFace("Courier New"), consoles[2].font.FaceName);
    registered_fonts[0] = font_policy.MONO_SEMIBOLD;
    requested.FaceName = makeFace("Nordwand Mono SemiBold"); _ = SetCurrentConsoleFontEx(2, 0, &requested);
    try std.testing.expectEqual(makeFace("Courier New"), consoles[2].font.FaceName);
    requested.FaceName = makeFace(SHELL_FONT); _ = SetCurrentConsoleFontEx(2, 0, &requested);
    try std.testing.expectEqual(makeFace(SHELL_FONT), consoles[2].font.FaceName);
    var info: CONSOLE_SCREEN_BUFFER_INFOEX = .{}; _ = SetConsoleScreenBufferInfoEx(2, &info);
    try std.testing.expectEqual(makeFace("Courier New"), consoles[2].font.FaceName);
}
test "new local SSH and tmux sessions register before spawn and stay on the shell font after queued work" {
    const bundle = prepare();
    for ([_]ShellKind{ .cmd, .pwsh, .bash, .vps, .vps2, .tmux }, 0..) |kind, i| try std.testing.expect(spawnSession(kind, i));
    try expectShellFont(); drain(); try expectShellFont();
    try std.testing.expectEqual(@as(usize, 1), registrations);
    try std.testing.expectEqual(@as(i16, 18), consoles[2].font.dwFontSize.y);
    try std.testing.expectEqual(@TypeOf(events[0]).register, events[0]);
    for (events[0..event_count], 0..) |e, i| if (e == .reset) {
        try std.testing.expect(i + 1 < event_count and events[i + 1] == .font);
    };
    unregisterBundledConsoleFonts(&bundle); try std.testing.expectEqual(registrations, removals);
}
test "SSH and tmux reconnect replace native console and preserve the shell font after settle and poll" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    for ([_]ShellKind{ .vps, .vps2, .tmux }) |kind| {
        try std.testing.expect(spawnSession(kind, 0));
        const old = shells[0].pid; consoles[old].live = false;
        try std.testing.expect(reconnectSession(kind, 0));
        try std.testing.expect(shells[0].pid != old);
        armConsoleGeometrySettle(g_main_hwnd); drain(); try expectShellFont();
        consoles[shells[0].pid].live = false;
    }
}
test "restart reclaims surviving console and later theme and poll cannot roll back its face" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    consoles[2] = .{ .live = true }; next_pid = 3;
    try std.testing.expect(reclaimShell(2, .tmux));
    drain(); try expectShellFont();
    seedWrong(0, 12); applyConsoleThemeToAllShells(); drain(); try expectShellFont();
    try std.testing.expect(spawnSession(.cmd, 1)); drain(); try expectShellFont();
}
test "tab switch stale generation runs production layout sync then settle and poll" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0)); try std.testing.expect(spawnSession(.tmux, 1));
    drain(); seedWrong(1, 18); fontSyncMarkAllStale(g_main_hwnd, "tab");
    switchToShell(1); drain(); try expectShellFont();
    try std.testing.expectEqual(g_font_gen, shells[1].font_gen);
    seedWrong(0, 18); shells[0].font_gen = g_font_gen;
    switchToShell(0); drain(); try expectShellFont();
}
test "workspace switch chooses remembered native tab and adoption ignores stale cached identity" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0)); try std.testing.expect(spawnSession(.tmux, 1));
    shells[1].workspace = 1; g_ws_last_shell[1] = shells[1].shell_id;
    seedWrong(1, 12); fontSyncMarkAllStale(g_main_hwnd, "workspace");
    switchToWorkspace(1); drain(); try expectShellFont();
    try std.testing.expectEqual(@as(u32, 1), active_shell);
    switchToWorkspace(0); drain(); try expectShellFont(); switchToWorkspace(0); drain(); try expectShellFont();
}
test "IGSH-457 Starred workspace switch keeps the selected console on the shell font" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0)); try std.testing.expect(spawnSession(.tmux, 1));
    shells[1].workspace = 1; shells[1].favorite = true;
    seedWrong(1, 12); fontSyncMarkAllStale(g_main_hwnd, "starred workspace");
    switchToWorkspace(@import("workspace_view.zig").starred); drain(); try expectShellFont();
    try std.testing.expect(g_starred_workspace);
    try std.testing.expectEqual(@as(u32, 1), active_shell);
}
test "ordinary Chat exit never resets and pending full width ends on the shell font after queued work" {
    for ([_]ChatViewMode{ .per_session, .everywhere, .nowhere }) |mode| {
        for ([_]bool{ false, true }) |full| {
            for (0..3) |toggles| {
                const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
                try std.testing.expect(spawnSession(.tmux, 0)); drain();
                g_chat_view_mode = mode; g_chat_active = true; shells[0].full_width = full;
                const before = resets;
                for (0..toggles) |_| _ = toggleFullWidth(g_main_hwnd);
                try std.testing.expectEqual(before, resets);
                closeChatView(); try expectShellFont();
                try std.testing.expectEqual(before + @intFromBool(toggles > 0), resets);
                try std.testing.expect(!shells[0].full_width_pending_console_resize);
                armConsoleGeometrySettle(g_main_hwnd); drain(); try expectShellFont();
            }
        }
    }
}
test "same-height wrong face is repaired and stale cached face never overrides the shell font during DPI and zoom" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.tmux, 0)); drain();
    seedWrong(0, 18); _ = normalizeConsoleFont(0, shells[0].pid); try expectShellFont();
    for ([_]u32{ 144, 192, 96 }) |dpi| {
        seedWrong(0, 12); _ = dpiChanged(g_main_hwnd, dpi, 0); drain(); try expectShellFont();
        try std.testing.expectEqual(@as(i16, @intCast(18 * dpi / 96)), consoles[shells[0].pid].font.dwFontSize.y);
    }
    _ = zoomBigger(g_main_hwnd); drain(); try expectShellFont();
    try std.testing.expectEqual(@as(i16, 19), g_console_font_override);
    try std.testing.expect(@abs(consoles[shells[0].pid].font.dwFontSize.y - 19) <= 1);
    _ = zoomBigger(g_main_hwnd); _ = zoomSmaller(g_main_hwnd); drain(); try expectShellFont();
    _ = zoomReset(g_main_hwnd); drain(); try expectShellFont();
    try std.testing.expectEqual(@as(i16, 18), consoles[shells[0].pid].font.dwFontSize.y);
}
test "independent same-height normalization repairs Courier without a theme reset" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0));
    seedWrong(0, 18); const before = resets;
    _ = normalizeConsoleFont(0, shells[0].pid); try expectShellFont();
    try std.testing.expectEqual(before, resets);
}
test "independent size normalization ignores stale cached Courier identity" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0));
    seedWrong(0, 12); consoles[shells[0].pid].font.FaceName = makeFace(SHELL_FONT);
    _ = normalizeConsoleFont(0, shells[0].pid); try expectShellFont();
    try std.testing.expectEqual(@as(i16, 18), consoles[shells[0].pid].font.dwFontSize.y);
}
test "viewport repair never restores captured wrong face and keeps remote redraw rules" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.tmux, 0)); drain();
    const pid = shells[0].pid; _ = AttachConsole(pid);
    var captured = consoles[pid].font; captured.FaceName = makeFace("Courier New");
    consoles[pid].buffer.dwSize.y = 10; consoles[pid].buffer.srWindow = .{ .bottom = 9 };
    try std.testing.expect(normalizeAttachedConsoleViewport(0, pid, &captured));
    try std.testing.expectEqual(@as(usize, 1), redraws); try expectShellFont();
    test_pane_h = 360; _ = AttachConsole(pid); _ = normalizeAttachedConsoleViewport(0, pid, &captured);
    try std.testing.expectEqual(@as(usize, 1), redraws); try expectShellFont();
    test_pane_h = 720; consoles[pid].buffer.dwSize.y = 100; consoles[pid].buffer.srWindow = .{ .top = 5, .bottom = 24 };
    _ = AttachConsole(pid); _ = normalizeAttachedConsoleViewport(0, pid, &captured);
    try std.testing.expectEqual(@as(usize, 1), redraws); drain(); try expectShellFont();
}
test "initial font read failure still reapplies the shell font after buffer reset" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    consoles[2] = .{ .live = true }; installConsole(2, .cmd, 0);
    read_failures = 1; applyBlackConsoleBackground(2); try expectShellFont(); drain(); try expectShellFont();
}
test "failed selection or silent substitution remains stale and a later sync retries" {
    const bundle = prepare(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0)); drain();
    for (0..3) |failure| {
        seedWrong(0, 18); fontSyncMarkAllStale(g_main_hwnd, "retry");
        fail_set = failure == 0; reject_shell_font = failure == 1; fail_attach = failure == 2;
        _ = fontSyncShell(0); try std.testing.expect(fontGenStale(shells[0].font_gen, g_font_gen));
        fail_set = false; reject_shell_font = false; fail_attach = false;
        drain(); try expectShellFont(); try std.testing.expectEqual(g_font_gen, shells[0].font_gen);
    }
    try std.testing.expect(selection_errors > 0);
}
test "registration failure cannot masquerade as the shell font and mintty bypasses conhost writes" {
    _ = prepare(); fail_registration = true; registered_font_count = 0;
    const bundle = registerBundledConsoleFonts(); defer unregisterBundledConsoleFonts(&bundle);
    try std.testing.expect(spawnSession(.cmd, 0));
    try std.testing.expectEqual(makeFace("Courier New"), consoles[shells[0].pid].font.FaceName);
    fail_registration = false; _ = registerBundledConsoleFonts(); drain(); try expectShellFont();
    const before = writes; shells[0].kind = .gitbash; fontSyncMarkAllStale(g_main_hwnd, "mintty");
    _ = fontSyncShell(0); try std.testing.expectEqual(before, writes);
    try std.testing.expectEqual(g_font_gen, shells[0].font_gen);
}
`;

test('IGSH-457 console lifecycle harness includes Starred workspace dependencies', () => {
  const source = harness();
  for (const name of ['starredShellVisible', 'refreshStarredWorkspace', 'inboxPublishesShell', 'loadInboxModel']) {
    assert.ok(source.includes(`fn ${name}(`), name);
  }
  assert.match(source, /var g_starred_workspace = false/);
  assert.match(source, /var g_starred_last_shell: u32 = 0/);
  assert.doesNotMatch(source, /@import\("inbox.zig"\)/);
});

test('extracted production console lifecycle keeps Nordwand Mono MP SemiBold after events and queued sync work', () => {
  const dir = fs.mkdtempSync(path.join(process.env.CONSOLE_FONT_TEST_TMP || os.tmpdir(), 'console-font-lifecycle-'));
  try {
    fs.cpSync(path.join(root, 'src/fonts'), path.join(dir, 'fonts'), { recursive: true });
    copyZig(['workspace_view.zig'], dir);
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, harness());
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], {
      encoding: 'utf8', timeout: 120000,
    });
    assert.equal(result.error, undefined);
    console.log((result.stdout + result.stderr).trim());
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.match(result.stderr, /All \d+ tests passed/);
  } finally {
    if (!process.env.CONSOLE_FONT_TEST_KEEP) fs.rmSync(dir, { recursive: true, force: true });
  }
});
