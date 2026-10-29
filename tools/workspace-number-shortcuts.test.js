const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const source = require('./app-source').readAppSource();

function body(name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('number shortcuts activate sidebar sessions in displayed order, including remote Starred rows', t => {
  const selector = body('nthVisibleShell');
  assert.match(selector, /fn nthVisibleShell\(n: u32\) \?Row/,
    'selection must preserve the visible row kind, not raw storage indexes');
  const start = source.indexOf('        WM_APP_SWITCH_TAB => {');
  const end = source.indexOf('        WM_APP_SWITCH_WORKSPACE =>', start);
  const handler = source.slice(start, end).replace('WM_APP_SWITCH_TAB => {', 'fn select(wp: usize) i32 {').replace(/},\s*$/, '}');
  assert.doesNotMatch(handler, /g_single_window|want < shell_count/);
  const hook = body('keyboardHookProc');
  const post = hook.lastIndexOf('WM_APP_SWITCH_TAB, tab_idx, 0');
  assert.ok(post > 0);
  assert.doesNotMatch(hook.slice(post - 180, post), /tab_idx < shell_count/,
    'remote Starred rows must not be capped by the local shell count');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-numbers-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }));
  const code = `const std = @import("std");
const Row = struct { kind: enum { tab, inbox, header, section }, shell_idx: u32 = 0 };
const MAX_ROWS = 16;
var visible: []const Row = &.{};
var selected: ?u32 = null;
var remote: ?u32 = null;
var g_ws_switch_focus_grace: u64 = 0;
var g_skip_view_bump = false;
fn layoutRows(out: *[MAX_ROWS]Row) u32 { @memcpy(out[0..visible.len], visible); return @intCast(visible.len); }
fn GetTickCount64() u64 { return 100; }
fn activeShellHasForegroundFocus() bool { return true; }
fn requestShellRefocus(_: u32, _: u32) void {}
fn switchToShellByUser(idx: u32) void { selected = idx; }
fn jumpToInboxRow(idx: u32) void { remote = idx; }
${selector}
${handler.replaceAll('@import("console.zig").', '')}
test "manual, auto, grouped, pinned and Starred display order" {
    const layouts = [_][]const Row{
        &.{.{.kind=.section}, .{.kind=.tab,.shell_idx=7}, .{.kind=.tab,.shell_idx=2}, .{.kind=.header}, .{.kind=.tab,.shell_idx=5}},
        &.{.{.kind=.tab,.shell_idx=4}, .{.kind=.tab,.shell_idx=8}, .{.kind=.tab,.shell_idx=1}},
    };
    const expected = [_][3]u32{.{7,2,5}, .{4,8,1}};
    for (layouts, expected) |rows, indexes| {
        visible = rows;
        for (indexes, 0..) |idx, digit| {
            selected = null;
            _ = select(digit);
            try std.testing.expectEqual(@as(?u32, idx), selected);
        }
        selected = 99;
        _ = select(8);
        try std.testing.expectEqual(@as(?u32, 99), selected);
    }
}
test "Starred remote rows count as sessions and use inbox activation" {
    visible = &.{.{.kind=.tab,.shell_idx=5}, .{.kind=.header}, .{.kind=.inbox,.shell_idx=12}, .{.kind=.inbox,.shell_idx=9}};
    selected = null;
    remote = null;
    _ = select(1);
    try std.testing.expectEqual(@as(?u32, 12), remote);
    try std.testing.expectEqual(@as(?u32, null), selected);
    _ = select(2);
    try std.testing.expectEqual(@as(?u32, 9), remote);
    _ = select(8);
    try std.testing.expectEqual(@as(?u32, 9), remote);
    visible = &.{};
    _ = select(0);
    try std.testing.expectEqual(@as(?u32, 9), remote);
}
`;
  fs.writeFileSync(path.join(dir, 'selection.zig'), code);
  const run = spawnSync(process.env.ZIG || 'zig', ['test', 'selection.zig', '-j1', '--cache-dir', path.join(dir, 'cache'), '--global-cache-dir', process.env.ZIG_GLOBAL_CACHE_DIR || path.join(dir, 'global-cache')], {
    cwd: dir, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024,
  });
  assert.equal(run.status, 0, `${run.error || ''}\n${run.stdout}\n${run.stderr}`);
});
