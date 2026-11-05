const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');

const unix = process.platform !== 'win32';

test('real flock and reader config/message storage converge without forwarding the account key', { skip: !unix }, async t => {
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-spawn-adapters-'));
  t.after(() => fs.rmSync(home, { recursive: true, force: true }));
  const reader = path.join(home, 'reader.py');
  fs.writeFileSync(reader, [
    'import json,os,runpy,sys',
    'assert "MULTIPROMPT_KEY" not in os.environ',
    `reader = runpy.run_path(${JSON.stringify(path.resolve('src/chat_history_reader.py'))})`,
    'if sys.argv[1:3] == ["host", "enable"]:',
    '    print(json.dumps(reader["host_cli"](sys.argv[2:])))',
    'elif sys.argv[1:3] == ["host", "start"]:',
    '    print(json.dumps(dict(status="started")))',
    'else:',
    '    assert sys.argv[1:] == ["--serve"]',
    '    for line in sys.stdin:',
    '        query = json.loads(line)',
    '        if query["op"] == "message_submit":',
    '            result = reader["message_store_request"](query)',
    '        else:',
    '            assert query["op"] == "message_dispatch"',
    '            result = dict(message=None)',
    '        print(json.dumps(dict(id=query["id"], result=result)))',
  ].join('\n'));
  let layout = { workspaces: [{ name: 'Work' }], tabs: [] }, revision = 0, parked = false, marker;
  const output = [], errors = [];
  const opts = {
    env: { HOME: home, PATH: process.env.PATH, MULTIPROMPT_KEY: 'must-not-reach-reader', MULTIPROMPT_READER: reader },
    out: line => output.push(JSON.parse(line)), err: line => errors.push(line),
    fetch: async (_, request) => {
      if (request.method === 'GET') return { status: 200, json: async () => ({ revision, layout: structuredClone(layout) }) };
      const body = JSON.parse(request.body);
      assert.equal(body.base_revision, revision);
      layout = body.layout; revision++;
      return { status: 200, json: async () => ({ revision }) };
    },
    tmux: args => {
      if (args[0] === 'has-session') return { status: parked ? 0 : 1 };
      if (args[0] === 'display-message') return { status: 0, stdout: `sleep\t${home}\t${marker}` };
      marker = args.at(-1); parked = true; return { status: 0 };
    }
  };
  const args = ['spawn', '--name', 'Adapter chat', '--folder', home, '--workspace', 'Work', '--task', 'one durable task'];
  assert.deepEqual(await Promise.all([run(args, opts), run(args, opts)]), [0, 0], errors.join('\n'));
  assert.equal(layout.tabs.length, 1);
  assert.equal(revision, 1);
  assert.equal(output[0].sid, output[1].sid);
  const key = crypto.createHash('sha256').update('claude:' + output[0].sid).digest('hex').slice(0, 32);
  const config = JSON.parse(fs.readFileSync(path.join(home, '.local/state/multiprompt/agent-host', key + '.config.json')));
  assert.equal(config.enabled, true);
  assert.equal(config.spawn_name, 'adapter chat');
  assert.equal(config.spawn_workspace, 'Work');
  assert.equal(config.permission_mode, 'bypassPermissions');
  assert.equal(await run([...args.slice(0, -1), 'changed task'], opts), 1);
  assert.equal(await run(args, opts), 0, errors.join('\n'));
});

test('real tmux parking markers survive repeated visible spawn', { skip: !unix }, async t => {
  const { spawnSync } = require('node:child_process');
  const { run } = await import('./mp-layout.mjs');
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-spawn-tmux-'));
  const socket = 'mp-spawn-' + crypto.randomBytes(12).toString('hex');
  const tmux = args => spawnSync('tmux', ['-L', socket, ...args], { encoding: 'utf8', timeout: 10000, env: { HOME: home, PATH: process.env.PATH } });
  t.after(() => { tmux(['kill-server']); fs.rmSync(home, { recursive: true, force: true }); });
  assert.equal(spawnSync('tmux', ['-V']).status, 0, 'hosted Unix proof requires tmux');
  let layout = { workspaces: [{ name: 'Work' }], tabs: [] }, revision = 0;
  const output = [], errors = [];
  const opts = {
    env: { HOME: home, PATH: process.env.PATH, MULTIPROMPT_KEY: 'fixture-only' },
    out: line => output.push(JSON.parse(line)), err: line => errors.push(line),
    fetch: async (_, request) => {
      if (request.method === 'GET') return { status: 200, json: async () => ({ revision, layout: structuredClone(layout) }) };
      const body = JSON.parse(request.body);
      assert.equal(body.base_revision, revision);
      layout = body.layout; revision++;
      return { status: 200, json: async () => ({ revision }) };
    },
    tmux,
    runtime: args => ({ status: 0, stdout: JSON.stringify({ status: args[1] === 'enable' ? 'enabled' : 'started' }) })
  };
  const args = ['spawn', '--name', 'Real parking', '--folder', home, '--workspace', 'Work'];
  assert.equal(await run(args, opts), 0, errors.join('\n'));
  assert.equal(await run(args, opts), 0, errors.join('\n'));
  assert.equal(output[0].sid, output[1].sid);
  assert.equal(layout.tabs.length, 1);
  assert.equal(revision, 1);
  const markers = tmux(['display-message', '-p', '-t', '=' + output[0].session + ':', '#{@mp_spawn_sid}|#{@mp_host_sid}']);
  assert.equal(markers.status, 0, markers.stderr);
  assert.equal(markers.stdout.trim(), output[0].sid + '|' + output[0].sid);
});
