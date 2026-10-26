import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';

let mf, db;
const base = 'http://localhost';
const account = 'owner@example.com';
const adminKey = 'mpk_a_' + 'A'.repeat(43), innerKey = 'mpk_w_' + 'B'.repeat(43), otherKey = 'mpk_w_' + 'C'.repeat(43), revokedKey = 'mpk_a_' + 'D'.repeat(43), skewedKey = 'mpk_a_' + 'E'.repeat(43);
const tab = (name, workspace, host = 0, extra = {}) => ({ kind: 'tmux', name, tmux_session: name, tmux_host: host, workspace, ...extra });
const seed = () => ({
  schema: 1, revision: 7, workspaces: [{ name: 'inne' }, { name: 'Work' }],
  settings: { frequent: true },
  hosts: [{ slot: 1, name: 'Host 2', hostname: 'example.test', port: 22, user: 'tester' }],
  tabs: [tab('inne-a', 'inne', 0, { favorite: true, visits: [10, 20] }), tab('work-a', 'Work'), tab('runner-1', 'Work', 1), tab('inne-b', 'inne'), tab('runner-2', 'Work', 1)]
});
const call = (path, key, options = {}) => mf.dispatchFetch(base + path, { ...options, headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json', ...options.headers } });
const get = async key => { const r = await call('/v1/layout', key); return { status: r.status, body: await r.json() }; };
const put = async (key, baseRevision, layout, headers) => {
  const r = await call('/v1/layout', key, { method: 'PUT', body: JSON.stringify({ base_revision: baseRevision, layout }), headers });
  return { status: r.status, body: await r.json() };
};
const stored = async () => { const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(account).first(); return { revision: row.revision, layout: JSON.parse(row.layout) }; };
const addKey = async (key, kind, workspace, revoked = 0) => db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created,revoked) VALUES (?,?,?,?,?,?,?)').bind(await hash(key), account, kind, workspace, 'test', 1, revoked).run();

before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({ modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'], bindings: { ACCOUNT_EMAIL: account, ALLOWED_EMAILS: account, AUTH_ORIGINS: base, RP_ID: 'localhost' } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  await addKey(adminKey, 'admin', null);
  await addKey(innerKey, 'workspace', 'inne');
  await addKey(otherKey, 'workspace', 'Missing');
  await addKey(revokedKey, 'admin', null, 1);
  await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,?)').bind(await hash(skewedKey), account, 'workspace', 'inne', 'skewed', 1).run();
});
after(async () => { await mf.dispose(); });
const reset = async () => { await db.prepare('DELETE FROM layouts').run(); await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind(account, 7, JSON.stringify(seed())).run(); };

test('unknown, revoked and kind-mismatched keys are refused', async () => {
  await reset();
  assert.equal((await get('mpk_a_' + 'Z'.repeat(43))).status, 401);
  assert.equal((await get(revokedKey)).status, 401);
  assert.equal((await get(skewedKey)).status, 401);
  assert.equal((await get('mpk_x_' + 'A'.repeat(43))).status, 401);
});

test('a key works only on the layout route', async () => {
  const r = await call('/v1/devices', adminKey);
  assert.equal(r.status, 403);
  assert.equal((await r.json()).error, 'key_scope');
  assert.equal((await call('/v1/me', innerKey)).status, 403);
});

test('admin key reads the whole layout', async () => {
  await reset();
  const { status, body } = await get(adminKey);
  assert.equal(status, 200);
  assert.equal(body.revision, 7);
  assert.deepEqual(body.layout.workspaces.map(w => w.name), ['inne', 'Work']);
  assert.equal(body.layout.tabs.length, 5);
});

test('admin key moves several sessions into a new section in one revision', async () => {
  await reset();
  const { body } = await get(adminKey);
  const layout = structuredClone(body.layout);
  layout.workspaces.push({ name: 'Runners' });
  for (const t of layout.tabs) if (t.tmux_session.startsWith('runner-')) t.workspace = 'Runners';
  const result = await put(adminKey, body.revision, layout);
  assert.equal(result.status, 200);
  assert.equal(result.body.revision, 8);
  const after = await stored();
  assert.equal(after.revision, 8);
  assert.deepEqual(after.layout.workspaces.map(w => w.name), ['inne', 'Work', 'Runners']);
  assert.deepEqual(after.layout.tabs.filter(t => t.workspace === 'Runners').map(t => t.tmux_session), ['runner-1', 'runner-2']);
  assert.deepEqual(after.layout.settings, { frequent: true });
  assert.equal(after.layout.hosts.length, 1);
  assert.equal(after.layout.tabs[0].favorite, true);
  assert.deepEqual(after.layout.tabs[0].visits, [10, 20]);
});

