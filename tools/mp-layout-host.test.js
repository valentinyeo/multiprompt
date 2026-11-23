const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const HOSTS = path.join('.local/state/multiprompt/agent-host');
const SERVERS = path.join('.local/share/vstack/servers.json');

async function fixture() {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-host-'));
  let layout = { workspaces: [{ name: 'Multiprompt' }], tabs: [] };
  let revision = 1;
  const puts = [];
  const fetch = async (url, request) => {
    const headers = { get: () => 'groups' };
    if (request.method === 'GET') return { status: 200, headers, json: async () => ({ layout: structuredClone(layout), revision }) };
    const body = JSON.parse(request.body);
    puts.push(body);
    layout = body.layout;
    revision += 1;
    return { status: 200, headers, json: async () => ({ revision }) };
  };
  const call = async args => {
    const out = [], err = [];
    const code = await run(args, { env: { MULTIPROMPT_KEY: 'k', HOME: home }, fetch, out: line => out.push(line), err: line => err.push(line), tmux: () => ({ status: 0 }) });
    return { code, out: out.join('\n'), err: err.join('\n') };
  };
  return { home, call, puts, get layout() { return layout; } };
}

function record(home, tmux, host) {
  const dir = path.join(home, HOSTS);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'record-' + tmux + '.config.json'), JSON.stringify({ enabled: true, tmux, spawn_host: host }));
}

function servers(home, value) {
  fs.mkdirSync(path.dirname(path.join(home, SERVERS)), { recursive: true });
  fs.writeFileSync(path.join(home, SERVERS), JSON.stringify(value));
}

test('SOFT-3139 a chat recorded on host 1 reopens on host 1 when no --host is given', async () => {
  const box = await fixture();
  record(box.home, 'live-incident', 1);
  const reopened = await box.call(['open', 'live-incident', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(reopened.code, 0, reopened.err);
  assert.deepEqual(box.layout.tabs.map(tab => [tab.tmux_session, tab.tmux_host]), [['live-incident', 1]]);
});

test('SOFT-3139 a --host that contradicts the recorded host is refused and writes nothing', async () => {
  const box = await fixture();
  record(box.home, 'live-incident', 1);
  const refused = await box.call(['open', 'live-incident', '--workspace', 'Multiprompt', '--host', '0', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: --host 0 contradicts the host 1 recorded for live-incident');
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 a --host that matches the record opens the tab once', async () => {
  const box = await fixture();
  record(box.home, 'live-incident', 1);
  const opened = await box.call(['open', 'live-incident', '--workspace', 'Multiprompt', '--host', '1', '--no-tmux']);
  assert.equal(opened.code, 0, opened.err);
  assert.deepEqual(box.layout.tabs.map(tab => [tab.tmux_session, tab.tmux_host]), [['live-incident', 1]]);
  const count = box.layout.tabs.length;
  const again = await box.call(['open', 'live-incident', '--workspace', 'Multiprompt', '--host', '1', '--no-tmux']);
  assert.equal(again.code, 0, again.err);
  assert.match(again.out, /already open/);
  assert.equal(box.layout.tabs.length, count);
});

test('SOFT-3139 a tab with no record and no --host is refused instead of landing on host 0', async () => {
  const box = await fixture();
  const refused = await box.call(['open', 'live-new', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: give --host: live-new has no recorded host');
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 the installed servers file names the host for a chat with no record', async () => {
  const box = await fixture();
  servers(box.home, {
    schema: 1,
    servers: [{ name: 'alpha', slot: 1, users: ['red'] }, { name: 'beta', slot: 0, users: ['red', 'blue'] }],
    chats: [{ session: 'live-alpha', server: 'alpha', user: 'red' }, { session: 'live-far', server: 'alpha', user: 'blue' }]
  });
  const opened = await box.call(['open', 'live-alpha', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(opened.code, 0, opened.err);
  assert.equal(box.layout.tabs[0].tmux_host, 1);
  const wrongUser = await box.call(['open', 'live-far', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(wrongUser.code, 1);
  assert.equal(wrongUser.err, 'mp-layout: give --host: live-far has no recorded host');
});

test('SOFT-3139 spawn refuses without --host and records the host it is given', async () => {
  const box = await fixture();
  const refused = await box.call(['spawn', '--name', 'New chat', '--folder', 'work', '--workspace', 'Multiprompt']);
  assert.equal(refused.code, 1);
  assert.deepEqual(JSON.parse(refused.err), { ok: false, error: 'give --host: a new chat must name the server it runs on' });
  const { run } = await import('./mp-layout.mjs');
  const lines = [];
  const code = await run(['spawn', '--name', 'New chat', '--folder', 'work', '--workspace', 'Multiprompt', '--host', '1'], {
    env: { MULTIPROMPT_KEY: 'k', HOME: box.home },
    resolveFolder: () => '/work',
    fetch: async (url, request) => {
      if (request.method === 'GET') return { status: 200, headers: { get: () => 'groups' }, json: async () => ({ layout: { workspaces: [{ name: 'Multiprompt' }], tabs: [] }, revision: 1 }) };
      return { status: 200, headers: { get: () => 'groups' }, json: async () => ({ revision: 2 }) };
    },
    out: line => lines.push(line),
    err: line => lines.push(line),
    lock: async () => () => {},
    tmux: args => ({ status: args[0] === 'has-session' ? 1 : 0 }),
    runtime: args => ({ status: 0, stdout: JSON.stringify({ status: args[0] === 'host' && args[1] === 'enable' ? 'enabled' : 'started' }) })
  });
  assert.equal(code, 0, lines.join('\n'));
  const spawned = JSON.parse(lines[0]);
  const dir = path.join(box.home, HOSTS);
  const configs = fs.readdirSync(dir).filter(name => name.endsWith('.config.json')).map(name => JSON.parse(fs.readFileSync(path.join(dir, name), 'utf8')));
  assert.equal(configs.length, 1);
  assert.equal(configs[0].spawn_host, 1);
  assert.equal(configs[0].tmux, spawned.session);
  const reopened = await box.call(['open', spawned.session, '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(reopened.code, 0, reopened.err);
  assert.deepEqual(box.layout.tabs.map(tab => [tab.tmux_session, tab.tmux_host]), [[spawned.session, 1]]);
});
