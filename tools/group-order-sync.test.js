const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const read = path => fs.readFileSync(new URL('../' + path, 'file://' + __filename), 'utf8');
const worker = read('service/worker.js');
const layout = { schema: 1, revision: 1, workspaces: [{ name: 'Main' }], tabs: [] };
const features = 'groups,group_order';

function sandbox() {
  const start = worker.indexOf('export function validateLayout(');
  const end = worker.indexOf('\nfunction validateCrashReport', start);
  const source = worker.slice(worker.indexOf('const json ='), worker.indexOf('export function validateLayout')) + worker.slice(start, end).replace('export ', '');
  const context = { Response, TextEncoder, validate: null, respond: null };
  vm.runInNewContext(source + '\nvalidate = validateLayout; respond = layoutResponse;', context);
  return context;
}

function merge(previous, incoming, tokens) {
  const start = worker.indexOf("        if (!layoutFeature(req, 'settings'))");
  const end = worker.indexOf('        const stored = new Map(', start);
  assert.ok(start >= 0 && end > start);
  const context = { previousLayout: structuredClone(previous), layout: structuredClone(incoming), req: new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }) };
  vm.runInNewContext(worker.slice(worker.indexOf('const layoutFeature ='), worker.indexOf('function layoutResponse')) + worker.slice(start, end), context);
  return JSON.parse(JSON.stringify(context.layout));
}

test('IGSH-1890 the Worker accepts a group order and rejects malformed ones', () => {
  const { validate } = sandbox();
  for (const group_order of [[], ['Work'], ['Work', 'Home'], Array.from({ length: 16 }, (_, i) => `G${i}`)]) {
    assert.doesNotThrow(() => validate({ ...layout, group_order }));
  }
  for (const group_order of [null, {}, 'Work', [1], [''], ['Work', 'Work'], Array.from({ length: 17 }, (_, i) => `G${i}`), ['x'.repeat(65)], ['bad\u0000name']]) {
    assert.throws(() => validate({ ...layout, group_order }), { status: 400, message: 'invalid_layout' });
  }
});

test('IGSH-1890 only clients that advertise group_order see the order and the capability', async () => {
  const { respond } = sandbox();
  const stored = { ...layout, group_order: ['Work', 'Home'] };
  for (const [tokens, sees] of [['', false], ['groups', false], ['favorite,muted,used,visits,input,settings,hosts,host_removal,bot_palette8,groups', false], [features, true]]) {
    const response = respond(new Request('https://example.com', { headers: { 'X-Layout-Features': tokens } }), { layout: stored });
    const advertised = response.headers.get('X-Layout-Features').split(',');
    assert.equal(advertised.includes('group_order'), sees);
    assert.ok(advertised.includes('groups'));
    const body = (await response.json()).layout;
    assert.equal(Object.hasOwn(body, 'group_order'), sees);
    if (sees) assert.deepEqual(body.group_order, ['Work', 'Home']);
  }
});

test('IGSH-1890 a client without group_order cannot erase or invent the stored order', () => {
  const stored = { ...layout, group_order: ['Work', 'Home'] };
  assert.deepEqual(merge(stored, layout, 'groups').group_order, ['Work', 'Home']);
  assert.deepEqual(merge(stored, { ...layout, group_order: ['Home'] }, 'groups').group_order, ['Work', 'Home']);
  assert.ok(!Object.hasOwn(merge(layout, { ...layout, group_order: ['Home'] }, 'groups'), 'group_order'));
  assert.deepEqual(merge(stored, { ...layout, group_order: ['Home', 'Work'] }, features).group_order, ['Home', 'Work']);
  assert.deepEqual(merge(stored, { ...layout, group_order: [] }, features).group_order, []);
});

test('IGSH-1890 the desktop captures, publishes, pulls and applies the sidebar group order', () => {
  const desktop = read('src/account_desktop.zig');
  const layoutZig = read('src/account_layout.zig');
  const client = read('src/account_client.zig');
  const sidebar = read('src/sidebar.zig');
  const session = read('src/session_layout.zig');
  const capture = desktop.slice(desktop.indexOf('pub fn captureSessionLayout('), desktop.indexOf('var g_account_hosts_cache'));
  assert.match(capture, /groupOrderFor\(a, tabs\.items\)/);
  assert.match(capture, /\.group_order = group_order/);
  assert.match(desktop.slice(desktop.indexOf('pub fn applyServerLayout(')), /if \(desired\.group_order\) \|names\| _ = @import\("sidebar\.zig"\)\.orderGroupsByName\(names\)/);
  assert.match(desktop, /if \(!app_state\.g_account_group_order_supported\) \{\s*plain_local = account_layout\.withoutGroupOrder\(plain_local\);\s*plain_base = account_layout\.withoutGroupOrder\(plain_base\);\s*plain_synced = account_layout\.withoutGroupOrder\(plain_synced\);/);
  assert.match(desktop, /if \(!remote\.group_order_supported\) rebased = account_layout\.withoutGroupOrder\(rebased\)/);
  assert.equal((desktop.match(/reply\.group_order_supported = remote\.group_order_supported/g) || []).length, 2);
  assert.match(desktop, /app_state\.g_account_group_order_supported = reply\.group_order_supported/);
  assert.match(client, /bot_palette8,groups,group_order/);
  assert.match(client, /group_order_supported = layoutSupports\(raw, "group_order"\)/);
  assert.match(session, /group_order: \?\[\]const \[\]const u8 = null/);
  assert.match(layoutZig, /\.group_order = remote\.group_order/);
  assert.match(layoutZig, /\.group_order = try rebaseGroupOrder\(a, base, edited, remote\)/);
  assert.match(layoutZig, /\.group_order = edited\.group_order/);
  assert.match(layoutZig, /if \(!sameNames\(a\.group_order orelse &\.\{\}, b\.group_order orelse &\.\{\}\)\) return false/);
  assert.match(sidebar, /pub fn orderGroupsByName\(/);
});
