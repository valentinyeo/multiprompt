const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

async function layoutFixture(features = 'groups,favorite') {
  const { run } = await import('./mp-layout.mjs');
  let layout = { workspaces: [{ name: 'Multiprompt' }, { name: 'Other' }], tabs: [] };
  let revision = 7;
  const requests = [];
  const fetch = async (url, request) => {
    requests.push({ url, method: request.method, headers: request.headers, body: request.body });
    if (request.method === 'GET') return { status: 200, headers: { get: () => features }, json: async () => ({ layout: structuredClone(layout), revision }) };
    const body = JSON.parse(request.body);
    if (body.base_revision !== revision) return { status: 409, headers: { get: () => features }, json: async () => ({}) };
    layout = body.layout;
    revision++;
    return { status: 200, headers: { get: () => features }, json: async () => ({ revision }) };
  };
  const invoke = async args => {
    const out = [], err = [];
    const code = await run(args, { env: { MULTIPROMPT_KEY: 'k', MULTIPROMPT_HOST: '1' }, fetch, out: line => out.push(line), err: line => err.push(line), tmux: () => { throw new Error('tmux'); } });
    return { code, out: out.join('\n'), err: err.join('\n') };
  };
  return { invoke, requests, get layout() { return layout; }, get revision() { return revision; } };
}

const shell = extra => ['open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--name', 'MP Runner 1 shell', '--workspace', 'Multiprompt', '--host', '1', '--no-tmux', ...extra];

test('open with a group sends the groups header and publishes one shell tab', async () => {
  const fixture = await layoutFixture();
  const opened = await fixture.invoke(shell(['--group', '  MP Runners  ']));
  assert.equal(opened.code, 0, opened.err);
  assert.equal(fixture.layout.tabs.length, 1);
  assert.equal(fixture.layout.tabs[0].group, 'MP Runners');
  assert.equal(fixture.layout.tabs[0].name, 'MP Runner 1 shell');
  assert.equal(fixture.layout.tabs[0].tmux_host, 1);
  assert.equal(fixture.layout.tabs[0].workspace, 'Multiprompt');
  for (const request of fixture.requests) assert.match(request.headers['X-Layout-Features'], /(^|,)groups(,|$)/);
  assert.ok(fixture.requests.some(request => request.method === 'PUT'));
});

test('open refuses a group when the service does not advertise groups', async () => {
  const fixture = await layoutFixture('');
  const refused = await fixture.invoke(['open', 'mp-runner-1', '--workspace', 'Multiprompt', '--group', 'MP Runners', '--no-tmux']);
  assert.equal(refused.code, 1);
  assert.match(refused.err, /does not support groups/);
  assert.equal(fixture.layout.tabs.length, 0);
  assert.ok(fixture.requests.every(request => request.method !== 'PUT'));
});

test('a second open keeps one tab and the same revision', async () => {
  const fixture = await layoutFixture();
  assert.equal((await fixture.invoke(shell(['--group', 'MP Runners']))).code, 0);
  const revision = fixture.revision;
  const again = await fixture.invoke(shell(['--group', 'MP Runners']));
  assert.equal(again.code, 0, again.err);
  assert.match(again.out, /already open/);
  assert.equal(fixture.revision, revision);
  assert.equal(fixture.layout.tabs.length, 1);
});

test('opening an existing tab switches it into the requested group', async () => {
  const fixture = await layoutFixture();
  fixture.layout.tabs.push({ kind: 'tmux', name: 'MP Runner 1 shell', tmux_session: 'mp-runner-1', tmux_host: 1, workspace: 'Multiprompt', group: 'Old' });
  const moved = await fixture.invoke(shell(['--group', 'MP Runners']));
  assert.equal(moved.code, 0, moved.err);
  assert.equal(fixture.layout.tabs.length, 1);
  assert.equal(fixture.layout.tabs[0].group, 'MP Runners');
  assert.equal(fixture.layout.tabs[0].workspace, 'Multiprompt');
});

test('a different workspace stays refused unless move is passed', async () => {
  const fixture = await layoutFixture();
  fixture.layout.tabs.push({ kind: 'tmux', name: 'MP Runner 1 shell', tmux_session: 'mp-runner-1', tmux_host: 1, workspace: 'Other' });
  const refused = await fixture.invoke(shell(['--group', 'MP Runners']));
  assert.equal(refused.code, 1);
  assert.match(refused.err, /already open in Other/);
  assert.equal(fixture.requests.filter(request => request.method === 'PUT').length, 0);
  const moved = await fixture.invoke(shell(['--group', 'MP Runners', '--move']));
  assert.equal(moved.code, 0, moved.err);
  assert.equal(fixture.layout.tabs.length, 1);
  assert.equal(fixture.layout.tabs[0].workspace, 'Multiprompt');
  assert.equal(fixture.layout.tabs[0].group, 'MP Runners');
});

test('star sets favorite and a repeat does not write again', async () => {
  const fixture = await layoutFixture();
  const starred = await fixture.invoke(shell(['--star']));
  assert.equal(starred.code, 0, starred.err);
  assert.equal(fixture.layout.tabs[0].favorite, true);
  assert.match(fixture.requests.find(request => request.method === 'PUT').headers['X-Layout-Features'], /(^|,)favorite(,|$)/);
  const revision = fixture.revision;
  const again = await fixture.invoke(shell(['--star']));
  assert.match(again.out, /already open/);
  assert.equal(fixture.revision, revision);
});

