const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const read = path => fs.readFileSync(new URL('../' + path, 'file://' + __filename), 'utf8');
const worker = read('service/worker.js');
const tab = { kind: 'tmux', name: 'Agent', tmux_session: 'one', tmux_host: 0, workspace: 'Main' };
const layout = { schema: 1, revision: 1, workspaces: [{ name: 'Main' }], tabs: [tab] };
const features = 'favorite,groups,group_order,starred_groups';

function sandbox() {
  const start = worker.indexOf('export function validateLayout(');
  const end = worker.indexOf('\nfunction validateCrashReport', start);
  const source = worker.slice(worker.indexOf('const json ='), worker.indexOf('export function validateLayout')) + worker.slice(start, end).replace('export ', '');
  const context = { Response, TextEncoder, validate: null, respond: null };
  vm.runInNewContext(source + '\nvalidate = validateLayout; respond = layoutResponse;', context);
  return context;
}

function save(previous, incoming, tokens) {
  const start = worker.indexOf('        for (const tab of layout.tabs) {');
  const end = worker.indexOf("          const photo = photos.get(", start);
  assert.ok(start >= 0 && end > start);
  const context = { previousLayout: structuredClone(previous), layout: structuredClone(incoming), req: new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }) };
  const stored = 'const stored = new Map((previousLayout?.tabs || []).map(tab => [`${tab.tmux_host}:${tab.tmux_session.toLowerCase()}`, tab]));\n';
  vm.runInNewContext(worker.slice(worker.indexOf('const layoutFeature ='), worker.indexOf('function layoutResponse')) + stored + worker.slice(start, end) + '}', context);
  return JSON.parse(JSON.stringify(context.layout));
}

test('IGSH-1890 the Worker accepts a Favorites group name per tab and rejects malformed ones', () => {
  const { validate } = sandbox();
  for (const starred_group of ['', 'Hypertask', 'x'.repeat(64)]) {
    assert.doesNotThrow(() => validate({ ...layout, tabs: [{ ...tab, starred_group }] }), `accepts ${JSON.stringify(starred_group)}`);
  }
  for (const starred_group of [null, 1, true, ['Hypertask'], 'x'.repeat(65), 'bad\u0000name']) {
    assert.throws(() => validate({ ...layout, tabs: [{ ...tab, starred_group }] }), { status: 400, message: 'invalid_tab' });
  }
});

test('IGSH-1890 only clients that advertise starred_groups see Favorites groups and the capability', async () => {
  const { respond } = sandbox();
  const stored = { ...layout, tabs: [{ ...tab, favorite: true, starred_group: 'Hypertask' }] };
  for (const [tokens, sees] of [['', false], ['favorite,groups,group_order', false], [features, true]]) {
    const response = respond(new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }), { layout: stored });
    assert.equal(response.headers.get('X-Layout-Features').split(',').includes('starred_groups'), sees);
    const body = (await response.json()).layout.tabs[0];
    assert.equal(Object.hasOwn(body, 'starred_group'), sees);
    if (sees) assert.equal(body.starred_group, 'Hypertask');
  }
});

test('IGSH-1890 a client without starred_groups cannot erase or invent a Favorites group', () => {
  const stored = { ...layout, tabs: [{ ...tab, starred_group: 'Hypertask' }] };
  assert.equal(save(stored, layout, 'favorite,groups,group_order').tabs[0].starred_group, 'Hypertask');
  assert.equal(save(stored, { ...layout, tabs: [{ ...tab, starred_group: 'Other' }] }, 'groups').tabs[0].starred_group, 'Hypertask');
  assert.ok(!Object.hasOwn(save(layout, { ...layout, tabs: [{ ...tab, starred_group: 'Other' }] }, 'groups').tabs[0], 'starred_group'));
  assert.equal(save(stored, { ...layout, tabs: [{ ...tab, starred_group: 'Multi Bot' }] }, features).tabs[0].starred_group, 'Multi Bot');
  assert.equal(save(stored, { ...layout, tabs: [{ ...tab, starred_group: '' }] }, features).tabs[0].starred_group, '');
});

test('IGSH-1890 the desktop captures, orders, publishes, pulls and applies Favorites groups', () => {
  const desktop = read('src/account_desktop.zig');
  const layoutZig = read('src/account_layout.zig');
  const client = read('src/account_client.zig');
  const sidebar = read('src/sidebar.zig');
  const session = read('src/session_layout.zig');
  const capture = desktop.slice(desktop.indexOf('pub fn captureSessionLayout('), desktop.indexOf('var g_account_hosts_cache'));
  assert.match(capture, /\.starred_group = /, 'capture sends the Favorites group name');
  assert.match(desktop.slice(desktop.indexOf('pub fn applyServerLayout(')), /if \(tab\.starred_group\) \|name\| shell\.starred_group_id = /, 'apply places the tab in its Favorites group');
  assert.match(sidebar.slice(sidebar.indexOf('fn groupNameInTabs(')), /tab\.starred_group/, 'group order lists Favorites groups');
  assert.match(desktop, /if \(!app_state\.g_account_starred_groups_supported\) \{\s*plain_local = account_layout\.withoutStarredGroups\(arena\.allocator\(\), plain_local\) catch return;/);
  assert.match(desktop, /if \(!remote\.starred_groups_supported\) rebased = try account_layout\.withoutStarredGroups\(alloc, rebased\)/);
  assert.equal((desktop.match(/reply\.starred_groups_supported = remote\.starred_groups_supported/g) || []).length, 2);
  assert.match(desktop, /app_state\.g_account_starred_groups_supported = reply\.starred_groups_supported/);
  assert.match(desktop, /app_state\.g_account_starred_groups_supported = false/);
  assert.match(client, /groups,group_order,starred_groups/);
  assert.match(client, /starred_groups_supported = layoutSupports\(raw, "starred_groups"\)/);
  assert.match(session, /starred_group: \?\[\]const u8 = null/);
  assert.match(layoutZig, /!eq\(u8, x\.starred_group orelse "", y\.starred_group orelse ""\)/, 'a Favorites move is a publishable edit');
  assert.match(layoutZig, /if \(tab\.starred_group == null\) tab\.starred_group = local\.tabs\[i\]\.starred_group/);
  assert.match(layoutZig, /if \(tab\.starred_group == null\) tab\.starred_group = base\.tabs\[i\]\.starred_group/);
  assert.match(layoutZig, /if \(edited\.tabs\[ei\]\.starred_group\) \|group\|/);
});
