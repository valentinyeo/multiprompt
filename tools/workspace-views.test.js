const { copyZig } = require('./zig-copy');
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function body(file, name) {
  const source = read(file);
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}

test('workspace views use inbox ordering and membership across local and remote workspaces', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'workspace-views-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 }));
  copyZig(['workspace_view.zig'], dir);
  const state = read('src/app_state.zig');
  const start = state.indexOf('pub const InboxRow = struct {');
  const row = state.slice(start, state.indexOf('\n};', start) + 3);
  fs.writeFileSync(path.join(dir, 'app_state.zig'), `const std = @import("std");
${row}
pub const INBOX_MAX_ROWS = 8;
pub var g_main_hwnd: ?*anyopaque = @ptrFromInt(1);
pub var g_inbox_tab: u32 = 1;
pub var g_unread_only = false;
pub var g_sidebar_view: ?@import("workspace_view.zig").Builtin = null;
pub var g_sidebar_order_frozen: bool = false;
pub var g_inbox_ws_count: u32 = 3;
pub var g_inbox_row_count: u32 = 3;
pub var g_inbox_ws = [_]struct { hwnd: usize }{ .{.hwnd=1}, .{.hwnd=2}, .{.hwnd=1} };
pub var g_inbox_rows: [INBOX_MAX_ROWS]InboxRow = undefined;
pub var shells = [_]struct { shell_id: u32, inbox_excluded: bool = false, muted: bool = false, pinned_top: bool = false }{ .{.shell_id=11, .pinned_top=true}, .{.shell_id=12} };
`);
  fs.writeFileSync(path.join(dir, 'inbox.zig'), `const frequent = @import("frequent.zig");
const app_state = @import("app_state.zig");
const InboxRow = app_state.InboxRow;
const favoriteSplitMatches = @import("workspace_view.zig").splitMatches;
pub fn nowFileTime() u64 { return (11_644_473_600_000 + 1_800_000_000_000) * 10_000; }
pub fn findShellById(sid: u32) ?u32 {
    for (app_state.shells, 0..) |shell, i| { if (shell.shell_id == sid) return @intCast(i); }
    return null;
}
fn inboxFilterMatches(_: *const InboxRow) bool { return true; }
${body('src/inbox.zig', 'inboxFrequent')}
pub ${body('src/inbox.zig', 'rowLessForSplit')}
pub ${body('src/inbox.zig', 'rowVisibleInSplit')}
pub ${body('src/inbox.zig', 'inboxRowVisible')}
`);
  fs.writeFileSync(path.join(dir, 'views.zig'), `const std = @import("std");
const app_state = @import("app_state.zig");
const frequent = @import("frequent.zig");
const inbox_model = @import("inbox.zig");
const MAX_ROWS = 8;
const LOOK_UNIFIED = false;
const Row = struct { kind: enum { tab, inbox }, gidx: u32, shell_idx: u32, y: i32 };
fn wsStripHeight() i32 { return 0; }
fn tabRowH() i32 { return 50; }
var g_frozen_places_len: usize = 0;
inline fn frozenPlaceOf(shell_id: u32) u64 { _ = shell_id; return 0; }
${body('src/sidebar.zig', 'layoutViewRows')}
fn sid(row: Row) u32 { return if (row.kind == .tab) app_state.shells[row.shell_idx].shell_id else app_state.g_inbox_rows[row.shell_idx].sid; }
fn setup() void {
    const now: u64 = 1_800_000_000_000;
    app_state.g_unread_only = false;
    for (&app_state.shells) |*shell| { shell.inbox_excluded = false; shell.muted = false; }
    app_state.g_inbox_rows[0] = .{ .ws=0, .sid=11, .la=100, .input=now-300, .favorite=true, .att=true, .act=1 };
    app_state.g_inbox_rows[1] = .{ .ws=1, .sid=20, .la=200, .input=now-100 };
    app_state.g_inbox_rows[2] = .{ .ws=2, .sid=12, .la=50, .lv=300, .favorite=true };
}
test "All merges workspaces by recency, ignoring pins, groups and attention" {
    setup();
    var rows: [MAX_ROWS]Row = undefined;
    const count = layoutViewRows(&rows, .all);
    try std.testing.expectEqual(@as(u32, 3), count);
    for ([_]u32{12,20,11}, rows[0..count]) |id, r| try std.testing.expectEqual(id, sid(r));
    try std.testing.expectEqual(.inbox, rows[1].kind);
    try std.testing.expectEqual(.tab, rows[0].kind);
}
test "Frequent uses input recency and Favorites uses the same membership as Inbox" {
    setup();
    var rows: [MAX_ROWS]Row = undefined;
    var count = layoutViewRows(&rows, .frequent);
    try std.testing.expectEqual(@as(u32, 2), count);
    try std.testing.expectEqual(@as(u32, 20), sid(rows[0]));
    try std.testing.expectEqual(@as(u32, 11), sid(rows[1]));
    count = layoutViewRows(&rows, .favorites);
    try std.testing.expectEqual(@as(u32, 2), count);
    try std.testing.expectEqual(@as(u32, 12), sid(rows[0]));
    try std.testing.expectEqual(@as(u32, 11), sid(rows[1]));
    const now = frequent.unixMs(inbox_model.nowFileTime() / 10_000);
    for (@import("workspace_view.zig").builtins) |view| {
        app_state.g_inbox_tab = view.split();
        count = layoutViewRows(&rows, view);
        var expected: u32 = 0;
        for (app_state.g_inbox_rows[0..3]) |*r| {
            if (!inbox_model.inboxRowVisible(r)) continue;
            expected += 1;
            var found = false;
            for (rows[0..count]) |r2| { if (sid(r2) == r.sid) found = true; }
            try std.testing.expect(found);
        }
        try std.testing.expectEqual(expected, count);
        try std.testing.expect(!inbox_model.rowLessForSplit(view.split(), now, app_state.g_inbox_rows[0], app_state.g_inbox_rows[0]));
    }
}
test "workspace views preserve Inbox exclusion, mute, unread and empty-list behavior" {
    setup();
    var rows: [MAX_ROWS]Row = undefined;
    app_state.shells[1].inbox_excluded = true;
    try std.testing.expectEqual(@as(u32, 2), layoutViewRows(&rows, .all));
    app_state.shells[0].muted = true;
    try std.testing.expectEqual(@as(u32, 1), layoutViewRows(&rows, .all));
    app_state.g_unread_only = true;
    try std.testing.expectEqual(@as(u32, 0), layoutViewRows(&rows, .all));
}
`);
  fs.writeFileSync(path.join(dir, 'workspace_switcher.zig'), 'pub fn headerHeight() i32 { return 52; }\n');
  fs.writeFileSync(path.join(dir, 'window_layout.zig'), 'pub fn paneOuterMargin() i32 { return 0; }\n');
  const result = spawnSync(process.env.ZIG || 'zig', ['test', 'views.zig', '-j1', '--cache-dir', path.join(dir, 'cache'), '--global-cache-dir', process.env.ZIG_GLOBAL_CACHE_DIR || path.join(dir, 'global-cache')], { cwd: dir, encoding: 'utf8', timeout: 120000, maxBuffer: 4 * 1024 * 1024 });
  assert.equal(result.status, 0, `${result.error || ''}\n${result.stdout}\n${result.stderr}`);
});
