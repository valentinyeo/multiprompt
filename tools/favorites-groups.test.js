const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('IGSH-556: groups sync behind their own tokens and keep regular and Favorites groups apart', () => {
  const client = read('src/account_client.zig');
  assert.match(client, /X-Layout-Features: favorite,muted,used,visits,input,settings,hosts,host_removal,bot_palette8,groups,group_order,starred_groups/);
  assert.match(client, /starred_groups_supported = layoutSupports\(raw, "starred_groups"\)/);
  const worker = read('service/worker.js');
  assert.match(worker, /if \(!layoutFeature\(request, 'groups'\)\) delete visible\.group/);
  assert.match(worker, /if \(!layoutFeature\(request, 'starred_groups'\)\) delete visible\.starred_group/);
  const layout = read('src/account_layout.zig');
  assert.match(layout, /x\.group orelse ""/);
  assert.match(layout, /x\.starred_group orelse ""/);
  assert.match(layout, /pub fn withoutStarredGroups/);
  const desktop = read('src/account_desktop.zig');
  assert.match(desktop, /if \(tab\.group\) \|name\| shell\.group_id = try syncedGroupId\(shell\.group_id, name, false/);
  assert.match(desktop, /if \(tab\.starred_group\) \|name\| shell\.starred_group_id = try syncedGroupId\(shell\.starred_group_id, name, true/);
});

test('IGSH-556: persistence and lifecycle paths retain the independent field', () => {
  const field = 'starred_group_id';
  for (const file of ['app_state', 'session', 'json_reader', 'launch_snapshot', 'launch_cache', 'console', 'reminders', 'workspaces']) {
    assert.ok(read(`src/${file}.zig`).includes(field), file);
  }
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /return if \(app_state.g_starred_workspace\) app_state.shells\[idx\].starred_group_id else app_state.shells\[idx\].group_id/);
  assert.match(sidebar, /shells\[i\].group_id == gid or app_state.shells\[i\].starred_group_id == gid/);
  assert.match(read('src/inbox.zig'), /if \(!app_state.shells\[idx\].favorite\) \{\s*app_state.shells\[idx\].starred_group_id = 0/);
  assert.equal((read('src/command_palette.zig').match(/groupInCurrentWorkspace\(app_state.groups\[gi\].id\)/g) || []).length, 2);
  for (const file of ['sidebar', 'session', 'launch_snapshot']) {
    assert.match(read(`src/${file}.zig`), /test "IGSH-556/);
  }
  const main = read('src/main.zig');
  for (const file of ['sidebar', 'session', 'launch_snapshot']) assert.ok(main.includes(`_ = @import("${file}.zig");`));
});

test('IGSH-1185: Starred pins persist independently through all local restore boundaries', () => {
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /return if \(app_state.g_starred_workspace\) app_state.shells\[i\].starred_pinned_top else app_state.shells\[i\].pinned_top/);
  assert.doesNotMatch(sidebar.slice(sidebar.indexOf('pub fn layoutRows('), sidebar.indexOf('pub fn rowTotalHeight(')), /or app_state.g_starred_workspace/);
  for (const file of ['app_state', 'session', 'json_reader', 'launch_snapshot', 'launch_cache', 'console', 'reminders', 'workspaces']) {
    assert.ok(read(`src/${file}.zig`).includes('starred_pinned_top'), file);
  }
  const journey = read('.claude/skills/verify-multiprompt/control-feature-favorites-groups.ps1');
  for (const name of ['starred-pins-before', 'starred-pins-after', 'starred-pins-restarted', 'starred-pins-unpinned']) assert.ok(journey.includes(name), name);
});
