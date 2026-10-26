import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';
import { run } from '../../tools/mp-layout.mjs';

let mf, db;
const base = 'http://localhost';
const account = 'owner@example.com';
const adminKey = 'mpk_a_' + 'A'.repeat(43), innerKey = 'mpk_w_' + 'B'.repeat(43);
const tab = (name, workspace, host = 0) => ({ kind: 'tmux', name, tmux_session: name, tmux_host: host, workspace });
const seed = () => ({ schema: 1, revision: 3, workspaces: [{ name: 'inne' }, { name: 'Work' }], tabs: [tab('inne-a', 'inne'), tab('runner-1', 'Work', 1), tab('runner-2', 'Work', 1), tab('inne-b', 'inne'), tab('plain', 'Work')] });
const stored = async () => { const row = await db.prepare('SELECT revision,layout FROM layouts WHERE account=?').bind(account).first(); return { revision: row.revision, layout: JSON.parse(row.layout) }; };
const reset = async () => { await db.prepare('DELETE FROM layouts').run(); await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind(account, 3, JSON.stringify(seed())).run(); };

async function cli(args, key, extra = {}) {
  const lines = [], errors = [], tmuxCalls = [];
  const code = await run(args, {
    env: { MULTIPROMPT_KEY: key, MULTIPROMPT_URL: base },
    out: line => lines.push(line), err: line => errors.push(line),
    fetch: extra.fetch || ((url, init) => mf.dispatchFetch(url, init)),
    tmux: args => { tmuxCalls.push(args); return { status: args[0] === 'has-session' ? 1 : 0 }; }
  });
  return { code, lines, errors, tmuxCalls };
}

before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({ modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'], bindings: { ACCOUNT_EMAIL: account, ALLOWED_EMAILS: account, AUTH_ORIGINS: base, RP_ID: 'localhost' } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  for (const [key, kind, workspace] of [[adminKey, 'admin', null], [innerKey, 'workspace', 'inne']]) {
    await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,?)').bind(await hash(key), account, kind, workspace, 'test', 1).run();
  }
});
after(async () => { await mf.dispose(); });

test('list shows workspaces and sessions, and json is parseable', async () => {
  await reset();
  const text = await cli(['list'], adminKey);
  assert.equal(text.code, 0);
  assert.ok(text.lines.includes('inne (2)'));
  assert.ok(text.lines.includes('Work (3)'));
  const json = await cli(['list', '--json'], adminKey);
  assert.equal(JSON.parse(json.lines[0]).workspaces[1].sessions.length, 3);
});

test('admin key moves every runner session into a new section as one revision', async () => {
  await reset();
  const result = await cli(['move', '--to', 'Runners', '--create', '--match', 'runner-*'], adminKey);
  assert.equal(result.code, 0, result.errors.join('\n'));
  assert.match(result.lines[0], /moved 2 sessions to Runners \(revision 4\)/);
  const after = await stored();
  assert.equal(after.revision, 4);
  assert.deepEqual(after.layout.tabs.filter(t => t.workspace === 'Runners').map(t => t.tmux_session), ['runner-1', 'runner-2']);
  assert.deepEqual(after.layout.workspaces.map(w => w.name), ['inne', 'Work', 'Runners']);
});

test('create-section adds a workspace once', async () => {
  await reset();
  assert.match((await cli(['create-section', 'Runners'], adminKey)).lines[0], /created section Runners \(revision 4\)/);
  assert.match((await cli(['create-section', 'Runners'], adminKey)).lines[0], /already exists/);
  assert.equal((await stored()).revision, 4);
});

test('move by name reports missing sessions and writes nothing', async () => {
  await reset();
  const result = await cli(['move', '--to', 'Work', 'plain', 'ghost'], adminKey);
  assert.equal(result.code, 1);
  assert.match(result.errors[0], /no such session: ghost/);
  assert.equal((await stored()).revision, 3);
});

