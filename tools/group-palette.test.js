const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, 'src', name + '.zig'), 'utf8');
const state = read('app_state');
const sidebar = read('sidebar');
const rename = read('rename');
const session = read('session');
const workspaces = read('workspaces');
const reminders = read('reminders');
const palette = read('command_palette');
function fn(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, name);
  return source.slice(start, source.indexOf('\n}', start) + 2);
}
function block(source, marker) {
  const start = source.indexOf(marker);
  assert.ok(start >= 0, marker);
  let depth = 0;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(marker);
}
function decl(name) {
  const match = state.match(new RegExp(`(?:pub )?const ${name}[^;]+;`));
  assert.ok(match, name);
  return match[0];
}
function harness() {
  const closedCapture = read('console').slice(read('console').indexOf('        var entry: ClosedShell ='), read('console').indexOf('        app_state.g_closed_count += 1;') + '        app_state.g_closed_count += 1;'.length);
  const reminderRead = reminders.slice(reminders.indexOf('        e.group_id = @intCast(json_reader.uint'), reminders.indexOf('        e.pinned_top ='));
  const migration = block(session, 'for (json_reader.array(json_reader.field(json, "groups")))');
  const saving = block(session, 'if (app_state.groups[gi].color_set)');
  const railStart = sidebar.lastIndexOf('        if (!app_state.g_sidebar_collapsed) {', sidebar.indexOf('for (rows_arr[0..row_count], 0..) |row, ri|'));
  const rails = block(sidebar.slice(railStart), 'if (!app_state.g_sidebar_collapsed)');
  const commands = [...rename.matchAll(/const (MENU_\w+) =/g)].map(([, n]) => n);
  const win32 = read('win32');
  const production = [fn(sidebar, 'createGroup'), fn(sidebar, 'findGroupIdx'), fn(sidebar, 'displayedGroupColor'), ...['paletteGroupId', 'groupPaletteCommand', 'groupPaletteLabel', 'groupPaletteActionAvailable', 'runGroupPaletteAction'].map(n => fn(rename, n)), fn(palette, 'appendGroupPaletteResults'), fn(workspaces, 'importWorkspaceGroups'), fn(workspaces, 'restoreClosedShellGroup'), fn(workspaces, 'reopenLastClosedShell')].join('\n').replaceAll('@import("rename.zig").', '');
  return `const std = @import("std");
const json_reader = @import("json_reader.zig");
const archive_rules = @import("archive_rules.zig");
const BROWSER_SPLIT_DEFAULT_PERMILLE = 350;
const app_state = @This();
const HANDLE = ?usize;
const DWORD = u32;
${['MAX_GROUPS', 'MAX_LWS', 'MAX_WORKSPACES', 'GROUP_COLORS', 'GROUP_COLOR_NAMES', 'SEARCH_GROUPCTX_BASE', 'SEARCH_GROUPCTX_COUNT'].map(decl).join('\n')}
${block(state, 'const TabGroup = struct')};
${commands.map(n => win32.match(new RegExp('pub const ' + n + '[^;]+;'))[0]).join('\n')}
const WM_APP_SEARCH_OPEN = 1;
var groups: [MAX_GROUPS]TabGroup = undefined;
var group_count: u32 = 0;
var next_group_id: u32 = 1;
var g_light_theme = false;
var g_search_groupctx_mode = false;
var g_groupctx_gid: u32 = 0;
var active_shell: u32 = 0;
var shell_count: u32 = 1;
const ShellKind = enum { cmd, pwsh, vps, tmux, vps2, bash, gitbash };
${block(state, 'pub const ClosedShell = struct')};
${block(state, 'pub const ReminderEntry = struct')};
${block(state, 'const SavedTab = struct')};
const Shell = struct {
    chat_id: u64 = 0, group_id: u32 = 1, workspace: u8 = 0, kind: ShellKind = .cmd, tmux_host: u8 = 0,
    name: [64]u16 = @splat(0), name_len: u32 = 0, name_source: enum { manual, semantic, auto } = .manual,
    tmux_session: [64]u8 = @splat(0), tmux_session_len: u32 = 0, cached_cwd: [512]u8 = @splat(0), cached_cwd_len: u32 = 0,
};
var shells = [_]Shell{.{}, .{}, .{}, .{}};
var g_closed_count: u32 = 0;
var g_closed_history: [10]ClosedShell = undefined;
var g_pending_tmux_host: u8 = 0;
var g_pending_chat_id: u64 = 0;
fn GetTickCount64() u64 { return 1; }
fn spawnShellWithSession(_: ShellKind, _: ?[]const u8, _: ?[]const u8, _: ?usize) bool {
    shells[shell_count] = .{};
    shell_count += 1;
    return true;
}
fn captureClosed(idx: u32) void {
${closedCapture}
}
fn captureReminder(idx: u32) ReminderEntry {
    var e = ReminderEntry{};
${block(fn(reminders, 'reminderFromShell'), 'if (findGroupIdx(app_state.shells[idx].group_id))')}
    return e;
}
fn saveReminder(e: ReminderEntry, json_buf: *[256]u8) []const u8 {
    var pos: usize = 0;
${block(fn(reminders, 'saveReminders'), 'if (e.group_id != 0)')}
    return json_buf[0..pos];
}
fn loadReminder(obj: std.json.Value) ReminderEntry {
    var e = ReminderEntry{};
${reminderRead}
    return e;
}
fn restoreReminderGroup(e: ReminderEntry) void {
    var gi: ?u32 = null;
${block(fn(reminders, 'restoreReminderEntry').slice(fn(reminders, 'restoreReminderEntry').lastIndexOf('if (gi == null and app_state.group_count < MAX_GROUPS)')), 'if (gi == null and app_state.group_count < MAX_GROUPS)')}
}
fn saveWorkspaceColor(gi: usize, json_buf: *[256]u8) []const u8 {
    var pos: usize = 0;
${block(workspaces, 'if (app_state.groups[gi].color_set)')}
    return json_buf[0..pos];
}
fn restoreSnapshotColor(value: std.json.Value) void {
    const group = &groups[0];
${block(fn(reminders, 'wakeSnapshotWorkspace'), 'if (json_reader.boolTrue(value, "color_set"))')}
}
fn appendRootGroups() void {
${palette.match(/    if \(app_state\.g_search_len > 0\) appendGroupPaletteResults\(\);/)[0]}
}
fn appendContextGroups() void {
${block(fn(palette, 'updateSearchResults'), 'if (app_state.g_search_groupctx_mode)')}
}
fn keepSearchSelectionVisible() void {}
var g_search_sel: u32 = 0;
var g_search_scroll: u32 = 0;

var g_pending_new_tab_group: u32 = 0;
var g_single_window = true;
var g_lws_count: u32 = 3;
var g_active_workspace: u32 = 0;
var g_ws_snoozed = [_]bool{false} ** MAX_LWS;
var g_ws_names: [MAX_LWS][32]u8 = @splat(@splat(0));
var g_ws_name_len: [MAX_LWS]u32 = @splat(0);
var g_workspace_count: u32 = 2;
var g_workspaces = [_]struct { name: [64]u8 = @splat(0), name_len: u32 = 0, id: [32]u8 = @splat(0), id_len: u32 = 0, hwnd: HANDLE = null }{.{}, .{}};
var g_main_hwnd: HANDLE = 1;
var g_search_result_count: u32 = 0;
var g_search_results: [128]usize = undefined;
var g_search_len: u32 = 0;
var g_search_buf: [128]u16 = @splat(0);
var moved: usize = 999;
var renamed: u32 = 999;
var closed: u32 = 0;
var locked = false;
var saves: u32 = 0;
fn RGB(r: u8, g: u8, b: u8) u32 { return @as(u32,r) | (@as(u32,g)<<8) | (@as(u32,b)<<16); }
fn customColorOr(_: []const u8, fallback: DWORD) DWORD { return fallback; }
fn workspaceCanMoveIntoClosedStandalone(wi: u32) bool { return wi == 1; }
fn getInstanceName() []const u8 { return "current"; }
fn newPillForMove() ?u8 { return 3; }
fn moveGroupToPill(_: u32, slot: u8) void { moved = slot; }
fn moveGroupToNewWorkspace(_: u32) void { moved = 100; }
fn moveGroupToClosedWorkspace(_: u32, wi: u32) void { moved = 200 + wi; }
fn moveGroupToWorkspace(_: u32, wi: u32) void { moved = 300 + wi; }
fn PostMessageW(_: HANDLE, _: u32, _: usize, _: isize) i32 { return 1; }
fn startGroupRename(gi: u32) void { renamed = gi; }
fn clampSidebarScroll() void {}
fn saveSession() void { saves += 1; }
fn InvalidateRect(_: HANDLE, _: ?usize, _: i32) i32 { return 1; }
fn deleteGroup(gid: u32) void { for (shells[0..shell_count]) |*s| { if (s.group_id == gid) s.group_id = 0; } }
fn normalizeGroupOrder() void {}
fn groupHasLockedSession(_: u32) bool { return locked; }
fn showHeaderNoticeAscii(_: []const u8, _: u32, _: bool) void {}
fn closeShell(_: u32) void { closed += 1; }
fn u16ContainsInsensitive(text: []const u16, query: []const u16) bool { return std.mem.indexOf(u16, text, query) != null; }
const RECT = struct { left: i32 = 0, top: i32 = 0, right: i32 = 0, bottom: i32 = 0 };
const Row = struct { kind: enum { header, tab, section }, gidx: u32 = 0, shell_idx: u32 = 0, y: i32 };
const GROUP_HEADER_H = 24;
var g_sidebar_collapsed = false;
var g_sidebar_scroll: i32 = 5;
var rail_rects: [16]RECT = undefined;
var rail_count: usize = 0;
fn uiScaled(px: i32) i32 { return px; }
fn tabRowH() i32 { return 38; }
${fn(read('inbox'), 'writeUintTo')}
fn appendJsonEscapedWide(buf: *const *[256]u8, pos: *usize, text: []const u16) void { for (text) |wc| { buf.*[pos.*] = @intCast(wc); pos.* += 1; } }
fn CreateSolidBrush(_: DWORD) HANDLE { return 1; }
fn DeleteObject(_: HANDLE) i32 { return 1; }
fn FillRect(_: HANDLE, rc: *RECT, _: HANDLE) i32 { rail_rects[rail_count] = rc.*; rail_count += 1; return 1; }
fn paintRails(rows_arr: []const Row) void {
    const row_count = rows_arr.len;
    const hdc: HANDLE = null;
    const column = RECT{ .left = 8, .right = 216 };
    ${rails}
}
${production}
test "split persistence leaves minimum pane widths to the shared geometry clamp" {
    for ([_]u32{0, 40, 350, 960, 1000, 5000}) |split| {
        var buf: [256]u8 = undefined;
        const json = try std.fmt.bufPrint(&buf, "{{\\"tabs\\":[{{\\"kind\\":\\"cmd\\",\\"name\\":\\"T\\",\\"bsplit\\":{d}}}]}}", .{split});
        var parsed = try json_reader.parse(std.testing.allocator, json);
        defer parsed.deinit();
        var tabs: [1]SavedTab = undefined;
        try std.testing.expectEqual(@as(u32, 1), json_reader.sessionTabs(parsed.value, &tabs, 16));
        try std.testing.expectEqual(@as(u16, @intCast(@min(split, 1000))), tabs[0].bsplit_permille);
    }
}
test "empty root excludes group rows while context and typed search include them" {
    group_count = 0;
    next_group_id = 1;
    _ = createGroup(&.{'A'});
    shells[0].group_id = groups[0].id;
    active_shell = 0;
    shell_count = 1;
    g_search_len = 0;
    g_search_result_count = 0;
    g_search_groupctx_mode = false;
    appendRootGroups();
    try std.testing.expectEqual(@as(u32, 0), g_search_result_count);
    g_search_groupctx_mode = true;
    g_groupctx_gid = groups[0].id;
    appendContextGroups();
    try std.testing.expect(g_search_result_count > 0);
    g_search_groupctx_mode = false;
    g_search_result_count = 0;
    g_search_len = 6;
    @memcpy(g_search_buf[0..6], &[_]u16{'R','e','n','a','m','e'});
    appendRootGroups();
    try std.testing.expectEqual(@as(u32, 1), g_search_result_count);
    g_search_len = 0;
    g_search_result_count = 0;
}
test "picked colors survive closed tab reopen, reminders and layout export import including palette zero" {
    for ([_]u8{0, 4, 7}) |color| {
        for ([_]bool{false, true}) |picked| {
            group_count = 0;
            next_group_id = 1;
            shell_count = 1;
            _ = createGroup(&.{'G'});
            groups[0].color = if (picked) color else 7;
            groups[0].color_set = picked;
            groups[0].collapsed = true;
            shells[0].group_id = groups[0].id;
            g_closed_count = 0;
            captureClosed(0);
            const reminder = captureReminder(0);
            var buf: [256]u8 = undefined;
            const color_json = saveWorkspaceColor(0, &buf);
            var layout_buf: [512]u8 = undefined;
            const layout_json = try std.fmt.bufPrint(&layout_buf, "{{\\"groups\\":[{{\\"id\\":1,\\"name\\":\\"G\\"{s}}}]}}", .{color_json});
            group_count = 0;
            var tabs = [_]SavedTab{std.mem.zeroes(SavedTab)};
            tabs[0].group_id = 1;
            try std.testing.expect(importWorkspaceGroups(layout_json, &tabs));
            try std.testing.expectEqual(picked, groups[0].color_set);
            try std.testing.expectEqual(if (picked) color else @as(u8, 7), groups[0].color);
            try std.testing.expectEqual(groups[0].id, tabs[0].group_id);
            group_count = 0;
            reopenLastClosedShell();
            try std.testing.expectEqual(@as(u32, 1), group_count);
            try std.testing.expectEqual(picked, groups[0].color_set);
            try std.testing.expectEqual(if (picked) color else @as(u8, 7), groups[0].color);
            try std.testing.expectEqual(groups[0].id, shells[1].group_id);
            try std.testing.expect(groups[0].collapsed);
            const reminder_fields = saveReminder(reminder, &buf);
            var reminder_buf: [512]u8 = undefined;
            const reminder_json = try std.fmt.bufPrint(&reminder_buf, "{{\\"unused\\":0{s}}}", .{reminder_fields});
            var parsed = try json_reader.parse(std.testing.allocator, reminder_json);
            defer parsed.deinit();
            const loaded = loadReminder(parsed.value);
            group_count = 0;
            restoreReminderGroup(loaded);
            try std.testing.expectEqual(picked, groups[0].color_set);
            try std.testing.expectEqual(if (picked) color else @as(u8, 7), groups[0].color);
            var snapshot = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, if (picked) "{\\"color\\":0,\\"color_set\\":true}" else "{\\"color\\":4}", .{});
            defer snapshot.deinit();
            groups[0].color = 7;
            groups[0].color_set = false;
            restoreSnapshotColor(snapshot.value);
            try std.testing.expectEqual(picked, groups[0].color_set);
            try std.testing.expectEqual(if (picked) @as(u8,0) else 7, groups[0].color);
        }
    }
    var legacy = try json_reader.parse(std.testing.allocator, "{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Old\\",\\"color\\":4}]}");
    defer legacy.deinit();
    group_count = 0;
    var tabs = [_]SavedTab{std.mem.zeroes(SavedTab)};
            tabs[0].group_id = 1;
    try std.testing.expect(importWorkspaceGroups("{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Old\\",\\"color\\":4}]}", &tabs));
    try std.testing.expect(!groups[0].color_set);
    try std.testing.expectEqual(@as(u8, 7), groups[0].color);
    var old_reminder = try json_reader.parse(std.testing.allocator, "{\\"group_id\\":1,\\"group_color\\":4}");
    defer old_reminder.deinit();
    const old = loadReminder(old_reminder.value);
    try std.testing.expect(!old.group_color_set);
    try std.testing.expectEqual(@as(u8, 7), old.group_color);
    group_count = 0;
    shell_count = 1;
    g_search_len = 0;
    g_search_result_count = 0;
}
test "rails span header and all members exactly once, excluding ungrouped rows" {
    group_count = 0;
    next_group_id = 1;
    _ = createGroup(&.{'A'});
    _ = createGroup(&.{'B'});
    shells[0].group_id = 1;
    shells[1].group_id = 1;
    shells[2].group_id = 0;
    const rows = [_]Row{
        .{ .kind = .header, .gidx = 0, .y = 8 },
        .{ .kind = .tab, .gidx = 0, .shell_idx = 0, .y = 32 },
        .{ .kind = .tab, .gidx = 0, .shell_idx = 1, .y = 70 },
        .{ .kind = .tab, .gidx = 0, .shell_idx = 2, .y = 108 },
        .{ .kind = .header, .gidx = 1, .y = 146 },
    };
    paintRails(&rows);
    try std.testing.expectEqual(@as(usize, 2), rail_count);
    try std.testing.expectEqual(RECT{ .left = 8, .right = 11, .top = 3, .bottom = 103 }, rail_rects[0]);
    try std.testing.expectEqual(RECT{ .left = 8, .right = 11, .top = 141, .bottom = 165 }, rail_rects[1]);
    g_sidebar_collapsed = true;
    paintRails(&rows);
    try std.testing.expectEqual(@as(usize, 2), rail_count);
}
fn restore(json: std.json.Value) void {
    group_count = 0;
    next_group_id = 1;
    ${migration}
}
fn serializedColor(gi: usize, json_buf: *[256]u8) []const u8 {
    var pos: usize = 0;
    ${saving}
    return json_buf[0..pos];
}
test "new and legacy groups are neutral in both themes; explicit choices survive save and restore" {
    group_count = 0;
    _ = createGroup(&.{'T'});
    try std.testing.expect(!groups[0].color_set);
    try std.testing.expectEqual(@as(u8, 7), groups[0].color);
    for ([_]bool{false, true}) |light| {
        g_light_theme = light;
        try std.testing.expectEqual(if (light) RGB(130,134,140) else RGB(145,149,157), displayedGroupColor(0));
    }
    const cases = [_][]const u8{
        "{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Old\\",\\"color\\":2}]}",
        "{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Old\\",\\"color\\":2,\\"color_set\\":false}]}",
        "{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Chosen\\",\\"color\\":0,\\"color_set\\":true}]}",
        "{\\"groups\\":[{\\"id\\":1,\\"name\\":\\"Chosen\\",\\"color\\":7,\\"color_set\\":true}]}"
    };
    for (cases, 0..) |bytes, i| {
        var parsed = try json_reader.parse(std.testing.allocator, bytes);
        defer parsed.deinit();
        restore(parsed.value);
        try std.testing.expectEqual(@as(u32,1), group_count);
        try std.testing.expectEqual(i >= 2, groups[0].color_set);
        try std.testing.expectEqual(if (i == 2) @as(u8,0) else @as(u8,7), groups[0].color);
        var buf: [256]u8 = undefined;
        const saved = serializedColor(0, &buf);
        if (i < 2) try std.testing.expectEqualStrings("", saved) else {
            try std.testing.expect(std.mem.indexOf(u8, saved, "\\"color_set\\":true") != null);
            try std.testing.expectEqual(GROUP_COLORS[groups[0].color], displayedGroupColor(0));
        }
    }
    runGroupPaletteAction(null, 0, 8);
    try std.testing.expect(groups[0].color_set);
    try std.testing.expectEqual(@as(u8,0), groups[0].color);
}
test "group band covers popup actions, scoped target, search and workspace destinations" {
    group_count = 0;
    next_group_id = 1;
    _ = createGroup(&.{'A'});
    _ = createGroup(&.{'B'});
    shells[0].group_id = 1;
    g_search_groupctx_mode = false;
    try std.testing.expectEqual(@as(u32,1), paletteGroupId());
    g_search_groupctx_mode = true;
    g_groupctx_gid = 2;
    try std.testing.expectEqual(@as(u32,2), paletteGroupId());
    appendGroupPaletteResults();
    try std.testing.expectEqual(@as(u32,17), g_search_result_count);
    for (g_search_results[0..g_search_result_count]) |target| {
        try std.testing.expect(target >= SEARCH_GROUPCTX_BASE and target < SEARCH_GROUPCTX_BASE + SEARCH_GROUPCTX_COUNT);
        const action = target - SEARCH_GROUPCTX_BASE;
        try std.testing.expect(groupPaletteCommand(action) != 0);
        var label: [192]u16 = undefined;
        try std.testing.expect(groupPaletteLabel(action, &label) > 0);
    }
    g_search_len = 6;
    @memcpy(g_search_buf[0..6], &[_]u16{'R','e','n','a','m','e'});
    g_search_result_count = 0;
    appendGroupPaletteResults();
    try std.testing.expectEqual(@as(u32,1), g_search_result_count);
    try std.testing.expectEqual(SEARCH_GROUPCTX_BASE + 1, g_search_results[0]);
    runGroupPaletteAction(null, 1, 1);
    try std.testing.expectEqual(@as(u32,1), renamed);
    runGroupPaletteAction(null, 1, 2);
    try std.testing.expect(groups[1].collapsed and !groups[0].collapsed);
    runGroupPaletteAction(null, 1, 0);
    try std.testing.expectEqual(@as(u32,2), g_pending_new_tab_group);
    for (8..16) |action| {
        runGroupPaletteAction(null, 1, action);
        try std.testing.expectEqual(@as(u8,@intCast(action-8)), groups[1].color);
        try std.testing.expect(groups[1].color_set);
    }
    runGroupPaletteAction(null, 1, 17);
    try std.testing.expectEqual(@as(usize,1), moved);
    runGroupPaletteAction(null, 1, 26);
    try std.testing.expectEqual(@as(usize,201), moved);
    locked = true;
    shells[1].group_id = 2;
    shell_count = 2;
    runGroupPaletteAction(null, 1, 4);
    try std.testing.expectEqual(@as(u32,0), closed);
    locked = false;
    runGroupPaletteAction(null, 1, 4);
    try std.testing.expectEqual(@as(u32,1), closed);
    runGroupPaletteAction(null, 1, 3);
    try std.testing.expectEqual(@as(u32,0), shells[1].group_id);
    try std.testing.expectEqual(@as(u32,1), shells[0].group_id);
}
`;
}
test('extracted production group default, migration, explicit colors and palette dispatch', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'group-palette-'));
  try {
    for (const name of ['json_reader', 'archive_rules', 'frequent', 'voice_filter']) fs.copyFileSync(path.join(root, 'src', name + '.zig'), path.join(dir, name + '.zig'));
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, harness());
    const result = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    console.log(result.stderr.trim());
    for (const [name, mutate] of [
      ['empty root group rows', text => text.replace('if (app_state.g_search_len > 0) appendGroupPaletteResults();', 'appendGroupPaletteResults();')],
      ['closed tab color loss', text => text.replace('app_state.groups[idx].color_set = saved.color_set;', 'app_state.groups[idx].color_set = false;')],
      ['zero color export loss', text => text.replace('if (app_state.groups[gi].color_set)', 'if (app_state.groups[gi].color != 0)')],
      ['reminder color loss', text => text.replace('.color_set = e.group_color_set', '.color_set = false')],
    ]) {
      const original = harness();
      const mutated = mutate(original);
      assert.notEqual(mutated, original, name);
      fs.writeFileSync(file, mutated);
      const bad = spawnSync(process.env.ZIG || path.join(os.homedir(), 'zig/zig'), ['test', file], { encoding: 'utf8', timeout: 120000 });
      assert.notEqual(bad.status, 0, name);
      assert.match(bad.stderr, /FAIL/, name);
      console.log(`${name} rejected`);
    }
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
test('group palette is painted and dispatched before open-ended palette bands', () => {
  const main = read('main');
  const confirm = main.slice(main.indexOf('WM_APP_SEARCH_CONFIRM =>'));
  assert.ok(confirm.indexOf('target >= app_state.SEARCH_GROUPCTX_BASE') < confirm.indexOf('target >= SEARCH_ADDFAVICON_OFFSET'));
  assert.ok(sidebar.indexOf('if (result_idx >= app_state.SEARCH_GROUPCTX_BASE') < sidebar.indexOf('} else if (is_addfavicon)'));
  assert.match(main, /openGroupContextPalette\(hwnd, gidx\)/);
  assert.doesNotMatch(rename, /TrackPopupMenu\(/);
  assert.match(read('command_palette'), /if \(app_state\.g_search_len > 0\) appendGroupPaletteResults\(\);\n    sortSearchResultsByRank/);
  assert.match(fn(rename, 'openGroupContextPalette'), /g_search_groupctx_mode = true/);
  assert.match(read('shortcuts'), /Right-click group \/ Ctrl\+K/);
});
test('one rail is painted per header, over every member row, after row backgrounds', () => {
  assert.doesNotMatch(sidebar, /gstripe_rc|stripe_rc/);
  const start = sidebar.indexOf('for (rows_arr[0..row_count], 0..) |row, ri|');
  const rail = sidebar.slice(start, sidebar.indexOf('const btns_y', start));
  assert.match(rail, /row.kind != \.header/);
  assert.match(rail, /member\.y \+ tabRowH\(\)/);
  assert.match(rail, /group_id != app_state.groups\[row.gidx\].id/);
  assert.match(rail, /\.top = row.y - app_state.g_sidebar_scroll/);
  assert.match(rail, /\.bottom = bottom - app_state.g_sidebar_scroll/);
  assert.ok(start > sidebar.indexOf('const hl_brush'));
});
