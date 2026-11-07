import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { run } from './mb.mjs';

const FEATURES = 'favorite,muted,used,visits,input,settings,hosts,host_removal,workspace_color,bot_appearance,bot_photo,bot_palette8,groups';
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGD4DwABBAEAX+XDSwAAAABJRU5ErkJggg==', 'base64');

function harness(options = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'mb-'));
  const layout = options.layout || { schema: 1, revision: 1, workspaces: [{ name: 'Work' }], tabs: [] };
  let revision = 1;
  const photos = new Map();
  const puts = [];
  const tmux = [];
  const runtime = [];
  const sessions = new Set();
  const panes = new Map();
  const ownerPath = join(dir, 'owners.json');
  const features = options.features ?? FEATURES;
  const fetch = async (url, init = {}) => {
    const path = new URL(url).pathname;
    const method = init.method || 'GET';
    const headers = { get: name => name.toLowerCase() === 'x-layout-features' ? features : null };
    if (path === '/v1/layout' && method === 'GET') return { status: 200, headers, json: async () => ({ revision, layout: structuredClone(layout) }) };
    if (path === '/v1/layout' && method === 'PUT') {
      const body = JSON.parse(init.body);
      puts.push({ kind: 'layout', features: init.headers['X-Layout-Features'], body });
      if (body.base_revision !== revision) return { status: 409, headers, json: async () => ({ error: 'revision_conflict' }) };
      revision += 1;
      layout.workspaces = body.layout.workspaces;
      layout.tabs = body.layout.tabs;
      return { status: 200, headers, json: async () => ({ revision, layout: structuredClone(layout) }) };
    }
    const photo = path.match(/^\/v1\/bot-photos\/([0-9a-f]{64})$/);
    if (photo && method === 'GET') {
      const png = photos.get(photo[1]);
      return png ? { status: 200, headers, json: async () => ({ png }) } : { status: 404, headers, json: async () => ({ error: 'not_found' }) };
    }
    if (photo && method === 'PUT') {
      puts.push({ kind: 'photo', features: init.headers['X-Layout-Features'] });
      photos.set(photo[1], JSON.parse(init.body).png);
      revision += 1;
      return { status: 200, headers, json: async () => ({ photo: revision }) };
    }
    return { status: 404, headers, json: async () => ({ error: 'not_found' }) };
  };
  const sessionOf = args => {
    const marked = args.find(arg => String(arg).startsWith('='));
    if (marked) return marked.slice(1);
    const index = args.indexOf('-s');
    return index >= 0 ? args[index + 1] : '';
  };
  const tmuxFn = args => {
    tmux.push(args);
    const name = sessionOf(args);
    if (args[0] === 'has-session') return { status: sessions.has(name) ? 0 : 1, stdout: '' };
    if (args[0] === 'new-session') { sessions.add(name); panes.set(name, args[4] || 'sleep'); return { status: 0, stdout: '' }; }
    if (args[0] === 'kill-session') { sessions.delete(name); return { status: 0, stdout: '' }; }
    if (args[0] === 'list-panes') return { status: sessions.has(name) ? 0 : 1, stdout: sessions.has(name) ? panes.get(name) + '\n' : '' };
    return { status: 0, stdout: '' };
  };
  const call = async args => {
    const lines = [], errors = [];
    const code = await run(args, {
      env: { MULTIPROMPT_KEY: 'test-key', MULTIPROMPT_URL: 'http://layout.test', HOME: dir, MULTIPROMPT_HOST: '0' },
      out: line => lines.push(line), err: line => errors.push(line), fetch, tmux: tmuxFn,
      runtime: argv => { runtime.push(argv); return { status: 0, stdout: '{"status":"disabled"}' }; },
      ownerPath
    });
    let owners = null;
    try { owners = JSON.parse(readFileSync(ownerPath, 'utf8')); } catch { owners = null; }
    return { code, lines, errors, puts, revision: () => revision, layout, tmux, runtime, sessions, panes, owners };
  };
  return { call, dir, layout, puts, panes, sessions, tmux };
}

const text = result => [...result.lines, ...result.errors].join('\n');

