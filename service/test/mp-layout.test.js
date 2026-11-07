import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';
import { run } from '../../tools/mp-layout.mjs';
import { run as mbRun } from '../../tools/mb.mjs';

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

test('spawn publishes once through the real service and refuses a workspace escape before setup', async t => {
  await reset();
  const home = mkdtempSync(join(tmpdir(), 'mp-layout-spawn-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  let marker, parked = false, runtimeCalls = 0;
  const errors = [];
  const opts = {
    env: { HOME: home, MULTIPROMPT_KEY: adminKey, MULTIPROMPT_URL: base },
    out() {}, err: line => errors.push(line),
    fetch: (url, init) => mf.dispatchFetch(url, init),
    resolveFolder: () => '/work',
    lock: async () => () => {},
    tmux: args => {
      if (args[0] === 'has-session') return { status: parked ? 0 : 1 };
      if (args[0] === 'display-message') return { status: 0, stdout: `sleep|/work|${marker}` };
      parked = true; marker = args.at(-1); return { status: 0 };
    },
    runtime: args => { runtimeCalls++; return { status: 0, stdout: JSON.stringify({ status: args[1] === 'enable' ? 'enabled' : 'started' }) }; }
  };
  const args = ['spawn', '--name', 'New live chat', '--folder', 'work', '--workspace', 'Work', '--group', 'Runners'];
  assert.equal(await run(args, { ...opts, env: { ...opts.env, MULTIPROMPT_KEY: innerKey } }), 1);
  assert.equal(runtimeCalls, 0);
  assert.equal(parked, false);
  for (let i = 0; i < 2; i++) assert.equal(await run([...args, '--mode', 'headless'], opts), 0, errors.join('\n'));
  assert.equal(parked, false);
  assert.equal((await stored()).revision, 3);
  for (let i = 0; i < 2; i++) assert.equal(await run(args, opts), 0, errors.join('\n'));
  const result = await stored();
  assert.equal(result.revision, 4);
  assert.equal(result.layout.tabs.length, seed().tabs.length + 1);
  const created = result.layout.tabs.at(-1);
  assert.equal(created.manual, true);
  assert.equal(created.name, 'New live chat');
  assert.equal(created.group, 'Runners');
  assert.match(created.tmux_session, /^live-[0-9a-f]{32}$/);
  const headers = { Authorization: 'Bearer ' + adminKey };
  const legacy = await mf.dispatchFetch(base + '/v1/layout', { headers });
  const snapshot = await legacy.json();
  assert.equal(snapshot.layout.tabs.at(-1).group, undefined);
  const write = await mf.dispatchFetch(base + '/v1/layout', { method: 'PUT', headers: { ...headers, 'Content-Type': 'application/json' }, body: JSON.stringify({ base_revision: snapshot.revision, layout: snapshot.layout }) });
  assert.equal(write.status, 200);
  assert.equal((await stored()).layout.tabs.at(-1).group, 'Runners');
});

test('open places shell runners in one group, stars one, and repeats as the same tabs', async () => {
  await reset();
  const open = name => ['open', '--kind', 'shell', '--tmux', name, '--name', name + ' shell', '--workspace', 'Work', '--group', 'MP Runners', '--host', '1', '--no-tmux'];
  for (const name of ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']) {
    const opened = await cli(open(name), adminKey);
    assert.equal(opened.code, 0, opened.errors.join('\n'));
  }
  const starred = await cli([...open('mp-runner-1'), '--star'], adminKey);
  assert.equal(starred.code, 0, starred.errors.join('\n'));
  const after = await stored();
  const runners = after.layout.tabs.filter(tab => tab.group === 'MP Runners');
  assert.deepEqual(runners.map(tab => tab.tmux_session), ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']);
  assert.equal(runners[0].favorite, true);
  const again = await cli([...open('mp-runner-1'), '--star'], adminKey);
  assert.match(again.lines[0], /already open/);
  assert.equal((await stored()).revision, after.revision);
  const other = await cli(['open', 'mp-runner-2', '--host', '1', '--workspace', 'inne', '--no-tmux'], adminKey);
  assert.equal(other.code, 1);
  assert.match(other.errors[0], /already open in Work/);
  const regrouped = await cli(['open', 'mp-runner-2', '--host', '1', '--workspace', 'Work', '--group', 'Lead runners', '--no-tmux'], adminKey);
  assert.equal(regrouped.code, 0, regrouped.errors.join('\n'));
  assert.equal((await stored()).layout.tabs.find(tab => tab.tmux_session === 'mp-runner-2').group, 'Lead runners');
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

test('roster apply sets group, face, color, photo, and workspace color once', async () => {
  await reset();
  await db.prepare('DELETE FROM bot_photos').run();
  const dir = mkdtempSync(join(tmpdir(), 'mb-service-'));
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==', 'base64');
  writeFileSync(join(dir, 'runner.png'), png);
  const file = join(dir, 'roster.json');
  writeFileSync(file, JSON.stringify({
    workspaces: [{ name: 'Multiprompt', color: 3 }],
    groups: ['MP Runners'],
    runners: [1, 2, 3].map(n => ({ name: 'mp-runner-' + n, kind: 'shell', title: 'Runner ' + n, workspace: 'Multiprompt', group: 'MP Runners', command: 'sleep infinity', model: 'cursor', host: 1, ...(n === 1 ? { face: 6, color: 7, photo: 'runner.png' } : {}) }))
  }));
  const sessions = new Set();
  const lines = [], errors = [];
  const invoke = args => mbRun(args, {
    env: { MULTIPROMPT_KEY: adminKey, MULTIPROMPT_URL: base, HOME: dir, MULTIPROMPT_HOST: '1' },
    out: line => lines.push(line), err: line => errors.push(line),
    fetch: (url, init) => mf.dispatchFetch(url, init),
    ownerPath: join(dir, 'owners.json'),
    tmux: argv => {
      const marked = argv.find(arg => String(arg).startsWith('='));
      const name = marked ? marked.slice(1) : argv[argv.indexOf('-s') + 1];
      if (argv[0] === 'has-session') return { status: sessions.has(name) ? 0 : 1, stdout: '' };
      if (argv[0] === 'new-session') { sessions.add(name); return { status: 0, stdout: '' }; }
      if (argv[0] === 'list-panes') return { status: 0, stdout: 'sleep\n' };
      return { status: 0, stdout: '' };
    }
  });
  const first = await invoke(['roster', 'apply', file]);
  assert.equal(first, 0, errors.join('\n'));
  const after = await stored();
  const runners = after.layout.tabs.filter(tab => tab.group === 'MP Runners');
  assert.deepEqual(runners.map(tab => tab.tmux_session), ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']);
  assert.equal(runners[0].face, 6);
  assert.equal(runners[0].color, 7);
  assert.equal(typeof runners[0].photo, 'number');
  assert.equal(after.layout.workspaces.find(workspace => workspace.name === 'Multiprompt').color, 3);
  lines.length = 0; errors.length = 0;
  const second = await invoke(['roster', 'apply', file]);
  assert.equal(second, 0, errors.join('\n'));
  assert.ok(lines.includes('unchanged mp-runner-1'));
  assert.equal((await stored()).revision, after.revision);
  lines.length = 0; errors.length = 0;
  const colored = await invoke(['workspace', 'color', 'Multiprompt', '1']);
  assert.equal(colored, 0, errors.join('\n'));
  assert.equal((await stored()).layout.workspaces.find(workspace => workspace.name === 'Multiprompt').color, 1);
  const coloredRevision = (await stored()).revision;
  const coloredAgain = await invoke(['workspace', 'color', 'Multiprompt', '1']);
  assert.equal(coloredAgain, 0, errors.join('\n'));
  assert.equal((await stored()).revision, coloredRevision);
  const styled = await invoke(['style', 'mp-runner-2', '--face', '1', '--color', '2', '--host', '1']);
  assert.equal(styled, 0, errors.join('\n'));
  assert.equal((await stored()).layout.tabs.find(tab => tab.tmux_session === 'mp-runner-2').face, 1);
  const styledRevision = (await stored()).revision;
  const styledAgain = await invoke(['style', 'mp-runner-2', '--face', '1', '--color', '2', '--host', '1']);
  assert.equal(styledAgain, 0, errors.join('\n'));
  assert.equal((await stored()).revision, styledRevision);
  rmSync(dir, { recursive: true, force: true });
});
