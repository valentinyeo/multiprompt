const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const HOSTS = path.join('.local/state/multiprompt/agent-host');
const FIXTURE = path.join(__dirname, 'fixtures/SOFT-3139/servers.json');
const INSTALLED_FIXTURE = path.join(__dirname, 'fixtures/MUBO-294/servers.json');

const noSlot = (session, file) => `give --host: ${session} has no recorded host and this machine has no multiprompt_slot; set MULTIPROMPT_HOST or add "multiprompt_slot": 0, 1 or 2 to its entry in ${file}`;

const layoutHosts = () => ([
  { slot: 0, name: 'Desk', hostname: 'desk.fake.internal', port: 22, user: 'red-cust' },
  { slot: 1, name: 'Rack beta', hostname: 'rack-beta.fake.internal', port: 22, user: 'red-cust' },
  { slot: 2, name: 'Other', hostname: 'rack-beta.fake.internal', port: 22, user: 'blue-cust' }
]);

async function fixture(extra = {}) {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-host-'));
  let layout = { workspaces: [{ name: 'Multiprompt' }], tabs: [], hosts: layoutHosts() };
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
  const env = { MULTIPROMPT_KEY: 'k', HOME: home, USER: 'red-cust', MULTIPROMPT_SERVERS_FILE: FIXTURE, ...extra.env };
  const call = async args => {
    const out = [], err = [];
    const { env: envPatch, ...rest } = extra;
    const code = await run(args, { env: { ...env, ...envPatch }, fetch, out: line => out.push(line), err: line => err.push(line), tmux: () => ({ status: 0 }), ...rest });
    return { code, out: out.join('\n'), err: err.join('\n') };
  };
  return { home, call, puts, env, get layout() { return layout; }, set layout(value) { layout = value; } };
}

function record(home, tmux, host, extra = {}) {
  const dir = path.join(home, HOSTS);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'record-' + tmux + '.config.json'), JSON.stringify({ enabled: true, tmux, spawn_host: host, ...extra }));
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
  const missing = path.join(box.home, 'missing-servers.json');
  box.env.MULTIPROMPT_SERVERS_FILE = missing;
  const refused = await box.call(['open', 'live-new', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: ' + noSlot('live-new', missing));
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 the installed servers file names the host for a chat with no record', async () => {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-host-'));
  const facts = JSON.parse(fs.readFileSync(FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'rack-beta' ? { ...server, hostname: os.hostname() } : server);
  const serversFile = path.join(home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  const env = { MULTIPROMPT_KEY: 'k', HOME: home, USER: 'red-cust', MULTIPROMPT_SERVERS_FILE: serversFile };
  let layout = { workspaces: [{ name: 'Multiprompt' }], tabs: [], hosts: layoutHosts().map(item => item.slot === 1 ? { ...item, hostname: os.hostname() } : item) };
  const fetch = async (url, request) => {
    const headers = { get: () => 'groups' };
    if (request.method === 'GET') return { status: 200, headers, json: async () => ({ layout: structuredClone(layout), revision: 1 }) };
    layout = JSON.parse(request.body).layout;
    return { status: 200, headers, json: async () => ({ revision: 2 }) };
  };
  const opened = await run(['open', 'live-legacy', '--workspace', 'Multiprompt', '--no-tmux'], { env, fetch, out: () => {}, err: () => {}, tmux: () => ({ status: 0 }) });
  assert.equal(opened, 0);
  assert.equal(layout.tabs[0].tmux_host, 1);
});

