const { test, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const homes = [];
afterEach(() => { for (const home of homes.splice(0)) fs.rmSync(home, { recursive: true, force: true }); });

async function fixture() {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-spawn-'));
  homes.push(home);
  const folder = 'work';
  let marker;
  let layout = { workspaces: [{ name: 'Work' }, { name: 'Other' }], tabs: [] };
  let revision = 0, conflicts = 0, denied = false, failPut = false, tmux = false;
  const calls = [], messages = new Map();
  let queue = Promise.resolve();
  const opts = {
    env: { HOME: home, MULTIPROMPT_KEY: 'private-key' },
    resolveFolder: value => value === folder ? '/work' : '/other',
    fetch: async (_, request) => {
      if (denied) return { status: 403, json: async () => ({ error: 'private-key' }) };
      if (request.method === 'GET') return { status: 200, headers: { get: () => 'groups' }, json: async () => ({ layout: structuredClone(layout), revision }) };
      if (failPut) { failPut = false; return { status: 500, json: async () => ({ error: 'private-key' }) }; }
      if (conflicts-- > 0) { layout.tabs.push({ kind: 'tmux', name: 'unrelated', tmux_session: 'other', tmux_host: 0, workspace: 'Work' }); revision++; return { status: 409, json: async () => ({}) }; }
      const body = JSON.parse(request.body);
      if (body.base_revision !== revision) return { status: 409, json: async () => ({}) };
      layout = body.layout; revision++;
      return { status: 200, json: async () => ({ revision }) };
    },
    lock: async () => { let release; const wait = queue; queue = new Promise(r => { release = r; }); await wait; return release; },
    tmux: args => { calls.push(['tmux', ...args]); if (args[0] === 'has-session') return { status: tmux ? 0 : 1 }; if (args[0] === 'display-message') return { status: 0, stdout: `sleep|/work|${marker}\n` }; marker = args.at(-1); tmux = true; return { status: 0 }; },
    runtime: (args, input) => {
      calls.push(['runtime', ...args]);
      if (args[0] === 'host' && args[1] === 'enable') {
        const key = crypto.createHash('sha256').update('claude:' + args[3]).digest('hex').slice(0, 32);
        const file = path.join(home, '.local/state/multiprompt/agent-host', key + '.config.json');
        fs.writeFileSync(file, JSON.stringify({ ...JSON.parse(fs.readFileSync(file)), enabled: true }));
        return { status: 0, stdout: '{"status":"enabled"}' };
      }
      if (args[0] === 'host') return { status: 0, stdout: '{"status":"started"}' };
      const [submit, dispatch] = input.trim().split('\n').map(JSON.parse);
      if (messages.has(submit.message_id) && messages.get(submit.message_id) !== submit.text) return { status: 0, stdout: '{}' };
      messages.set(submit.message_id, submit.text);
      return { status: 0, stdout: JSON.stringify({ id: submit.id, result: { message: { id: submit.message_id, text: submit.text, state: 'queued' } } }) + '\n' + JSON.stringify({ id: dispatch.id, result: {} }) };
    }
  };
  const invoke = async (extra = [], replacements = {}) => {
    const out = [], err = [];
    const code = await run(['spawn', '--name', replacements.name ?? 'Example', '--folder', replacements.folder ?? folder, '--workspace', replacements.workspace ?? 'Work', ...extra], { ...opts, out: x => out.push(x), err: x => err.push(x) });
    return { code, out: out.join(''), err: err.join('') };
  };
  return { opts, invoke, messages, calls, get layout() { return layout; }, conflict: () => { conflicts = 1; }, fail: () => { failPut = true; }, deny: () => { denied = true; } };
}

test('blank and concurrent repeats converge; changed task is refused', async () => {
  const f = await fixture();
  const blank = await f.invoke();
  assert.equal(blank.code, 0);
  assert.equal(JSON.parse(blank.out).first_task_id, null);
  const results = await Promise.all([f.invoke(['--task', 'hello']), f.invoke(['--task', 'hello'])]);
  assert.deepEqual(results.map(x => x.code), [0, 0]);
  assert.equal(f.layout.tabs.length, 1);
  assert.equal(f.messages.size, 1);
  assert.match(JSON.parse(results[0].out).first_task_id, /^mp-spawn-[0-9a-f]{32}$/);
  assert.equal((await f.invoke(['--task', 'different'])).code, 1);
});

test('partial publication and revision conflicts preserve unrelated tabs', async () => {
  const f = await fixture(); f.fail();
  assert.equal((await f.invoke()).code, 1);
  assert.equal((await f.invoke([], { workspace: 'Other' })).code, 1);
  assert.equal((await f.invoke([], { folder: 'other' })).code, 1);
  f.conflict();
  assert.equal((await f.invoke()).code, 0);
  assert.equal(f.layout.tabs.length, 2);
  assert.ok(f.layout.tabs.some(t => t.name === 'unrelated'));
});

test('validation and authorization refuse before setup', async () => {
  for (const [extra, replacements] of [[['--folder', 'other'], {}], [['--create'], {}], [['--unknown'], {}], [['--host', ''], {}], [['--task', ' '], {}], [[], { name: '\ud800' }], [[], { workspace: 'é'.repeat(16) }]]) {
    const f = await fixture();
    assert.equal((await f.invoke(extra, replacements)).code, 1);
    assert.deepEqual(f.calls, []);
  }
  const f = await fixture(); f.deny();
  const denied = await f.invoke(['--task', 'private-task']);
  assert.equal(denied.code, 1);
  assert.doesNotMatch(denied.err, /private-key|private-task/);
  assert.deepEqual(f.calls, []);
});

test('same title on host refuses terminal and other live tabs', async () => {
  for (const kind of ['terminal', 'tmux']) {
    const f = await fixture();
    f.layout.tabs.push({ kind, name: ' example ', tmux_host: 0, tmux_session: 'different', workspace: 'Work' });
    assert.equal((await f.invoke()).code, 1);
    assert.deepEqual(f.calls, []);
  }
});

test('publish precedes start; failed start retries with permission mode', async () => {
  const f = await fixture();
  const runtime = f.opts.runtime;
  let fail = true;
  f.opts.runtime = (args, input) => {
    if (args[1] === 'start') {
      assert.equal(f.layout.tabs.length, 1);
      if (fail) { fail = false; return { status: 1, stderr: 'private-key private-task' }; }
    }
    return runtime(args, input);
  };
  const first = await f.invoke(['--task', 'private-task']);
  assert.equal(first.code, 1);
  assert.doesNotMatch(first.err, /private-key|private-task/);
  assert.equal((await f.invoke(['--task', 'private-task'])).code, 0);
  const enable = f.calls.find(x => x[1] === 'host' && x[2] === 'enable');
  assert.deepEqual(enable.slice(-2), ['--permission-mode', 'bypassPermissions']);
  assert.equal(f.layout.tabs.length, 1);
});

test('visible chats never create a parking pane, even without a tmux server', async () => {
  const f = await fixture();
  f.opts.tmux = args => { assert.equal(args[0], 'has-session'); return { status: 1 }; };
  assert.equal((await f.invoke()).code, 0);
  assert.equal((await f.invoke()).code, 0);
  assert.equal(f.layout.tabs.length, 1);
});

test('headless repeats stay undiscoverable; visible mode promotes the same chat and task', async () => {
  const f = await fixture();
  const options = ['--mode', 'headless', '--group', 'Runners', '--task', 'one task'];
  const first = await f.invoke(options);
  const again = await f.invoke(options);
  assert.equal(first.code, 0);
  assert.equal(again.code, 0);
  assert.equal(JSON.parse(first.out).mode, 'headless');
  assert.equal(f.layout.tabs.length, 0);
  assert.ok(!f.calls.some(call => call[0] === 'tmux' && call[1] !== 'has-session'));
  assert.equal(f.messages.size, 1);
  const shown = await f.invoke(['--mode', 'visible', '--group', 'Runners', '--task', 'one task']);
  assert.equal(shown.code, 0, shown.err);
  assert.equal(JSON.parse(shown.out).sid, JSON.parse(first.out).sid);
  assert.equal(f.layout.tabs.length, 1);
  assert.equal(f.layout.tabs[0].group, 'Runners');
  assert.equal(f.messages.size, 1);
  assert.equal((await f.invoke(options)).code, 1);
  assert.equal((await f.invoke(['--group', 'Other'])).code, 1);
  assert.equal(f.layout.tabs[0].group, 'Runners');
  assert.ok(!f.calls.some(call => call.includes('@mp_host_sid') || call.includes('new-session')));
});

test('invalid modes and groups refuse before any host setup', async () => {
  for (const options of [['--mode', 'background'], ['--group', ' '], ['--group', 'x'.repeat(65)], ['--group', 'bad\nname'], ['--mode', 'headless', '--mode', 'visible']]) {
    const f = await fixture();
    assert.equal((await f.invoke(options)).code, 1);
    assert.deepEqual(f.calls, []);
  }
});

test('old services refuse group requests before setup', async () => {
  const f = await fixture();
  const fetch = f.opts.fetch;
  f.opts.fetch = async (...args) => ({ ...await fetch(...args), headers: { get: () => '' } });
  const result = await f.invoke(['--group', 'Runners']);
  assert.equal(result.code, 1);
  assert.match(result.err, /does not support groups/);
  assert.deepEqual(f.calls, []);
});

test('headless cannot adopt an existing terminal or visible setup claim', async () => {
  const f = await fixture();
  f.fail();
  assert.equal((await f.invoke()).code, 1);
  assert.equal((await f.invoke(['--mode', 'headless'])).code, 1);
  assert.equal(f.layout.tabs.length, 0);
});

test('task text travels through protocol, not command arguments', async () => {
  const f = await fixture();
  const text = 'literal; $(not-a-command)';
  const result = await f.invoke(['--task', text]);
  assert.equal(result.code, 0);
  assert.deepEqual([...f.messages.values()], [text]);
  assert.ok(!JSON.stringify(f.calls).includes(text));
  assert.ok(!JSON.stringify(f.calls).includes('private-key'));
});

test('a foreign terminal name collision is refused without creating anything', async () => {
  const f = await fixture();
  f.opts.tmux = args => { assert.equal(args[0], 'has-session'); return { status: 0 }; };
  assert.equal((await f.invoke()).code, 1);
  assert.equal(f.layout.tabs.length, 0);
});

test('failed dispatch and malformed submit do not report success', async () => {
  for (const failure of ['dispatch', 'submit']) {
    const f = await fixture();
    const runtime = f.opts.runtime;
    f.opts.runtime = (args, input) => {
      const result = runtime(args, input);
      if (args[0] !== '--serve') return result;
      const replies = result.stdout.split('\n').map(JSON.parse);
      if (failure === 'dispatch') replies[1].result.message = { state: 'failed' };
      else replies[0].result.message.id = 'unexpected';
      return { status: 0, stdout: replies.map(JSON.stringify).join('\n') };
    };
    assert.equal((await f.invoke(['--task', 'hello'])).code, 1);
    assert.equal(f.messages.size, 1);
  }
});

test('normalized names converge and terminal ownership is preserved', async () => {
  const f = await fixture();
  const first = await f.invoke([], { name: '  Caf\u00e9  ' });
  const repeated = await f.invoke([], { name: 'CAFE\u0301' });
  assert.equal(first.code, 0);
  assert.equal(repeated.code, 0);
  assert.equal(JSON.parse(first.out).sid, JSON.parse(repeated.out).sid);
  assert.equal(f.layout.tabs.length, 1);
  const key = crypto.createHash('sha256').update('claude:' + JSON.parse(first.out).sid).digest('hex').slice(0, 32);
  fs.writeFileSync(path.join(f.opts.env.HOME, '.local/state/multiprompt/agent-host', key + '.owner.json'), JSON.stringify({ owner: 'terminal' }), { mode: 0o600 });
  assert.match((await f.invoke([], { name: 'Caf\u00e9' })).err, /owned by terminal/);
});