test('workspace key lists only its workspace and moves sessions inside it', async () => {
  await reset();
  const listing = await cli(['list'], innerKey);
  assert.deepEqual(listing.lines.filter(l => !l.startsWith(' ')), ['revision 3', 'inne (2)']);
  const moved = await cli(['move', '--to', 'inne', 'inne-a'], innerKey);
  assert.equal(moved.code, 0, moved.errors.join('\n'));
  assert.deepEqual((await stored()).layout.tabs.filter(t => t.workspace === 'inne').map(t => t.tmux_session), ['inne-b', 'inne-a']);
});

test('workspace key gets a clear refusal for another workspace', async () => {
  await reset();
  const other = await cli(['move', '--to', 'Work', 'inne-a'], innerKey);
  assert.equal(other.code, 1);
  assert.match(other.errors[0], /not found or not visible to this key/);
  const created = await cli(['move', '--to', 'Fresh', '--create', 'inne-a'], innerKey);
  assert.equal(created.code, 1);
  assert.equal(created.errors[0], 'mp-layout: refused: this key may change only its own workspace');
  const steal = await cli(['open', 'runner-1', '--host', '1'], innerKey);
  assert.equal(steal.code, 1);
  assert.equal(steal.errors[0], 'mp-layout: refused: this key may change only its own workspace');
  assert.deepEqual(await stored(), { revision: 3, layout: seed() });
});

test('open starts tmux when missing and registers the session in the default workspace', async () => {
  await reset();
  const result = await cli(['open', 'fresh-one', '--title', 'Fresh one'], innerKey);
  assert.equal(result.code, 0, result.errors.join('\n'));
  assert.deepEqual(result.tmuxCalls.map(c => c[0]), ['has-session', 'new-session']);
  assert.match(result.lines[0], /opened fresh-one \(tmux session started\) \(revision 4\)/);
  const added = (await stored()).layout.tabs.find(t => t.tmux_session === 'fresh-one');
  assert.deepEqual(added, { kind: 'tmux', name: 'Fresh one', tmux_session: 'fresh-one', tmux_host: 0, workspace: 'inne' });
  const again = await cli(['open', 'fresh-one', '--no-tmux'], innerKey);
  assert.match(again.lines[0], /already open/);
  assert.equal((await stored()).revision, 4);
});

test('admin open needs a workspace when there are several', async () => {
  await reset();
  const result = await cli(['open', 'fresh-two', '--no-tmux'], adminKey);
  assert.equal(result.code, 1);
  assert.match(result.errors[0], /--workspace/);
  const named = await cli(['open', 'fresh-two', '--workspace', 'Work', '--host', '2', '--no-tmux'], adminKey);
  assert.equal(named.code, 0);
  assert.equal((await stored()).layout.tabs.at(-1).tmux_host, 2);
});

test('a concurrent change between read and write is retried onto the winner', async () => {
  await reset();
  let injected = false;
  const racing = async (url, init) => {
    if (init?.method === 'PUT' && !injected) {
      injected = true;
      const row = await stored();
      row.layout.workspaces.push({ name: 'Concurrent' });
      await db.prepare('UPDATE layouts SET revision=revision+1,layout=?').bind(JSON.stringify(row.layout)).run();
    }
    return mf.dispatchFetch(url, init);
  };
  const result = await cli(['move', '--to', 'Runners', '--create', '--match', 'runner-*'], adminKey, { fetch: racing });
  assert.equal(result.code, 0, result.errors.join('\n'));
  const after = await stored();
  assert.equal(after.revision, 5);
  assert.deepEqual(after.layout.workspaces.map(w => w.name), ['inne', 'Work', 'Concurrent', 'Runners']);
  assert.equal(after.layout.tabs.filter(t => t.workspace === 'Runners').length, 2);
});

test('the key never appears in output and a missing key is reported', async () => {
  await reset();
  const result = await cli(['move', '--to', 'Work', 'ghost'], adminKey);
  assert.ok(![...result.lines, ...result.errors].some(l => l.includes(adminKey)));
  const unknown = await cli(['list'], 'mpk_a_' + 'Q'.repeat(43));
  assert.equal(unknown.errors[0], 'mp-layout: the key was not accepted');
  const none = await run(['list'], { env: {}, out() {}, err: () => {} });
  assert.equal(none, 1);
});
