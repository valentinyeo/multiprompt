const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { copyZig } = require('./zig-copy');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const normalize = source => source.replaceAll('app_state.', '').replaceAll('@import("inbox.zig").', '');
function between(source, start, end) {
  const a = source.indexOf(start), b = source.indexOf(end, a + start.length);
  assert.ok(a >= 0 && b > a, `${start} / ${end}`);
  return source.slice(a, b);
}
const inbox = read('src/inbox.zig');
const main = read('src/main.zig');
const session = read('src/session.zig');
const state = read('src/app_state.zig');
const offsets = state.match(/pub const SEARCH_(?:SHOW_FREQUENT|FREQUENT_FIRST|SHOW_FAVORITES|SHOW_ALL)_OFFSET: usize = \d+;/g).join('\n');
const toggle = between(main, '                if (target == SEARCH_SHOW_FREQUENT_OFFSET', '                if (target == SEARCH_INBOX_FREQUENT_OFFSET)');
const serialize = between(session, '    if (app_state.g_layout_settings) |settings| {', '    const split_state =');
const paint = between(inbox, '    var total_attn: u32 = 0;', '    var div_rc = RECT{ .left = 16, .top = tab_y + 28,');
const navigationTest = inbox.slice(inbox.indexOf('test "ISSUE-423 hidden selection'));
const harness = `const std = @import("std");
const frequent = @import("frequent.zig");
${offsets}
var g_layout_settings: ?frequent.Settings = null;
var g_inbox_tab: u32 = frequent.all_split;
var g_inbox_sel: u32 = 0;
var g_inbox_ws_count: u32 = 0;
var g_unread_only = false;
var g_inbox_ws = [_]struct { attn: u32 = 0, total: u32 = 0, name: [32]u8 = .{0} ** 32, name_len: usize = 0 }{.{}};
var g_inbox_row_count: u32 = 0;
var g_inbox_rows = [_]struct { att: bool = false, favorite: bool = false }{.{}};
const INBOX_MAX_SPLIT_TABS = 4;
var g_inbox_split_tab_count: u32 = 0;
var g_inbox_split_xs: [4]i32 = undefined;
var g_inbox_split_xe: [4]i32 = undefined;
var g_inbox_split_ids: [4]u32 = undefined;
var saves: usize = 0;
var saved_json: [4096]u8 = undefined;
var saved_len: usize = 0;
fn InvalidateRect(_: usize, _: ?*anyopaque, _: i32) i32 { return 1; }
fn nowFileTime() u64 { return 0; }
fn inboxFrequent(_: anytype, _: u64) bool { return false; }
fn drawInboxTab(_: usize, x: *i32, _: i32, _: []const u8, _: u32, _: ?usize, _: bool, _: u32, _: u32, _: bool, _: u32, _: i32, _: u32) void { x.* += 50; }
${normalize(between(inbox, 'pub fn inboxSplitVisible(', 'pub fn inboxVisibleCount('))}
fn saveSessionTo(json_buf: []u8) bool {
    const prefix = "{\\\"workspaces\\\":[],\\\"tabs\\\":[]";
    @memcpy(json_buf[0..prefix.len], prefix);
    var pos: usize = prefix.len;
${normalize(serialize)}
    json_buf[pos] = '}';
    saved_len = pos + 1;
    return true;
}
fn saveSession() void { std.debug.assert(saveSessionTo(&saved_json)); saves += 1; }
fn confirm(target: usize) usize {
    const hwnd: usize = 0;
${normalize(toggle)}
    return 1;
}
fn paintSplits() void {
    const hdc: usize = 0;
    const fg_bright: u32 = 0;
    const fg_dim: u32 = 0;
    const blue: u32 = 0;
${normalize(paint)}
}
${normalize(navigationTest)}
test "ISSUE-423 production toggles persist exact flags and painted hit boxes share their order" {
    g_inbox_ws_count = 0;
    g_unread_only = false;
    inline for (.{ .{ SEARCH_SHOW_FREQUENT_OFFSET, "frequent" }, .{ SEARCH_FREQUENT_FIRST_OFFSET, "frequent_first" }, .{ SEARCH_SHOW_FAVORITES_OFFSET, "favorites" }, .{ SEARCH_SHOW_ALL_OFFSET, "all" } }) |entry| {
        g_layout_settings = null;
        g_inbox_tab = frequent.frequent_split;
        saves = 0;
        for ([_]bool{ false, true }) |expected| {
            try std.testing.expectEqual(@as(usize, 0), confirm(entry[0]));
            try std.testing.expectEqual(expected, @field(g_layout_settings.?, entry[1]));
            const parsed = try @import("session_layout.zig").parse(std.testing.allocator, saved_json[0..saved_len]);
            defer parsed.deinit();
            try std.testing.expectEqualDeep(g_layout_settings, parsed.value.settings);
        }
        try std.testing.expectEqual(@as(usize, 2), saves);
    }
    for (0..16) |bits| {
        g_layout_settings = .{ .frequent = bits & 1 != 0, .favorites = bits & 2 != 0, .all = bits & 4 != 0, .frequent_first = bits & 8 != 0 };
        g_inbox_tab = frequent.frequent_split;
        paintSplits();
        const builtins = frequent.builtinSplits(g_layout_settings.?);
        try std.testing.expectEqualSlices(u32, builtins.slice(), g_inbox_split_ids[0..g_inbox_split_tab_count]);
        try std.testing.expect(inboxSplitVisible(g_inbox_tab));
        for (0..g_inbox_split_tab_count) |i| {
            const mx = g_inbox_split_xs[i] + 1;
            var hit: ?u32 = null;
            for (0..g_inbox_split_tab_count) |ti| {
                if (mx >= g_inbox_split_xs[ti] and mx < g_inbox_split_xe[ti]) { hit = g_inbox_split_ids[ti]; break; }
            }
            try std.testing.expectEqual(@as(?u32, builtins.ids[i]), hit);
        }
    }
}
`;
function execute(mutate = source => source) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-split-settings-'));
  try {
    copyZig(['frequent.zig', 'session_layout.zig'], dir);
    fs.writeFileSync(path.join(dir, 'integration.zig'), mutate(harness));
    return spawnSync(process.env.ZIG || 'zig', ['test', '-j1', path.join(dir, 'integration.zig'), '--test-filter', 'ISSUE-423'], { encoding: 'utf8', timeout: 120000 });
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

test('ISSUE-423 production settings palette persistence navigation and painted click targets execute', () => {
  const result = execute();
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.match(result.stderr, /All \d+ tests passed/);
});

test('ISSUE-423 regressions reject lost saves and drawing a hidden built-in split', () => {
  for (const mutate of [
    source => source.replace('                    saveSession();', ''),
    source => source.replace('for (builtins.slice()) |split|', 'for (if (builtins.len > 0) &[_]u32{0, 1, 2} else builtins.slice()) |split|'),
  ]) {
    const result = execute(mutate);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /FAIL/, result.stdout + result.stderr);
  }
});

