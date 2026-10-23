const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('IGSH-556: groups stay local without account layout or Worker fields', () => {
  const audit = source => assert.doesNotMatch(source, /\b(?:group_id|starred_group\w*)\b/);
  const files = fs.readdirSync(path.join(__dirname, '..', 'src'))
    .filter(file => /^account_.*\.zig$/.test(file))
    .map(file => `src/${file}`);
  for (const file of [...files, 'src/session_layout.zig', 'service/worker.js', 'service/test/worker.test.js']) {
    audit(read(file));
  }
  for (const field of ['group_id', 'starred_group_id', 'starred_group']) {
    assert.throws(() => audit(`tab.${field} = 17;`), assert.AssertionError);
  }
  const header = source => assert.match(source, /X-Layout-Features: favorite,used,visits,input,settings,hosts,host_removal\\r\\n/);
  const client = read('src/account_client.zig');
  header(client);
  assert.throws(() => header(client.replace('settings,hosts', 'settings,hosts,groups')), assert.AssertionError);
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
  assert.equal((read('src/command_palette.zig').match(/groupInCurrentWorkspace\(app_state.groups\[gi\].id\)/g) || []).length, 3);
  for (const file of ['sidebar', 'session', 'launch_snapshot']) {
    assert.match(read(`src/${file}.zig`), /test "IGSH-556/);
  }
  const main = read('src/main.zig');
  for (const file of ['sidebar', 'session', 'launch_snapshot']) assert.ok(main.includes(`_ = @import("${file}.zig");`));
});
