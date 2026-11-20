const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fnBody(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `missing ${name}`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `unterminated ${name}`);
  return source.slice(start, end + 3);
}

function structBlock(source, marker) {
  const start = source.indexOf(marker);
  assert.ok(start >= 0, marker);
  let depth = 0;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  assert.fail(marker);
}

function harness() {
  const desktop = read('src/account_desktop.zig');
  const sidebar = read('src/sidebar.zig');
  const state = read('src/app_state.zig');
  const production = [
    ...['syncedGroupId', 'groupNamed', 'groupNameSurvivesIn', 'groupHasMember', 'groupsWithMembers', 'dropEmptiedGroups'].map(name => fnBody(desktop, name)),
    ...['findGroupIdx', 'createGroup', 'deleteGroup', 'moveGroupToIndex', 'orderGroupsByName'].map(name => fnBody(sidebar, name)),
  ].join('\n').replaceAll('@import("sidebar.zig").', '');
  return `const std = @import("std");
const app_state = @This();
const MAX_GROUPS: usize = 16;
const session_layout = struct {
    const Tab = struct { group: ?[]const u8 = null, starred_group: ?[]const u8 = null };
};
${structBlock(state, 'const TabGroup = struct')};
var groups: [MAX_GROUPS]TabGroup = undefined;
var group_count: u32 = 0;
var next_group_id: u32 = 1;
const Shell = struct { group_id: u32 = 0, starred_group_id: u32 = 0 };
var shells = [_]Shell{.{}} ** 4;
var shell_count: u32 = 0;
${production}
fn makeGroup(idx: usize, id: u32, text: []const u8, color: u8, color_set: bool, collapsed: bool) void {
    groups[idx] = .{ .id = id, .name = @splat(0), .name_len = @intCast(text.len), .collapsed = collapsed, .color = color, .color_set = color_set };
    for (text, 0..) |ch, i| groups[idx].name[i] = @intCast(ch);
}
fn groupName(idx: usize, buf: *[64]u8) []const u8 {
    const len = std.unicode.utf16LeToUtf8(buf, groups[idx].name[0..groups[idx].name_len]) catch return "";
    return buf[0..len];
}
test "SOFT-2324 rename on another device keeps the group colour, folded state and place" {
    group_count = 0;
    next_group_id = 13;
    makeGroup(0, 10, "Personal", 7, false, false);
    makeGroup(1, 11, "Work", 4, true, true);
    makeGroup(2, 12, "Archive", 2, true, false);
    group_count = 3;
    shell_count = 1;
    shells[0] = .{ .group_id = 11 };
    var filled: [MAX_GROUPS]u32 = undefined;
    const had = groupsWithMembers(&filled);
    const tabs = [_]session_layout.Tab{.{ .group = "Office" }};
    const gid = try syncedGroupId(shells[0].group_id, "Office", false, &tabs);
    shells[0].group_id = gid;
    dropEmptiedGroups(had);
    _ = orderGroupsByName(&[_][]const u8{ "Personal", "Office", "Archive" });
    try std.testing.expectEqual(@as(u32, 3), group_count);
    try std.testing.expectEqual(@as(u32, 11), gid);
    try std.testing.expectEqual(@as(u32, 11), groups[1].id);
    try std.testing.expectEqual(@as(u32, 11), shells[0].group_id);
    try std.testing.expect(groups[1].color_set);
    try std.testing.expectEqual(@as(u8, 4), groups[1].color);
    try std.testing.expect(groups[1].collapsed);
    var name_buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Office", groupName(1, &name_buf));
}
test "SOFT-2324 a group the sync empties is not left saved" {
    group_count = 0;
    next_group_id = 22;
    makeGroup(0, 20, "Office", 3, true, false);
    makeGroup(1, 21, "Work", 5, true, true);
    group_count = 2;
    shell_count = 2;
    shells[0] = .{ .group_id = 21 };
    shells[1] = .{ .group_id = 20 };
    var filled: [MAX_GROUPS]u32 = undefined;
    const had = groupsWithMembers(&filled);
    const tabs = [_]session_layout.Tab{.{ .group = "Office" }, .{ .group = "Office" }};
    shells[0].group_id = try syncedGroupId(shells[0].group_id, "Office", false, &tabs);
    shells[1].group_id = try syncedGroupId(shells[1].group_id, "Office", false, &tabs);
    dropEmptiedGroups(had);
    try std.testing.expectEqual(@as(u32, 1), group_count);
    try std.testing.expectEqual(@as(u32, 20), groups[0].id);
    try std.testing.expectEqual(@as(u32, 20), shells[0].group_id);
}
test "SOFT-2324 groups that were already empty before the sync stay saved" {
    group_count = 0;
    next_group_id = 32;
    makeGroup(0, 30, "Office", 3, true, false);
    makeGroup(1, 31, "Scratch", 7, false, false);
    group_count = 2;
    shell_count = 1;
    shells[0] = .{ .group_id = 30 };
    var filled: [MAX_GROUPS]u32 = undefined;
    const had = groupsWithMembers(&filled);
    dropEmptiedGroups(had);
    try std.testing.expectEqual(@as(u32, 2), group_count);
    try std.testing.expectEqual(@as(u32, 31), groups[1].id);
}
test "SOFT-2324 a matching group name still syncs without a rename" {
    group_count = 0;
    next_group_id = 41;
    makeGroup(0, 40, "Work", 6, true, true);
    group_count = 1;
    shell_count = 1;
    shells[0] = .{ .group_id = 40 };
    const tabs = [_]session_layout.Tab{.{ .group = "Work" }};
    try std.testing.expectEqual(@as(u32, 40), try syncedGroupId(shells[0].group_id, "Work", false, &tabs));
    try std.testing.expectEqual(@as(u32, 1), group_count);
}
`;
}

const source = read('src/account_desktop.zig');
const apply = source.slice(source.indexOf('pub fn applyServerLayout('), source.indexOf('\nfn accountDevices('));

test('SOFT-2324 the apply path hands the synced tabs to the group mapping and drops emptied groups', () => {
  assert.match(apply, /const had_members = groupsWithMembers\(&filled_before\);/);
  assert.match(apply, /syncedGroupId\(shell\.group_id, name, false, desired\.tabs\)/);
  assert.match(apply, /syncedGroupId\(shell\.starred_group_id, name, true, desired\.tabs\)/);
  const drop = apply.indexOf('dropEmptiedGroups(had_members);');
  assert.ok(drop > apply.indexOf('for (desired.tabs, 0..) |tab, dest|'), 'leftovers are dropped after the tabs are mapped');
  assert.ok(drop < apply.indexOf('saveSession();'), 'leftovers are dropped before the layout is saved');
});

test('SOFT-2324 the group rename harness imports only std', () => {
  const reached = [...new Set([...harness().matchAll(/@import\("([^"]+)"\)/g)].map(([, name]) => name))].filter(name => name !== 'std');
  assert.deepEqual(reached, [], 'the harness must be self-contained');
});

test('SOFT-2324 extracted group rename keeps identity and drops sync leftovers', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'group-rename-'));
  try {
    const file = path.join(dir, 'test.zig');
    fs.writeFileSync(file, harness());
    const zig = process.env.ZIG || path.join(os.homedir(), 'zig/zig');
    const run = () => spawnSync(zig, ['test', file, '--test-filter', 'SOFT-2324'], { encoding: 'utf8', timeout: 120000 });
    const result = run();
    assert.equal(result.error, undefined);
    assert.equal(result.status, 0, result.stdout + result.stderr);
    console.log(result.stderr.trim());
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