test('help lists style, workspace color, and roster apply', async () => {
  const lines = [];
  assert.equal(await run(['help'], { out: line => lines.push(line), err() {} }), 0);
  const help = lines.join('\n');
  for (const word of ['list', 'open', 'close', 'rename', 'move', 'style', '--face', '--color', '--photo', 'workspace color', 'group create', 'roster apply', '--dry-run']) assert.match(help, new RegExp(word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  assert.equal(await run([], { out() {}, err() {} }), 2);
});

test('invalid face and color are refused before any request', async () => {
  const box = harness();
  let fetches = 0;
  const lines = [], errors = [];
  const code = await run(['style', 'plain', '--face', '20'], {
    env: { MULTIPROMPT_KEY: 'k', MULTIPROMPT_URL: 'http://layout.test', HOME: box.dir },
    out: line => lines.push(line), err: line => errors.push(line),
    fetch: () => { fetches += 1; throw new Error('fetched'); }, ownerPath: join(box.dir, 'owners.json')
  });
  assert.equal(code, 1);
  assert.match(errors[0], /invalid face/);
  assert.equal(fetches, 0);
  const color = await box.call(['workspace', 'color', 'Work', '8']);
  assert.equal(color.code, 1);
  assert.match(color.errors[0], /invalid color/);
  assert.equal(color.puts.length, 0);
  rmSync(box.dir, { recursive: true, force: true });
});

test('style and workspace color publish once and then match', async () => {
  const box = harness({ layout: { schema: 1, revision: 1, workspaces: [{ name: 'Work' }], tabs: [{ kind: 'tmux', name: 'Runner', tmux_session: 'mp-runner-1', tmux_host: 0, workspace: 'Work', group: 'Runners' }] } });
  const photo = join(box.dir, 'face.png');
  writeFileSync(photo, PNG);
  const styled = await box.call(['style', 'mp-runner-1', '--face', '4', '--color', '7', '--photo', photo]);
  assert.equal(styled.code, 0, text(styled));
  assert.match(styled.lines.at(-1), /styled mp-runner-1/);
  assert.equal(box.layout.tabs[0].face, 4);
  assert.equal(box.layout.tabs[0].color, 7);
  const layoutPut = styled.puts.find(put => put.kind === 'layout');
  assert.match(layoutPut.features, /bot_appearance/);
  assert.match(layoutPut.features, /bot_palette8/);
  assert.doesNotMatch(layoutPut.features, /(^|,)favorite(,|$)/);
  assert.equal(styled.puts.filter(put => put.kind === 'photo').length, 1);
  const styledPuts = box.puts.length;
  const again = await box.call(['style', 'Runner', '--face', '4', '--color', '7', '--photo', photo]);
  assert.match(again.lines.at(-1), /already styled/);
  assert.equal(box.puts.length, styledPuts);
  const colored = await box.call(['workspace', 'color', 'Work', '3']);
  assert.match(colored.lines[0], /colored workspace Work/);
  assert.equal(box.layout.workspaces[0].color, 3);
  assert.match(colored.puts.at(-1).features, /workspace_color/);
  const coloredPuts = box.puts.length;
  const same = await box.call(['workspace', 'color', 'Work', '3']);
  assert.match(same.lines[0], /already colored 3/);
  assert.equal(box.puts.length, coloredPuts);
  rmSync(box.dir, { recursive: true, force: true });
});

test('open groups a shell once, and a different workspace is refused', async () => {
  const box = harness();
  const opened = await box.call(['open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--title', 'Runner 1', '--workspace', 'Work', '--group', 'MP Runners', '--host', '1', '--no-tmux']);
  assert.equal(opened.code, 0, text(opened));
  assert.equal(box.layout.tabs.length, 1);
  assert.equal(box.layout.tabs[0].group, 'MP Runners');
  assert.equal(box.sessions.size, 0);
  const openedPuts = box.puts.length;
  const repeat = await box.call(['open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--workspace', 'Work', '--group', 'MP Runners', '--host', '1', '--no-tmux']);
  assert.match(repeat.lines[0], /already open mp-runner-1/);
  assert.equal(box.puts.length, openedPuts);
  const moved = await box.call(['open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--workspace', 'Other', '--host', '1', '--no-tmux']);
  assert.equal(moved.code, 1);
  assert.match(moved.errors[0], /already open in Work/);
  assert.equal(box.puts.length, openedPuts);
  rmSync(box.dir, { recursive: true, force: true });
});

test('groups are refused before tmux when the service does not advertise them', async () => {
  const box = harness({ features: 'favorite,bot_appearance' });
  const opened = await box.call(['open', '--kind', 'shell', '--tmux', 'mp-runner-1', '--workspace', 'Work', '--group', 'Runners']);
  assert.equal(opened.code, 1);
  assert.match(opened.errors[0], /does not support groups/);
  assert.equal(opened.puts.length, 0);
  assert.equal(opened.tmux.length, 0);
  rmSync(box.dir, { recursive: true, force: true });
});

test('close removes a tab, kills only an owned empty session, and leaves a busy one', async () => {
  const box = harness({ layout: { schema: 1, revision: 1, workspaces: [{ name: 'Work' }], tabs: [
    { kind: 'tmux', name: 'Foreign', tmux_session: 'foreign', tmux_host: 0, workspace: 'Work' },
    { kind: 'tmux', name: 'Owned', tmux_session: 'owned', tmux_host: 0, workspace: 'Work' },
    { kind: 'tmux', name: 'Busy', tmux_session: 'busy', tmux_host: 0, workspace: 'Work' }
  ] } });
  box.sessions.add('owned'); box.sessions.add('busy'); box.sessions.add('foreign');
  box.panes.set('owned', 'sleep'); box.panes.set('busy', 'node'); box.panes.set('foreign', 'sleep');
  writeFileSync(join(box.dir, 'owners.json'), JSON.stringify({ sessions: {
    '0:owned': { owner: 'mb', name: 'Owned', session: 'owned', host: 0, command: 'sleep infinity', provider: 'hax', sid: 'sid-1' },
    '0:busy': { owner: 'mb', name: 'Busy', session: 'busy', host: 0, command: 'sleep infinity', provider: 'hax', sid: 'sid-2' }
  }, workspaces: {}, groups: {} }));
  const foreign = await box.call(['close', 'foreign']);
  assert.match(foreign.lines.at(-1), /closed foreign/);
  assert.equal(box.layout.tabs.some(tab => tab.tmux_session === 'foreign'), false);
  assert.equal(foreign.tmux.some(args => args[0] === 'kill-session'), false);
  const owned = await box.call(['close', 'owned']);
  assert.match(text(owned), /closed owned/);
  assert.ok(owned.runtime.some(args => args.join(' ') === 'host disable hax sid-1'));
  assert.ok(owned.tmux.some(args => args[0] === 'kill-session' && args.at(-1) === '=owned'));
  const busy = await box.call(['close', 'busy']);
  assert.match(text(busy), /left busy/);
  assert.match(text(busy), /closed busy/);
  assert.equal(busy.tmux.some(args => args[0] === 'kill-session' && args.at(-1) === '=busy'), false);
  assert.equal(busy.owners.sessions['0:busy'].owner, 'mb');
  const repeat = await box.call(['close', 'owned']);
  assert.match(repeat.lines.at(-1), /already closed owned/);
  rmSync(box.dir, { recursive: true, force: true });
});

test('workspace and group verbs are idempotent and delete only owned names', async () => {
  const box = harness();
  const created = await box.call(['workspace', 'create', 'Multiprompt', '--color', '2']);
  assert.match(created.lines[0], /created workspace Multiprompt/);
  assert.equal(box.layout.workspaces.at(-1).color, 2);
  assert.equal(created.owners.workspaces.Multiprompt.owner, 'mb');
  const createdPuts = box.puts.length;
  const again = await box.call(['workspace', 'create', 'Multiprompt']);
  assert.match(again.lines[0], /already exists/);
  assert.equal(box.puts.length, createdPuts);
  const renamed = await box.call(['workspace', 'rename', 'Multiprompt', 'Lead']);
  assert.match(renamed.lines[0], /renamed workspace Multiprompt to Lead/);
  const renamedPuts = box.puts.length;
  const renamedAgain = await box.call(['workspace', 'rename', 'Multiprompt', 'Lead']);
  assert.match(renamedAgain.lines[0], /already renamed/);
  assert.equal(box.puts.length, renamedPuts);
  const foreign = await box.call(['workspace', 'delete', 'Work']);
  assert.equal(foreign.code, 1);
  assert.match(foreign.errors[0], /not owned/);
  const removed = await box.call(['workspace', 'delete', 'Lead']);
  assert.match(removed.lines[0], /deleted workspace Lead/);
  const removedAgain = await box.call(['workspace', 'delete', 'Lead']);
  assert.match(removedAgain.lines[0], /already deleted workspace Lead/);
  const group = await box.call(['group', 'create', 'MP Runners']);
  assert.match(group.lines[0], /created group MP Runners/);
  const groupPuts = box.puts.length;
  const groupAgain = await box.call(['group', 'create', 'MP Runners']);
  assert.match(groupAgain.lines[0], /already exists/);
  assert.equal(box.puts.length, groupPuts);
  const groupGone = await box.call(['group', 'delete', 'MP Runners']);
  assert.match(groupGone.lines[0], /deleted group MP Runners/);
  const groupGoneAgain = await box.call(['group', 'delete', 'MP Runners']);
  assert.match(groupGoneAgain.lines[0], /already deleted group/);
  rmSync(box.dir, { recursive: true, force: true });
});

test('roster apply creates the workspace, group, face, color, and photo once', async () => {
  const box = harness({ layout: { schema: 1, revision: 1, workspaces: [{ name: 'Work' }], tabs: [{ kind: 'tmux', name: 'Foreign', tmux_session: 'foreign', tmux_host: 0, workspace: 'Work' }] } });
  const photo = join(box.dir, 'runner.png');
  writeFileSync(photo, PNG);
  const file = join(box.dir, 'roster.json');
  const roster = {
    workspaces: [{ name: 'Multiprompt', color: 5 }],
    groups: ['MP Runners'],
    runners: [
      { name: 'mp-runner-1', kind: 'shell', title: 'Runner 1', workspace: 'Multiprompt', group: 'MP Runners', command: 'sleep infinity', model: 'cursor', face: 2, color: 4, photo: 'runner.png', host: 1 },
      { name: 'mp-runner-2', kind: 'shell', title: 'Runner 2', workspace: 'Multiprompt', group: 'MP Runners', command: 'sleep infinity', model: 'cursor', host: 1 },
      { name: 'mp-runner-3', kind: 'shell', title: 'Runner 3', workspace: 'Multiprompt', group: 'MP Runners', command: 'sleep infinity', model: 'cursor', host: 1 }
    ]
  };
  writeFileSync(file, JSON.stringify(roster));
  const dry = await box.call(['roster', 'apply', file, '--dry-run']);
  assert.equal(dry.lines[0], 'dry-run');
  assert.ok(dry.lines.includes('create workspace Multiprompt'));
  assert.ok(dry.lines.includes('create group MP Runners'));
  assert.ok(dry.lines.includes('open mp-runner-1'));
  assert.ok(dry.lines.includes('photo mp-runner-1'));
  assert.equal(dry.puts.length, 0);
  assert.equal(dry.tmux.some(args => args[0] === 'new-session'), false);
  assert.equal(dry.owners, null);
  const applied = await box.call(['roster', 'apply', file]);
  assert.equal(applied.code, 0, text(applied));
  assert.equal(applied.lines.at(-2), 'applied');
  const runners = box.layout.tabs.filter(tab => tab.workspace === 'Multiprompt');
  assert.deepEqual(runners.map(tab => tab.tmux_session), ['mp-runner-1', 'mp-runner-2', 'mp-runner-3']);
  assert.ok(runners.every(tab => tab.group === 'MP Runners'));
  assert.equal(runners[0].face, 2);
  assert.equal(runners[0].color, 4);
  assert.equal(box.layout.workspaces.find(workspace => workspace.name === 'Multiprompt').color, 5);
  assert.equal(box.layout.tabs.some(tab => tab.tmux_session === 'foreign'), true);
  assert.equal(applied.owners.sessions['1:mp-runner-1'].owner, 'mb');
  assert.equal(applied.owners.sessions['0:foreign'], undefined);
  assert.equal(applied.puts.filter(put => put.kind === 'layout').length, 1);
  assert.equal(applied.puts.filter(put => put.kind === 'photo').length, 1);
  assert.match(applied.puts.find(put => put.kind === 'layout').features, /groups/);
  const count = box.puts.length;
  const started = box.tmux.filter(args => args[0] === 'new-session').length;
  const repeat = await box.call(['roster', 'apply', file]);
  assert.ok(repeat.lines.includes('unchanged mp-runner-1'));
  assert.ok(repeat.lines.includes('unchanged workspace Multiprompt'));
  assert.ok(repeat.lines.includes('unchanged group MP Runners'));
  assert.equal(box.puts.length, count);
  assert.equal(box.tmux.filter(args => args[0] === 'new-session').length, started);
  roster.runners = roster.runners.filter(runner => runner.name !== 'mp-runner-2');
  writeFileSync(file, JSON.stringify(roster));
  const planned = await box.call(['roster', 'apply', file, '--dry-run']);
  assert.ok(planned.lines.includes('close mp-runner-2'));
  assert.equal(planned.puts.length, count);
  assert.equal(box.layout.tabs.some(tab => tab.tmux_session === 'mp-runner-2'), true);
  const closed = await box.call(['roster', 'apply', file]);
  assert.equal(closed.code, 0, text(closed));
  assert.equal(box.layout.tabs.some(tab => tab.tmux_session === 'mp-runner-2'), false);
  assert.equal(box.layout.tabs.some(tab => tab.tmux_session === 'foreign'), true);
  assert.ok(closed.tmux.some(args => args[0] === 'kill-session' && args.at(-1) === '=mp-runner-2'));
  box.panes.set('mp-runner-3', 'node');
  roster.runners.find(runner => runner.name === 'mp-runner-3').command = 'codex';
  writeFileSync(file, JSON.stringify(roster));
  const beforeBusy = box.puts.length;
  const busy = await box.call(['roster', 'apply', file]);
  assert.equal(busy.code, 1, text(busy));
  assert.match(text(busy), /busy mp-runner-3/);
  assert.equal(box.puts.length, beforeBusy);
  assert.equal(box.layout.tabs.find(tab => tab.tmux_session === 'mp-runner-3').name, 'Runner 3');
  rmSync(box.dir, { recursive: true, force: true });
});

test('a listed unowned runner is regrouped and not claimed', async () => {
  const box = harness({ layout: { schema: 1, revision: 1, workspaces: [{ name: 'Work' }, { name: 'Multiprompt' }], tabs: [{ kind: 'tmux', name: 'Old', tmux_session: 'mp-runner-1', tmux_host: 1, workspace: 'Work' }] } });
  const file = join(box.dir, 'roster.json');
  writeFileSync(file, JSON.stringify({ workspaces: ['Multiprompt'], groups: ['MP Runners'], runners: [{ name: 'mp-runner-1', kind: 'shell', title: 'Runner 1', workspace: 'Multiprompt', group: 'MP Runners', face: 1, color: 0, host: 1 }] }));
  const applied = await box.call(['roster', 'apply', file]);
  assert.equal(applied.code, 0, text(applied));
  const tab = box.layout.tabs[0];
  assert.equal(tab.workspace, 'Multiprompt');
  assert.equal(tab.group, 'MP Runners');
  assert.equal(tab.face, 1);
  assert.equal(tab.color, 0);
  assert.equal(applied.owners.sessions['1:mp-runner-1'], undefined);
  const dropped = JSON.parse(readFileSync(file, 'utf8'));
  dropped.runners = [];
  writeFileSync(file, JSON.stringify(dropped));
  const after = await box.call(['roster', 'apply', file]);
  assert.equal(after.code, 0, text(after));
  assert.equal(box.layout.tabs.length, 1);
  assert.equal(after.tmux.some(args => args[0] === 'kill-session'), false);
  rmSync(box.dir, { recursive: true, force: true });
});