test('ISSUE-423 settings use the account feature and existing debounced save path', () => {
  const client = read('src/account_client.zig');
  const desktop = read('src/account_desktop.zig');
  const layout = read('src/account_layout.zig');
  const audit = (client, desktop, session) => {
    assert.ok(client.includes('X-Layout-Features: favorite,used,visits,input,settings,hosts,host_removal\\r\\n'));
    assert.match(desktop, /return \.\{ \.settings = app_state.g_layout_settings,/);
    assert.match(desktop, /app_state.g_layout_settings = desired.settings;/);
    assert.match(desktop, /TIMER_ACCOUNT_SAVE, 2000/);
    assert.match(session, /if \(saveSessionTo\(path, null\)\) publishSessionLayout\(\)/);
    assert.match(session, /parseFromValue\(@import\("frequent.zig"\).Settings/);
  };
  audit(client, desktop, session);
  assert.throws(() => audit(client.replace(',input,settings', ',input'), desktop, session));
  assert.throws(() => audit(client, desktop.replace('.settings = app_state.g_layout_settings,', ''), session));
  assert.throws(() => audit(client, desktop, session.replace('if (saveSessionTo(path, null)) publishSessionLayout();', '')));
  assert.match(layout, /\.settings = edited.settings/);
  for (const label of ['Show Frequent split', 'Frequent as first tab', 'Show Favorites split', 'Show All split']) {
    assert.ok(read('src/shortcuts.zig').includes(`Ctrl+K -> ${label}`));
    assert.ok(read('openwiki/operations/keyboard-shortcuts.md').includes(label));
    assert.ok(read('src/sidebar.zig').includes(`L("${label}: ON")`));
  }
});
