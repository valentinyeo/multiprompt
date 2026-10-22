const { copyZig } = require('./zig-copy');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const main = fs.readFileSync(path.join(__dirname, '../src/main.zig'), 'utf8');
function frontFunction(source) {
  const start = source.indexOf('fn updateSessionFront(');
  assert.ok(start >= 0);
  return source.slice(start, source.indexOf('\n}', start) + 2).replaceAll('@import("inbox.zig").nowFileTime()', 'nowFileTime()');
}

function run(source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'issue-513-front-'));
  try {
    copyZig(['frequent.zig'], dir);
    fs.writeFileSync(path.join(dir, 'test.zig'), `
const std = @import("std");
const frequent = @import("frequent.zig");
const app_state = struct {
    var g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
    var g_account_locked = false;
    var g_restoring = false;
    var g_startup_progress = false;
    var g_account_applying = false;
    var g_inbox_active = false;
    var g_all_sessions_active = false;
    var g_search_active = false;
    var g_shortcuts_active = false;
    var g_changelog_active = false;
    var g_url_picker_active = false;
    var active_shell: u32 = 0;
    var shell_count: u32 = 2;
    var g_single_window = false;
    var g_active_workspace: u8 = 0;
    var shells = [_]struct { workspace: u8 = 0, shell_id: u32 }{ .{ .shell_id = 1 }, .{ .shell_id = 2 } };
    var g_front_period: frequent.FrontPeriod = .{};
    const TIMER_VISIT_DWELL = 173;
};
const launch_cache = struct { var pending = false; };
var foreground = true;
var probes: usize = 0;
var timer: u32 = 0;
var now: u64 = 100;
fn foregroundIsOurs() bool { probes += 1; return foreground; }
fn GetTickCount64() u64 { return now; }
fn nowFileTime() u64 { return 116444736000000000 + now * 10000; }
fn SetTimer(_: ?*anyopaque, _: usize, interval: u32, _: ?*anyopaque) usize { timer = interval; return 1; }
fn KillTimer(_: ?*anyopaque, _: usize) i32 { timer = 0; return 1; }
${frontFunction(source)}
test "ISSUE-513 unselected idle messages never probe foreground or arm a visit" {
    app_state.g_front_period = .{};
    probes = 0;
    timer = 0;
    for (0..120) |_| { now += 1000; updateSessionFront(false); }
    try std.testing.expectEqual(@as(usize, 0), probes);
    try std.testing.expectEqual(@as(u32, 0), timer);
}
test "ISSUE-513 focus gating preserves visit semantics for every selection and visibility state" {
    const ids = [_]?u32{ null, 1, 2 };
    for (ids) |selected| for (ids) |sid| for ([_]bool{ false, true }) |user| {
        for ([_]bool{ false, true }) |focused| for ([_]bool{ false, true }) |visible| {
            for ([_]bool{ false, true }) |allowed| {
                const before = frequent.FrontPeriod{ .selected = selected, .sid = sid, .start_ms = 9, .start_tick = 8, .recorded = true };
                app_state.g_front_period = before;
                app_state.g_search_active = !visible;
                app_state.g_account_locked = !allowed;
                foreground = focused;
                probes = 0;
                var expected = before;
                const candidate: ?u32 = if (allowed) 1 else null;
                _ = expected.select(candidate, user, visible and focused, now, now);
                updateSessionFront(user);
                try std.testing.expectEqualDeep(expected, app_state.g_front_period);
                try std.testing.expectEqual(@as(usize, @intFromBool(allowed and visible and (user or selected == candidate))), probes);
            }
        };
    };
}
test "ISSUE-513 user selection still records a focused ten-second visit and cancels on focus loss" {
    app_state.g_front_period = .{};
    app_state.g_search_active = false;
    app_state.g_account_locked = false;
    foreground = true;
    now = 100;
    updateSessionFront(true);
    try std.testing.expectEqual(@as(u32, 10000), timer);
    try std.testing.expectEqual(@as(?u64, null), app_state.g_front_period.visit(10099));
    try std.testing.expectEqual(@as(?u64, 100), app_state.g_front_period.visit(10100));
    foreground = false;
    updateSessionFront(false);
    try std.testing.expectEqual(@as(?u32, null), app_state.g_front_period.sid);
    try std.testing.expectEqual(@as(?u32, 1), app_state.g_front_period.selected);
    try std.testing.expectEqual(@as(u32, 0), timer);
    foreground = true;
    updateSessionFront(false);
    try std.testing.expectEqual(@as(?u32, 1), app_state.g_front_period.sid);
    app_state.active_shell = 1;
    probes = 0;
    updateSessionFront(false);
    try std.testing.expectEqual(@as(usize, 0), probes);
    try std.testing.expectEqual(@as(?u32, null), app_state.g_front_period.selected);
    try std.testing.expectEqual(@as(u32, 0), timer);
}
`);
    return spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'test.zig'), '--test-filter', 'ISSUE-513'], { encoding: 'utf8', timeout: 60000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('ISSUE-513 production idle dispatch avoids ownership probes without changing visit tracking', () => {
  const result = run(main);
  assert.equal(result.status, 0, result.stdout + result.stderr);
});

test('ISSUE-513 the same oracle rejects the pre-fix production function', () => {
  const old = fs.readFileSync(path.join(__dirname, 'fixtures/issue-513-front-before.zig'), 'utf8');
  const result = run(old);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /expected 0, found 120/);
});
