const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');
const service = read('service/worker.js');
const validation = service.slice(service.indexOf('export function validateLayout('), service.indexOf('\nfunction validateCrashReport(')).replace('export ', '');
const response = service.slice(service.indexOf('function layoutResponse('), service.indexOf('\nexport function validateLayout('));
const context = vm.createContext({ Request, Response, TextEncoder });
vm.runInContext("const fail = (status, error) => { throw Object.assign(new Error(error), {status}); }; const json = value => new Response(JSON.stringify(value)); const layoutFeature = (request, token) => (request.headers.get('X-Layout-Features') || '').split(',').some(feature => feature.trim() === token);" + validation + response, context);
const layout = () => ({ schema: 1, revision: 0, workspaces: [{ name: 'Home' }], tabs: [{ kind: 'tmux', name: 'Session', tmux_host: 0, tmux_session: 'one', workspace: 'Home' }] });
const group = name => ({ name, collapsed: false, color: 7, color_set: false });

test('IGSH-556: service accepts old layouts and both group memberships, rejects invalid groups', () => {
  context.value = layout();
  assert.doesNotThrow(() => vm.runInContext('validateLayout(value)', context));
  Object.assign(context.value.tabs[0], { group_id: 17, starred_group_id: 29, group: group('Home'), starred_group: group('Favorites') });
  assert.doesNotThrow(() => vm.runInContext('validateLayout(value)', context));
  for (const bad of [-1, 1.5, 2 ** 32, '29', null]) {
    const saved = context.value.tabs[0].starred_group_id;
    context.value.tabs[0].starred_group_id = bad;
    assert.throws(() => vm.runInContext('validateLayout(value)', context), /invalid_tab/);
    context.value.tabs[0].starred_group_id = saved;
  }
  for (const bad of [null, {}, { ...group('F'), color: 8 }, { ...group('F'), collapsed: 'false' }, group(''), { ...group('F'), private: 'extra' }]) {
    context.value.tabs[0].starred_group = bad;
    assert.throws(() => vm.runInContext('validateLayout(value)', context), /invalid_tab/);
  }
});

test('IGSH-556: negotiated responses hide groups from old clients without losing stored fields', async () => {
  context.value = layout();
  Object.assign(context.value.tabs[0], { group_id: 17, starred_group_id: 29, group: group('Home'), starred_group: group('Favorites') });
  context.request = new Request('https://example.test/v1/layout', { headers: { 'X-Layout-Features': 'groups' } });
  const modern = await vm.runInContext('layoutResponse(request, {layout: value})', context).json();
  assert.equal(modern.layout.tabs[0].group_id, 17);
  assert.equal(modern.layout.tabs[0].starred_group_id, 29);
  context.request = new Request('https://example.test/v1/layout');
  const legacy = await vm.runInContext('layoutResponse(request, {layout: value})', context).json();
  assert.equal(Object.hasOwn(legacy.layout.tabs[0], 'starred_group_id'), false);
  assert.equal(Object.hasOwn(legacy.layout.tabs[0], 'group'), false);
  assert.equal(context.value.tabs[0].starred_group_id, 29);
  const start = service.indexOf("          if (!layoutFeature(request, 'groups')) {");
  const end = service.indexOf("          if (!layoutFeature(request, 'favorite')) {", start);
  assert.ok(start >= 0 && end > start);
  context.previous = context.value.tabs[0];
  context.tab = layout().tabs[0];
  vm.runInContext(service.slice(start, end), context);
  assert.equal(context.tab.group_id, 17);
  assert.equal(context.tab.starred_group_id, 29);
});

test('IGSH-556: persistence and lifecycle paths retain the independent field', () => {
  const field = 'starred_group_id';
  for (const file of ['app_state', 'session', 'json_reader', 'launch_snapshot', 'launch_cache', 'session_layout', 'account_layout', 'account_desktop', 'console', 'reminders', 'workspaces']) {
    assert.ok(read(`src/${file}.zig`).includes(field), file);
  }
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /return if \(app_state.g_starred_workspace\) app_state.shells\[idx\].starred_group_id else app_state.shells\[idx\].group_id/);
  assert.match(sidebar, /shells\[i\].group_id == gid or app_state.shells\[i\].starred_group_id == gid/);
  assert.match(read('src/inbox.zig'), /if \(!app_state.shells\[idx\].favorite\) \{\s*app_state.shells\[idx\].starred_group_id = 0/);
  assert.equal((read('src/command_palette.zig').match(/groupInCurrentWorkspace\(app_state.groups\[gi\].id\)/g) || []).length, 3);
  for (const file of ['sidebar', 'session', 'session_layout', 'launch_snapshot', 'account_layout']) {
    assert.match(read(`src/${file}.zig`), /test "IGSH-556/);
  }
  const main = read('src/main.zig');
  for (const file of ['sidebar', 'session', 'launch_snapshot']) assert.ok(main.includes(`_ = @import("${file}.zig");`));
  for (const file of ['session_layout', 'account_layout']) assert.ok(read('build.zig').includes(`b.path("src/${file}.zig")`));
  assert.match(read('src/account_client.zig'), /X-Layout-Features: [^"\n]*hosts,groups/);
});
