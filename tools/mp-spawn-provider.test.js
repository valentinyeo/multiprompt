const { test, afterEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const homes = [];
afterEach(() => { for (const home of homes.splice(0)) fs.rmSync(home, { recursive: true, force: true }); });

async function spawn(extra) {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-spawn-provider-'));
  homes.push(home);
  let layout = { workspaces: [{ name: 'Work' }], tabs: [] };
  let revision = 0, marker, parked = false;
  const calls = [], submitted = [], errors = [];
  const out = [];
  const code = await run(['spawn', '--name', 'MP Runner 1', '--folder', 'work', '--workspace', 'Work', '--host', '0', '--group', 'Runners', ...extra], {
    env: { HOME: home, MULTIPROMPT_KEY: 'private-key' },
    resolveFolder: () => '/work',
    fetch: async (_, request) => {
      if (request.method === 'GET') return { status: 200, headers: { get: () => 'groups' }, json: async () => ({ layout: structuredClone(layout), revision }) };
      layout = JSON.parse(request.body).layout; revision++;
      return { status: 200, json: async () => ({ revision }) };
    },
    lock: async () => () => {},
    tmux: args => { if (args[0] === 'has-session') return { status: parked ? 0 : 1 }; if (args[0] === 'display-message') return { status: 0, stdout: `sleep|/work|${marker}\n` }; marker = args.at(-1); parked = true; return { status: 0 }; },
    runtime: (args, input) => {
      calls.push(args);
      if (args[0] === 'host' && args[1] === 'enable') {
        const key = crypto.createHash('sha256').update(args[2] + ':' + args[3]).digest('hex').slice(0, 32);
        const file = path.join(home, '.local/state/multiprompt/agent-host', key + '.config.json');
        fs.writeFileSync(file, JSON.stringify({ ...JSON.parse(fs.readFileSync(file)), enabled: true }));
        return { status: 0, stdout: '{"status":"enabled"}' };
      }
      if (args[0] === 'host') return { status: 0, stdout: '{"status":"started"}' };
      const [submit, dispatch] = input.trim().split('\n').map(JSON.parse);
      submitted.push(submit);
      return { status: 0, stdout: JSON.stringify({ id: submit.id, result: { message: { id: submit.message_id, text: submit.text, state: 'queued' } } }) + '\n' + JSON.stringify({ id: dispatch.id, result: {} }) };
    },
    out: x => out.push(x), err: x => errors.push(x)
  });
  return { code, out: out.join(''), errors: errors.join('\n'), calls, submitted };
}

test('spawn starts a hax live chat when asked for provider hax', async () => {
  const r = await spawn(['--provider', 'hax', '--task', 'take a ticket']);
  assert.equal(r.code, 0);
  assert.deepEqual(r.calls.find(a => a[1] === 'enable').slice(0, 3), ['host', 'enable', 'hax']);
  assert.ok(!r.calls.find(a => a[1] === 'enable').includes('--permission-mode'));
  assert.deepEqual(r.calls.find(a => a[1] === 'start'), ['host', 'start', 'hax', JSON.parse(r.out).sid]);
  assert.equal(r.submitted[0].provider, 'hax');
  assert.equal(JSON.parse(r.out).provider, 'hax');
});

test('spawn keeps claude as the default provider', async () => {
  const r = await spawn([]);
  assert.equal(r.code, 0);
  assert.deepEqual(r.calls.find(a => a[1] === 'enable').slice(0, 3), ['host', 'enable', 'claude']);
  assert.ok(r.calls.find(a => a[1] === 'enable').includes('bypassPermissions'));
});

for (const provider of ['codex', 'pi', 'antigravity']) {
  test(`spawn starts a ${provider} live chat when asked for provider ${provider}`, async () => {
    const r = await spawn(['--provider', provider, '--task', 'take a ticket']);
    assert.equal(r.code, 0, r.errors);
    const enable = r.calls.find(a => a[1] === 'enable');
    assert.deepEqual(enable.slice(0, 3), ['host', 'enable', provider]);
    assert.equal(enable[enable.indexOf('--permission-mode') + 1], 'bypassPermissions', `${provider} starts with full permissions`);
    assert.deepEqual(r.calls.find(a => a[1] === 'start').slice(0, 3), ['host', 'start', provider]);
    assert.equal(r.submitted[0].provider, provider);
    assert.equal(JSON.parse(r.out).provider, provider);
  });
}

test('open --kind chat reaches the same providers spawn does', async () => {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-open-provider-'));
  homes.push(home);
  const errors = [];
  const code = await run(['open', '--kind', 'chat', '--name', 'Chat', '--folder', 'work', '--workspace', 'Work', '--host', '0', '--provider', 'other'], {
    env: { HOME: home, MULTIPROMPT_KEY: 'private-key' },
    out: () => {}, err: line => errors.push(line)
  });
  assert.equal(code, 1);
  assert.match(errors.join('\n'), /provider must be one of: claude, codex, pi, antigravity, hax/);
});

test('spawn refuses an unknown provider and names the ones it takes', async () => {
  const r = await spawn(['--provider', 'other']);
  assert.equal(r.code, 1);
  assert.equal(r.errors, JSON.stringify({ ok: false, error: 'provider must be one of: claude, codex, pi, antigravity, hax' }));
});