test('SOFT-3139 reopen without --host lands on the second slot when only the servers file knows the machine', async () => {
  const box = await fixture();
  const facts = JSON.parse(fs.readFileSync(FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'rack-beta' ? { ...server, hostname: os.hostname() } : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  box.env.MULTIPROMPT_SERVERS_FILE = serversFile;
  box.layout.hosts = layoutHosts().map(item => item.slot === 1 ? { ...item, hostname: os.hostname() } : item);
  const reopened = await box.call(['open', 'live-today', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(reopened.code, 0, reopened.err);
  assert.equal(box.layout.tabs[0].tmux_host, 1);
  assert.notEqual(box.layout.tabs[0].tmux_host, 0);
});

test('SOFT-3139 a shared server refuses when the os user is not allowed', async () => {
  const box = await fixture({ env: { USER: 'stranger-cust' } });
  const facts = JSON.parse(fs.readFileSync(FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'rack-beta' ? { ...server, hostname: os.hostname() } : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  box.env.MULTIPROMPT_SERVERS_FILE = serversFile;
  const refused = await box.call(['open', 'live-shared', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: ' + noSlot('live-shared', serversFile));
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 a shared server refuses the other customer user on this machine', async () => {
  const box = await fixture({ env: { USER: 'red-cust' } });
  const facts = JSON.parse(fs.readFileSync(FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'rack-beta' ? { ...server, hostname: os.hostname() } : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  box.env.MULTIPROMPT_SERVERS_FILE = serversFile;
  box.layout.hosts = [{ slot: 2, name: 'Rack beta blue', hostname: os.hostname(), port: 22, user: 'blue-cust' }];
  const refused = await box.call(['open', 'live-red-on-shared', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: ' + noSlot('live-red-on-shared', serversFile));
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 an unknown machine refuses when the servers file does not match', async () => {
  const box = await fixture({ env: { USER: 'red-cust' } });
  const refused = await box.call(['open', 'live-nowhere', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.equal(refused.err, 'mp-layout: ' + noSlot('live-nowhere', FIXTURE));
  assert.equal(box.puts.length, 0);
});

test('SOFT-3139 spawn refuses without --host and records the host it is given', async () => {
  const box = await fixture();
  const refused = await box.call(['spawn', '--name', 'New chat', '--folder', 'work', '--workspace', 'Multiprompt']);
  assert.equal(refused.code, 1);
  assert.deepEqual(JSON.parse(refused.err), { ok: false, error: noSlot('New chat', FIXTURE) });
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

test('MUBO-294 a tab that is already open reopens with the installed servers file and no slot', async () => {
  const box = await fixture({ env: { MULTIPROMPT_SERVERS_FILE: INSTALLED_FIXTURE } });
  box.layout.tabs = [{ kind: 'tmux', name: 'Live chat', tmux_session: 'live-open', tmux_host: 1, workspace: 'Multiprompt' }];
  const reopened = await box.call(['open', 'live-open', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(reopened.code, 0, reopened.err);
  assert.deepEqual(box.layout.tabs.map(tab => [tab.tmux_session, tab.tmux_host]), [['live-open', 1]]);
});

test('MUBO-294 the servers file slot names the host for a new tab', async () => {
  const box = await fixture();
  const facts = JSON.parse(fs.readFileSync(INSTALLED_FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'site-two'
    ? { ...server, hostname: os.hostname(), multiprompt_slot: 1 }
    : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  box.env.MULTIPROMPT_SERVERS_FILE = serversFile;
  const opened = await box.call(['open', 'live-from-slot', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(opened.code, 0, opened.err);
  assert.equal(box.layout.tabs[0].tmux_host, 1);
});

test('MUBO-294 MULTIPROMPT_HOST wins over a servers file slot', async () => {
  const box = await fixture({ env: { MULTIPROMPT_HOST: '0' } });
  const facts = JSON.parse(fs.readFileSync(INSTALLED_FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'site-two'
    ? { ...server, hostname: os.hostname(), multiprompt_slot: 2 }
    : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  box.env.MULTIPROMPT_SERVERS_FILE = serversFile;
  const opened = await box.call(['open', 'live-from-env', '--workspace', 'Multiprompt', '--no-tmux']);
  assert.equal(opened.code, 0, opened.err);
  assert.equal(box.layout.tabs[0].tmux_host, 0);
});

test('MUBO-294 a new tab with the installed servers file names the file and the field to add', async () => {
  const box = await fixture({ env: { MULTIPROMPT_SERVERS_FILE: INSTALLED_FIXTURE } });
  const refused = await box.call(['spawn', '--name', 'New chat', '--folder', 'work', '--workspace', 'Multiprompt']);
  assert.equal(refused.code, 1);
  const error = JSON.parse(refused.err).error;
  assert.match(error, /multiprompt_slot/);
  assert.ok(error.includes(INSTALLED_FIXTURE), error);
  assert.equal(box.puts.length, 0);
});

test('MUBO-294 spawn takes the servers file slot when no --host is given', async () => {
  const box = await fixture();
  const facts = JSON.parse(fs.readFileSync(INSTALLED_FIXTURE, 'utf8'));
  facts.servers = facts.servers.map(server => server.id === 'site-two'
    ? { ...server, hostname: os.hostname(), multiprompt_slot: 1 }
    : server);
  const serversFile = path.join(box.home, 'servers.json');
  fs.writeFileSync(serversFile, JSON.stringify(facts));
  const lines = [];
  const { run } = await import('./mp-layout.mjs');
  const code = await run(['spawn', '--name', 'New chat', '--folder', 'work', '--workspace', 'Multiprompt'], {
    env: { MULTIPROMPT_KEY: 'k', HOME: box.home, MULTIPROMPT_SERVERS_FILE: serversFile },
    resolveFolder: () => '/work',
    fetch: async (url, request) => (request.method === 'GET'
      ? { status: 200, headers: { get: () => 'groups' }, json: async () => ({ layout: { workspaces: [{ name: 'Multiprompt' }], tabs: [] }, revision: 1 }) }
      : { status: 200, headers: { get: () => 'groups' }, json: async () => ({ revision: 2 }) }),
    out: line => lines.push(line),
    err: line => lines.push(line),
    lock: async () => () => {},
    tmux: args => ({ status: args[0] === 'has-session' ? 1 : 0 }),
    runtime: args => ({ status: 0, stdout: JSON.stringify({ status: args[0] === 'host' && args[1] === 'enable' ? 'enabled' : 'started' }) })
  });
  assert.equal(code, 0, lines.join('\n'));
  assert.equal(JSON.parse(lines[0]).host, 1);
});