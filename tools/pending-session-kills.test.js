const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const read = file => fs.readFileSync(file, 'utf8');
function between(source, start, end) {
  const first = source.indexOf(start);
  const last = source.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, `missing ${start}`);
  return source.slice(first, last);
}
function native(source, files) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pending-close-'));
  try {
    for (const file of files) {
      const source = read(`src/${file}`);
      fs.writeFileSync(path.join(dir, file), file === 'json_reader.zig' ? source.replace(/^test "[^\n]+" \{[\s\S]*?^\}\n/gm, '') : source);
    }
    fs.writeFileSync(path.join(dir, 'test.zig'), source);
    const result = spawnSync(process.env.ZIG || 'zig', ['test', path.join(dir, 'test.zig'), '-j1'], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}

test('IGSH-1516 offline end survives stale account layout and rejects an unaccepted end', () => {
  const archive = read('src/archive.zig');
  const end = between(archive, 'pub fn endTmuxSessionAt(', 'pub fn endActiveTmuxSession(');
  const filter = between(read('src/account_desktop.zig'), '    var kept: std.ArrayList(session_layout.Tab)', '    app_state.g_account_applying = true;');
  const tokenized = /sid: \[\]const u8, pending:/.test(archive);
  const admits = /fn queuePendingSessionKill\([^\n]+\) bool/.test(archive);
  native(`const std = @import("std");
const Closed = @import("tmux_closed.zig").Closed;
const Outcome = enum { gone, retry, unsafe };
const Shell = struct { tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0, tmux_host: u8 = 0, claude_sid: [40]u8 = @splat(0), claude_sid_len: u32 = 0 };
const app_state = struct {
    var shells: [1]Shell = .{.{}};
    var shell_count: usize = 1;
    var g_tmux_closed: Closed = .{};
    var g_tmux_fetch_tick: u64 = 100;
    const g_main_hwnd: ?*anyopaque = null;
};
const session_layout = struct { const Tab = struct { tmux_host: u8, tmux_session: []const u8 }; };
var kill_outcome: Outcome = .retry;
var admitted = true;
var notices: usize = 0;
var saved: usize = 0;
var queued: usize = 0;
fn rememberArchivedTab(_: usize) ?u8 { return 0; }
fn rejectPinnedSessionClose(_: usize) bool { return false; }
fn parkMainWindowBeforeActiveShellRemoval(_: usize) bool { return true; }
fn focusActiveShell() void {}
fn killRemoteTmuxSession(_: []const u8, _: u8, _: []const u8${tokenized ? ', _: ?u64' : ''}) Outcome { return kill_outcome; }
fn queuePendingSessionKill(_: []const u8, _: u8, _: []const u8) ${admits ? 'bool' : 'void'} { queued += 1; ${admits ? 'return admitted;' : ''} }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void { notices += 1; }
fn removePaneSessionFilesForShell(_: u32) void {}
fn closeShellRemember(_: u32, remember: bool) void {
    if (remember) app_state.g_tmux_closed.close(std.testing.allocator, 0, "session-one") catch unreachable;
    app_state.shell_count = 0;
}
fn fetchTmuxSessions() void {}
fn publishInboxState() void {}
fn saveSession() void { saved += 1; }
fn InvalidateRect(_: ?*anyopaque, _: ?*anyopaque, _: i32) i32 { return 1; }
${end}
fn staleLayout(a: std.mem.Allocator) ![]session_layout.Tab {
    var desired = struct { tabs: []const session_layout.Tab }{ .tabs = &.{ .{ .tmux_host = 0, .tmux_session = "SESSION-ONE" }, .{ .tmux_host = 1, .tmux_session = "session-one" } } };
${filter}
    return kept.items;
}
fn reset() void {
    app_state.shell_count = 1;
    app_state.shells[0] = .{ .tmux_session_len = 11 };
    @memcpy(app_state.shells[0].tmux_session[0..11], "session-one");
    notices = 0; saved = 0; queued = 0;
}
test "offline end prevents stale sync resurrection but not another host" {
    defer {
        app_state.g_tmux_closed.entries.deinit(std.testing.allocator);
        app_state.g_tmux_closed = .{};
    }
    reset();
    endTmuxSessionAt(0);
    try std.testing.expectEqual(@as(usize, 0), app_state.shell_count);
    try std.testing.expectEqual(@as(usize, 1), queued);
    try std.testing.expectEqual(@as(usize, 0), notices);
    try std.testing.expectEqual(@as(usize, 1), saved);
    try std.testing.expect(app_state.g_tmux_closed.contains(0, "session-one"));
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const kept = try staleLayout(arena.allocator());
    try std.testing.expectEqual(@as(usize, 1), kept.len);
    try std.testing.expectEqual(@as(u8, 1), kept[0].tmux_host);
    app_state.g_tmux_closed.reopen(0, "session-one");
}
test "full queue and unsafe target preserve tab, successful end needs no retry" {
    reset(); admitted = false; kill_outcome = .retry;
    endTmuxSessionAt(0);
    try std.testing.expectEqual(@as(usize, 1), app_state.shell_count);
    try std.testing.expectEqual(@as(usize, 1), notices);
    try std.testing.expectEqual(@as(usize, 0), saved);
    reset(); kill_outcome = .unsafe;
    endTmuxSessionAt(0);
    try std.testing.expectEqual(@as(usize, 1), app_state.shell_count);
    try std.testing.expectEqual(@as(usize, 0), queued);
    reset(); kill_outcome = .gone;
    endTmuxSessionAt(0);
    try std.testing.expectEqual(@as(usize, 0), app_state.shell_count);
    try std.testing.expectEqual(@as(usize, 0), queued);
    try std.testing.expect(!app_state.g_tmux_closed.contains(0, "session-one"));
}
`, ['tmux_closed.zig', 'tmux_identity.zig', 'json_reader.zig', 'session_layout.zig', 'account_hosts.zig', 'archive_rules.zig', 'voice_filter.zig', 'frequent.zig']);
});

test('IGSH-1516 cancelled retry cannot kill or resurrect a replacement intent', () => {
  if (!fs.existsSync('src/session_kills.zig')) return;
  const archive = read('src/archive.zig');
  const retry = between(archive, 'pub fn retryPendingSessionKills(', 'fn remoteNameIsSafe(');
  const cancel = between(archive, 'pub fn cancelPendingSessionKill(', 'pub fn retryPendingSessionKills(');
  const reopen = between(read('src/console.zig'), '    app_state.shells[idx].font_gen = app_state.g_font_gen;', '    if (!app_state.g_restoring and background_workspace == null) app_state.shells[idx].last_active')
    .slice('    app_state.shells[idx].font_gen = app_state.g_font_gen;\n    app_state.shell_count += 1;\n'.length)
    .replace('@import("archive.zig").', '');
  native(`const std = @import("std");
const session_kills = @import("session_kills.zig");
const app_state = struct {
    var g_restoring = false;
    var g_pending_tmux_host: u8 = 0;
    var g_tmux_closed: @import("tmux_closed.zig").Closed = .{};
    var g_pending_session_kills: session_kills.Queue = .{};
    var g_pending_session_kill_mutex = struct {
        fn tryLock(_: *@This()) bool { return true; }
        fn unlock(_: *@This()) void {}
    }{};
};
var calls: usize = 0;
var terminated: usize = 0;
fn Sleep(_: u32) void {}
fn debugLog2(_: []const u8, _: []const u8) void {}
fn TerminateProcess(process: *anyopaque, _: u32) i32 {
    std.debug.assert(process == @as(*anyopaque, @ptrFromInt(7)));
    terminated += 1;
    return 1;
}
fn killRemoteTmuxSession(session: []const u8, host: u8, _: []const u8, token: ?session_kills.Token) session_kills.Outcome {
    calls += 1;
    tryAttach(token.?);
    cancelPendingSessionKill(host, session);
    _ = app_state.g_pending_session_kills.add(host, session, "replacement");
    return .retry;
}
fn tryAttach(token: session_kills.Token) void {
    std.debug.assert(app_state.g_pending_session_kills.attach(token, @ptrFromInt(7)));
}
${cancel}
${retry}
test "actual worker finishes only its own cancelled token" {
    const original = app_state.g_pending_session_kills.add(0, "session-one", "").?;
    retryPendingSessionKills();
    try std.testing.expectEqual(@as(usize, 1), calls);
    try std.testing.expectEqual(@as(usize, 1), terminated);
    const replacement = app_state.g_pending_session_kills.begin(0).?;
    try std.testing.expect(replacement.token != original);
    try std.testing.expectEqualStrings("replacement", replacement.sid[0..replacement.sid_len]);
}
fn spawnAccepted(tmux_session: ?[]const u8) void {
${reopen}
}
test "only explicit accepted reopen cancels end and clears tombstone" {
    app_state.g_pending_session_kills = .{};
    defer app_state.g_tmux_closed.entries.deinit(std.testing.allocator);
    try app_state.g_tmux_closed.close(std.testing.allocator, 0, "queued");
    _ = app_state.g_pending_session_kills.add(0, "queued", "").?;
    app_state.g_restoring = true;
    spawnAccepted("queued");
    try std.testing.expect(app_state.g_tmux_closed.contains(0, "queued"));
    const pending = app_state.g_pending_session_kills.begin(0).?;
    app_state.g_pending_session_kills.finish(pending.token, .retry);
    app_state.g_restoring = false;
    spawnAccepted("queued");
    try std.testing.expect(!app_state.g_tmux_closed.contains(0, "queued"));
    try std.testing.expect(app_state.g_pending_session_kills.begin(0) == null);
}
test "production queue controls" { std.testing.refAllDecls(session_kills); }
`, ['session_kills.zig', 'tmux_identity.zig', 'tmux_closed.zig', 'json_reader.zig', 'session_layout.zig', 'account_hosts.zig', 'archive_rules.zig', 'voice_filter.zig', 'frequent.zig']);
});

test('reconnect journey selects the owned main window rather than transient overlays', () => {
  const window = between(read('tools/verify-reconnect/desktop.cs'), 'public static IntPtr Window(', 'public static IntPtr InputSurface(');
  assert.match(window, /owner==pid && IsWindowVisible\(h\) && Class\(h\)=="ZigShell"/);
});
