import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, rmSync, writeFileSync, mkdirSync, chmodSync, symlinkSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { hash } from '../worker.js';
import { run } from '../../tools/mp-layout.mjs';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

let mf, db, home, opts, layoutFetch, runtimeCalls, messages, keyReads;
const account = 'sessions@example.com';
const key = 'mpk_a_' + 'S'.repeat(43);
const base = 'http://localhost';
const stored = async () => JSON.parse((await db.prepare('SELECT layout FROM layouts WHERE account=?').bind(account).first()).layout);
const save = async layout => { await db.prepare('UPDATE layouts SET layout=? WHERE account=?').bind(JSON.stringify(layout), account).run(); };
const args = ['new', '--name', 'Daily chat', '--folder', 'work'];

async function cli(argv, extra = {}) {
  const out = [], err = [];
  const code = await run(['session', ...argv], { ...opts, ...extra, out: line => out.push(line), err: line => err.push(line) });
  return { code, out: out.join('\n'), err: err.join('\n') };
}

before(async () => {
  mf = new Miniflare(convertV4MiniflareOptions({ modules: true, scriptPath: new URL('../.build/worker.js', import.meta.url).pathname, compatibilityDate: '2026-10-09', compatibilityFlags: ['nodejs_compat'], d1Databases: ['DB'], bindings: { ACCOUNT_EMAIL: account, ALLOWED_EMAILS: account, AUTH_ORIGINS: base, RP_ID: 'localhost' } }));
  db = await mf.getD1Database('DB');
  for (const sql of readFileSync(new URL('../schema.sql', import.meta.url), 'utf8').split(';').filter(s => s.trim())) await db.prepare(sql).run();
  await db.prepare('INSERT INTO service_keys (hash,account,kind,workspace,label,created) VALUES (?,?,?,?,?,?)').bind(await hash(key), account, 'admin', null, 'disposable session test', 1).run();
  layoutFetch = (url, init) => mf.dispatchFetch(url, init);
});
after(async () => { if (home) rmSync(home, { recursive: true, force: true }); await mf.dispose(); });
beforeEach(async () => {
  if (home) rmSync(home, { recursive: true, force: true });
  home = mkdtempSync(join(tmpdir(), 'mp-session-'));
  await db.prepare('DELETE FROM layouts WHERE account=?').bind(account).run();
  await db.prepare('INSERT INTO layouts VALUES (?,?,?)').bind(account, 0, JSON.stringify({ schema: 1, revision: 0, workspaces: [{ name: 'Disposable' }, { name: 'Other' }], tabs: [] })).run();
  runtimeCalls = []; messages = new Map(); keyReads = 0;
  opts = {
    env: { HOME: home, MULTIPROMPT_URL: base },
    loadKey: () => { keyReads++; return key; },
    fetch: layoutFetch,
    resolveFolder: () => '/work',
    tmux: () => ({ status: 1 }),
    lock: async () => () => {},
    wait: async () => {},
    runtime: (argv, input) => {
      runtimeCalls.push(argv);
      if (argv[0] === 'host') {
        if (argv[1] === 'enable') {
          const stateKey = createHash('sha256').update(argv[2] + ':' + argv[3]).digest('hex').slice(0, 32);
          const file = join(home, '.local/state/multiprompt/agent-host', stateKey + '.config.json');
          writeFileSync(file, JSON.stringify({ ...JSON.parse(readFileSync(file, 'utf8')), enabled: true }));
        }
        return { status: 0, stdout: JSON.stringify({ status: argv[1] === 'enable' ? 'enabled' : 'started' }) };
      }
      const [submit, dispatch] = input.trim().split('\n').map(JSON.parse);
      assert.ok(!messages.has(submit.message_id) || messages.get(submit.message_id) === submit.text, 'message id conflict');
      messages.set(submit.message_id, submit.text);
      return { status: 0, stdout: JSON.stringify({ id: submit.id, result: { message: { id: submit.message_id, text: submit.text, state: 'queued' } } }) + '\n' + JSON.stringify({ id: dispatch.id, result: {} }) };
    }
  };
});