test('three shell runners land in one group and a second pass adds nothing', async () => {
  const fixture = await layoutFixture();
  for (const name of ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']) {
    const opened = await fixture.invoke(['open', '--kind', 'shell', '--tmux', name, '--name', name + ' shell', '--workspace', 'Multiprompt', '--group', 'MP Runners', '--host', '1', '--no-tmux']);
    assert.equal(opened.code, 0, opened.err);
  }
  assert.equal(fixture.layout.tabs.length, 3);
  assert.ok(fixture.layout.tabs.every(tab => tab.group === 'MP Runners' && tab.tmux_host === 1 && tab.workspace === 'Multiprompt'));
  const revision = fixture.revision;
  for (const name of ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']) {
    const again = await fixture.invoke(['open', name, '--workspace', 'Multiprompt', '--group', 'MP Runners', '--host', '1', '--no-tmux']);
    assert.match(again.out, /already open/);
  }
  assert.equal(fixture.revision, revision);
  assert.equal(fixture.layout.tabs.length, 3);
});

test('invalid groups are refused before any layout write', async () => {
  for (const group of [' ', 'x'.repeat(65), 'bad\nname', 'e\u0301\u0000']) {
    const fixture = await layoutFixture();
    const refused = await fixture.invoke(shell(['--group', group]));
    assert.equal(refused.code, 1, group);
    assert.match(refused.err, /invalid group/);
    assert.deepEqual(fixture.requests, []);
  }
  const fixture = await layoutFixture();
  const trimmed = await fixture.invoke(shell(['--group', '  e\u0301  ']));
  assert.equal(trimmed.code, 0, trimmed.err);
  assert.equal(fixture.layout.tabs[0].group, 'é');
});

test('multibot help lists the same shell and chat open commands', () => {
  const { existsSync } = require('node:fs');
  const { spawnSync } = require('node:child_process');
  assert.equal(existsSync('tools/multibot.mjs'), true);
  const help = spawnSync(process.execPath, ['tools/multibot.mjs', 'help'], { encoding: 'utf8' });
  assert.equal(help.status, 0);
  assert.match(help.stdout, /--kind shell/);
  assert.match(help.stdout, /--kind chat/);
  assert.match(help.stdout, /--group/);
  assert.match(help.stdout, /--star/);
});

test('help lists every layout command including shell and chat open', async () => {
  const { run } = await import('./mp-layout.mjs');
  const lines = [];
  assert.equal(await run(['help'], { out: line => lines.push(line), err() {} }), 0);
  const help = lines.join('\n');
  for (const word of ['list', 'create-section', 'move', 'spawn', 'open', '--kind shell', '--kind chat', '--group', '--star', '--move']) assert.match(help, new RegExp(word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
});

test('chat kind routes to spawn and refuses an old service before setup', async () => {
  const { run } = await import('./mp-layout.mjs');
  const calls = [];
  const err = [];
  const code = await run(['open', '--kind', 'chat', '--name', 'Runner', '--folder', 'work', '--workspace', 'Work', '--group', 'Runners'], {
    env: { HOME: os.tmpdir(), MULTIPROMPT_KEY: 'k' },
    out() {}, err: line => err.push(line),
    resolveFolder: () => '/work',
    fetch: async () => ({ status: 200, headers: { get: () => '' }, json: async () => ({ layout: { workspaces: [{ name: 'Work' }], tabs: [] }, revision: 1 }) }),
    lock: async () => { calls.push('lock'); return () => {}; },
    tmux: () => { calls.push('tmux'); return { status: 0 }; },
    runtime: () => { calls.push('runtime'); return { status: 0, stdout: '{}' }; }
  });
  assert.equal(code, 1);
  assert.match(err.join('\n'), /does not support groups/);
  assert.deepEqual(calls, []);
});

test('chat kind publishes one grouped live tab through spawn', async () => {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-open-chat-'));
  let layout = { workspaces: [{ name: 'Work' }], tabs: [] };
  let revision = 3;
  let marker;
  let parked = false;
  const fetch = async (_, request) => {
    if (request.method === 'GET') return { status: 200, headers: { get: () => 'groups' }, json: async () => ({ layout: structuredClone(layout), revision }) };
    const body = JSON.parse(request.body);
    if (body.base_revision !== revision) return { status: 409, json: async () => ({}) };
    layout = body.layout;
    revision++;
    return { status: 200, json: async () => ({ revision }) };
  };
  const out = [], err = [];
  const code = await run(['open', '--kind', 'chat', '--name', 'Runner chat', '--folder', 'work', '--workspace', 'Work', '--group', 'MP Runners'], {
    env: { HOME: home, MULTIPROMPT_KEY: 'k' },
    out: line => out.push(line), err: line => err.push(line),
    resolveFolder: () => '/work',
    fetch,
    lock: async () => () => {},
    tmux: args => {
      if (args[0] === 'has-session') return { status: parked ? 0 : 1 };
      if (args[0] === 'display-message') return { status: 0, stdout: `sleep|/work|${marker}\n` };
      parked = true;
      marker = args.at(-1);
      return { status: 0 };
    },
    runtime: args => ({ status: 0, stdout: JSON.stringify({ status: args[1] === 'enable' ? 'enabled' : 'started' }) })
  });
  fs.rmSync(home, { recursive: true, force: true });
  assert.equal(code, 0, err.join('\n'));
  assert.equal(layout.tabs.length, 1);
  assert.equal(layout.tabs[0].group, 'MP Runners');
  assert.equal(layout.tabs[0].name, 'Runner chat');
  assert.equal(JSON.parse(out.join('\n')).ok, true);
});