test('a stale admin write returns the winner and writes nothing', async () => {
  await reset();
  const { body } = await get(adminKey);
  const first = structuredClone(body.layout); first.workspaces.push({ name: 'First' });
  assert.equal((await put(adminKey, body.revision, first)).status, 200);
  const late = structuredClone(body.layout); late.workspaces.push({ name: 'Late' });
  const result = await put(adminKey, body.revision, late);
  assert.equal(result.status, 409);
  assert.equal(result.body.revision, 8);
  assert.ok(result.body.layout.workspaces.some(w => w.name === 'First'));
  assert.ok(!(await stored()).layout.workspaces.some(w => w.name === 'Late'));
});

test('workspace key sees only its own workspace', async () => {
  await reset();
  const { status, body } = await get(innerKey);
  assert.equal(status, 200);
  assert.deepEqual(body.layout.workspaces, [{ name: 'inne' }]);
  assert.deepEqual(body.layout.tabs.map(t => t.tmux_session), ['inne-a', 'inne-b']);
  assert.equal(body.layout.settings, undefined);
  assert.equal(body.layout.hosts, undefined);
  assert.equal((await get(otherKey)).status, 404);
});

test('workspace key reorders and opens sessions inside its own workspace', async () => {
  await reset();
  const { body } = await get(innerKey);
  const layout = structuredClone(body.layout);
  layout.tabs = [layout.tabs[1], layout.tabs[0], tab('inne-new', 'inne')];
  const result = await put(innerKey, body.revision, layout);
  assert.equal(result.status, 200);
  assert.equal(result.body.revision, 8);
  assert.deepEqual(result.body.layout.tabs.map(t => t.tmux_session), ['inne-b', 'inne-a', 'inne-new']);
  const after = await stored();
  assert.deepEqual(after.layout.workspaces.map(w => w.name), ['inne', 'Work']);
  assert.deepEqual(after.layout.tabs.filter(t => t.workspace === 'Work').map(t => t.tmux_session), ['work-a', 'runner-1', 'runner-2']);
  assert.deepEqual(after.layout.tabs.filter(t => t.workspace === 'inne').map(t => t.tmux_session), ['inne-b', 'inne-a', 'inne-new']);
  assert.equal(after.layout.tabs.find(t => t.tmux_session === 'inne-a').favorite, true);
  assert.deepEqual(after.layout.settings, { frequent: true });
  assert.equal(after.layout.hosts.length, 1);
});

test('workspace key is refused outside its workspace and nothing is written', async () => {
  await reset();
  const { body } = await get(innerKey);
  const refused = async layout => {
    const result = await put(innerKey, body.revision, layout);
    assert.equal(result.status, 403);
    assert.equal(result.body.error, 'scope_denied');
    assert.deepEqual(await stored(), { revision: 7, layout: seed() });
  };
  const addsWorkspace = structuredClone(body.layout); addsWorkspace.workspaces.push({ name: 'Extra' });
  await refused(addsWorkspace);
  const otherWorkspace = structuredClone(body.layout); otherWorkspace.workspaces = [{ name: 'inne' }, { name: 'Work' }]; otherWorkspace.tabs[0].workspace = 'Work';
  await refused(otherWorkspace);
  const renamed = structuredClone(body.layout); renamed.workspaces = [{ name: 'Renamed' }]; renamed.tabs.forEach(t => { t.workspace = 'Renamed'; });
  await refused(renamed);
  const steals = structuredClone(body.layout); steals.tabs.push(tab('runner-1', 'inne', 1));
  await refused(steals);
});

test('workspace key cannot change settings or hosts even when it declares them', async () => {
  await reset();
  const { body } = await get(innerKey);
  const layout = structuredClone(body.layout);
  layout.settings = { frequent: false };
  layout.hosts = [];
  layout.removed_hosts = [1];
  const result = await put(innerKey, body.revision, layout, { 'X-Layout-Features': 'settings,hosts,host_removal,favorite' });
  assert.equal(result.status, 200);
  const after = await stored();
  assert.deepEqual(after.layout.settings, { frequent: true });
  assert.equal(after.layout.hosts.length, 1);
  assert.equal(after.layout.removed_hosts, undefined);
});

test('a revoked workspace key cannot write', async () => {
  await reset();
  const key = 'mpk_w_' + 'F'.repeat(43);
  await addKey(key, 'workspace', 'inne');
  const { body } = await get(key);
  await db.prepare('UPDATE service_keys SET revoked=1 WHERE hash=?').bind(await hash(key)).run();
  assert.equal((await put(key, body.revision, body.layout)).status, 401);
});

test('two simultaneous key writes admit exactly one', async () => {
  await reset();
  const { body } = await get(adminKey);
  const a = structuredClone(body.layout); a.workspaces.push({ name: 'A' });
  const b = structuredClone(body.layout); b.workspaces.push({ name: 'B' });
  const results = await Promise.all([put(adminKey, body.revision, a), put(adminKey, body.revision, b)]);
  assert.deepEqual(results.map(r => r.status).sort(), [200, 409]);
});