test('new defaults to one visible top-level chat and restarts that same name', async () => {
  const first = await cli(args);
  assert.equal(first.code, 0, first.err);
  const created = JSON.parse(first.out);
  assert.equal(created.workspace, 'Disposable');
  assert.equal(created.visible, true);
  const again = await cli(['new', '--name', ' DAILY CHAT ', '--folder', 'work']);
  assert.equal(again.code, 0, again.err);
  assert.equal(JSON.parse(again.out).sid, created.sid);
  assert.equal((await stored()).tabs.length, 1);
  assert.equal((await stored()).tabs[0].group, undefined);
  assert.equal(runtimeCalls.filter(call => call[1] === 'start').length, 2);
  assert.equal(keyReads, 2);
});

test('list reads session names, groups and stars from the real layout API', async () => {
  assert.equal((await cli([...args, '--group', 'Daily'])).code, 0);
  assert.equal((await cli(['star', 'Daily chat'])).code, 0);
  const listed = await cli(['list', '--json']);
  assert.equal(listed.code, 0, listed.err);
  const session = JSON.parse(listed.out).workspaces[0].sessions[0];
  assert.equal(session.name, 'Daily chat');
  assert.equal(session.group, 'Daily');
  assert.equal(session.starred, true);
});

test('star uses favorite, preserves groups and repeats without a write', async () => {
  await cli([...args, '--group', 'Daily']);
  const first = await cli(['star', 'Daily chat']);
  assert.equal(first.code, 0, first.err);
  const layout = await stored();
  assert.equal(layout.tabs[0].favorite, true);
  assert.equal(layout.tabs[0].group, 'Daily');
  assert.equal((await cli(['star', 'Daily chat'])).code, 0);
  assert.deepEqual(await stored(), layout);
});

test('unstar clears favorite and repeats without a write', async () => {
  await cli(args); await cli(['star', 'Daily chat']);
  const result = await cli(['unstar', 'Daily chat']);
  assert.equal(result.code, 0, result.err);
  const layout = await stored();
  assert.equal(layout.tabs[0].favorite, false);
  assert.equal((await cli(['unstar', 'Daily chat'])).code, 0);
  assert.deepEqual(await stored(), layout);
});

test('move changes workspace and group; new still returns the existing chat', async () => {
  const opened = await cli(args);
  assert.equal(opened.code, 0, opened.err);
  const first = JSON.parse(opened.out);
  const result = await cli(['move', 'Daily chat', '--workspace', 'Other', '--group', 'Follow-ups']);
  assert.equal(result.code, 0, result.err);
  const moved = await stored();
  assert.equal(moved.tabs[0].workspace, 'Other');
  assert.equal(moved.tabs[0].group, 'Follow-ups');
  assert.equal((await cli(['move', first.session, '--workspace', 'Other', '--group', 'Follow-ups'])).code, 0);
  assert.deepEqual(await stored(), moved);
  const again = await cli(args);
  assert.equal(again.code, 0, again.err);
  assert.equal(JSON.parse(again.out).session, first.session);
  assert.equal(JSON.parse(again.out).workspace, 'Other');
  assert.equal((await cli(['move', 'Daily chat', '--workspace', 'Disposable'])).code, 0);
  assert.equal((await stored()).tabs[0].group, undefined);
});

test('task stdin stays off argv; repeats deduplicate, different text has its own id', async () => {
  const launch = text => cli([...args, '--task', '-'], { readTask: () => text });
  for (const text of ['first task', 'first task', 'second task']) {
    const result = await launch(text);
    assert.equal(result.code, 0, result.err);
  }
  assert.deepEqual([...messages.values()], ['first task', 'second task']);
  assert.doesNotMatch(JSON.stringify(runtimeCalls), /first task|second task|mpk_a_/);
});

test('publication readback is required, including on a repeated new', async () => {
  const first = await cli(args);
  assert.equal(first.code, 0, first.err);
  const lying = async (url, init) => {
    const response = await layoutFetch(url, init);
    if (init.method !== 'GET') return response;
    const data = await response.json(); data.layout.tabs = [];
    return new Response(JSON.stringify(data), { status: 200, headers: response.headers });
  };
  const result = await cli(args, { fetch: lying });
  assert.equal(result.code, 1);
  assert.match(result.err, /not visible/);
  assert.equal(result.out, '');
});

test('helper is explicit and placed immediately after the calling tab', async () => {
  const opened = await cli(args);
  assert.equal(opened.code, 0, opened.err);
  const parent = JSON.parse(opened.out);
  const result = await cli(['new', '--name', 'Helper', '--folder', 'work', '--helper'], { env: { ...opts.env, MULTIPROMPT_TAB: parent.session } });
  assert.equal(result.code, 0, result.err);
  const tabs = (await stored()).tabs;
  assert.equal(tabs[0].tmux_session, parent.session);
  assert.equal(tabs[1].name, 'Helper');
  assert.equal(tabs[1].workspace, tabs[0].workspace);
});

test('key lookup errors and service bodies cannot leak secrets', async () => {
  const lookup = await cli(['list'], { loadKey: () => { throw new Error(key); } });
  assert.equal(lookup.code, 1); assert.doesNotMatch(lookup.err, /mpk_a_/);
  const refused = await cli(['star', 'Daily chat'], { fetch: async () => new Response(JSON.stringify({ error: key }), { status: 403 }) });
  assert.equal(refused.code, 1); assert.doesNotMatch(refused.err, /mpk_a_/);
  assert.equal((await cli(['star', 'missing'])).code, 1);
  assert.equal((await cli(['move', 'missing', '--workspace', 'Other'])).code, 1);
});

test('bad options and help do not look up the key', async () => {
  for (const argv of [['--help'], ['new', '--bad'], ['new', '--name', 'X', '--name', 'Y'], ['star'], ['list', '--task', 'secret']]) await cli(argv);
  assert.equal(keyReads, 0);
});

test('new reuses a previously named stopped host instead of creating a second identity', async () => {
  const sid = '3ef1687a-d9f1-4840-8c57-cfd828c7c743';
  const session = 'live-native-existing';
  const root = join(home, '.local/state/multiprompt/agent-host');
  mkdirSync(root, { recursive: true, mode: 0o700 });
  const stateKey = createHash('sha256').update('hax:' + sid).digest('hex').slice(0, 32);
  writeFileSync(join(root, stateKey + '.config.json'), JSON.stringify({ enabled: true, provider: 'hax', sid, tmux: session, cwd: '/work' }), { mode: 0o600 });
  const layout = await stored();
  layout.tabs.push({ kind: 'tmux', name: 'Daily chat', tmux_session: session, tmux_host: 0, workspace: 'Other' });
  await save(layout);
  const runtime = opts.runtime;
  const native = (argv, input) => argv[0] === 'host' && argv[1] === 'list'
    ? { status: 0, stdout: JSON.stringify({ chats: [{ name: session, provider: 'hax', sid }] }) }
    : runtime(argv, input);
  const result = await cli([...args, '--task', 'resume work'], { runtime: native });
  assert.equal(result.code, 0, result.err);
  assert.equal(JSON.parse(result.out).sid, sid);
  assert.equal(JSON.parse(result.out).workspace, 'Other');
  assert.deepEqual(runtimeCalls.find(call => call[1] === 'start'), ['host', 'start', 'hax', sid]);
  assert.equal(runtimeCalls.filter(call => call[1] === 'enable').length, 0);
  assert.equal((await stored()).tabs.length, 1);
  assert.equal((await cli([...args, '--provider', 'claude'], { runtime: native })).code, 1);
});

test('concurrent writes retain unrelated sessions and retry the real revision conflict', async () => {
  await cli(args);
  let raced = false;
  const racing = async (url, init) => {
    if (init.method === 'PUT' && !raced) {
      raced = true;
      const body = JSON.parse(init.body);
      body.layout.tabs.push({ kind: 'tmux', name: 'Unrelated', tmux_session: 'unrelated', tmux_host: 1, workspace: 'Other' });
      const winner = await layoutFetch(url, { ...init, body: JSON.stringify(body) });
      assert.equal(winner.status, 200);
    }
    return layoutFetch(url, init);
  };
  const result = await cli(['star', 'Daily chat'], { fetch: racing });
  assert.equal(result.code, 0, result.err);
  assert.equal((await stored()).tabs.length, 2);
  assert.ok((await stored()).tabs.find(tab => tab.tmux_session === 'unrelated'));
});

test('unsupported Starred fails before mutation instead of silently succeeding', async () => {
  await cli(args);
  const before = await stored();
  const unsupported = async (url, init) => {
    const response = await layoutFetch(url, init);
    const headers = new Headers(response.headers); headers.set('X-Layout-Features', 'groups');
    return new Response(await response.text(), { status: response.status, headers });
  };
  const result = await cli(['star', 'Daily chat'], { fetch: unsupported });
  assert.equal(result.code, 1);
  assert.match(result.err, /does not support Starred/);
  assert.deepEqual(await stored(), before);
});

test('installed symlink loads the key once per verb without forwarding it to the real reader', { skip: process.platform === 'win32' }, async () => {
  const item = 'Multiprompt Layout Admin Key Mini Boss CEO';
  const keyLog = join(home, 'key-calls');
  const yeoKey = join(home, 'yeo-key');
  writeFileSync(yeoKey, [
    '#!/usr/bin/python3',
    'import os,sys',
    'assert "MULTIPROMPT_KEY" not in os.environ',
    `assert sys.argv[1:] == ${JSON.stringify([item, 'MULTIPROMPT_KEY'])}`,
    `with open(${JSON.stringify(keyLog)}, 'a') as log: log.write('read\\n')`,
    `print(${JSON.stringify(key)})`
  ].join('\n'));
  chmodSync(yeoKey, 0o700);
  const mp = join(home, 'mp');
  symlinkSync(new URL('../../tools/mp-layout.mjs', import.meta.url).pathname, mp);
  assert.notEqual(statSync(mp).mode & 0o111, 0, 'the installed mp command must be executable');
  const reader = join(home, 'reader.py');
  writeFileSync(reader, [
    'import os,json,runpy,sys',
    'assert "MULTIPROMPT_KEY" not in os.environ',
    'assert "CALLER_SECRET" not in os.environ',
    `reader = runpy.run_path(${JSON.stringify(new URL('../../src/chat_history_reader.py', import.meta.url).pathname)})`,
    'if sys.argv[1:3] == ["host", "start"]:',
    '    print(json.dumps(dict(status="started")))',
    'elif sys.argv[1] == "host":',
    '    print(json.dumps(reader["host_cli"](sys.argv[2:])))',
    'else:',
    '    assert sys.argv[1:] == ["--serve"]',
    '    for line in sys.stdin:',
    '        q = json.loads(line)',
    '        result = reader["message_store_request"](q) if q["op"] == "message_submit" else dict(message=None)',
    '        print(json.dumps(dict(id=q["id"], result=result)))'
  ].join('\n'));
  const transport = join(home, 'transport.mjs');
  writeFileSync(transport, `const fetch = globalThis.fetch; globalThis.fetch = (url, init) => fetch(new URL(new URL(url).pathname, ${JSON.stringify(String(await mf.ready))}), init);`);
  const env = { HOME: home, PATH: home + ':' + process.env.PATH, NODE_OPTIONS: '--import=' + transport, MULTIPROMPT_READER: reader, CALLER_SECRET: 'must-not-reach-reader' };
  const invoke = async argv => {
    const { stdout, stderr } = await promisify(execFile)(mp, ['session', ...argv], { env, timeout: 30000 });
    assert.equal(stderr, ''); assert.ok(!stdout.includes(key));
    return JSON.parse(stdout);
  };
  const help = await promisify(execFile)(mp, ['--help'], { env });
  assert.match(help.stdout, /^usage: mp session/);
  assert.doesNotMatch(help.stdout, /set MULTIPROMPT_KEY/);
  const create = ['new', '--name', 'Installed chat', '--folder', home, '--task', 'one task'];
  const first = await invoke(create);
  const again = await invoke(create);
  assert.equal(first.sid, again.sid);
  assert.equal((await invoke(['star', 'Installed chat'])).starred, true);
  assert.equal((await invoke(['unstar', 'Installed chat'])).starred, false);
  assert.equal((await invoke(['move', 'Installed chat', '--workspace', 'Other'])).workspace, 'Other');
  assert.equal((await invoke(['list', '--json'])).workspaces[1].sessions.length, 1);
  assert.equal(readFileSync(keyLog, 'utf8').trim().split('\n').length, 6);
});

test('the shared command cannot redirect the approved key using MULTIPROMPT_URL', async () => {
  const result = await cli(['list'], {
    env: { ...opts.env, MULTIPROMPT_URL: 'https://do-not-send.example' },
    fetch: (url, init) => { assert.equal(url, 'https://account.multiprompt.dev/v1/layout'); return layoutFetch(url, init); }
  });
  assert.equal(result.code, 0, result.err);
});
