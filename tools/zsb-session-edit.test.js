const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const test = require('node:test');
const { readChangelogEntry } = require('./changelog-entry');

const root = path.resolve(__dirname, '..');
const wrapper = process.env.ZSB_WRAPPER_SH || path.join(__dirname, 'vps-multiprompt-browser.sh');
const verbs = ['session-close', 'session-rebind', 'session-rename', 'session-move'];

function cli(argv, port) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [wrapper, ...argv], {
      env: { ...process.env, MULTIPROMP_NOTIFY_RELAY_TOKEN: 'relay-test-token', TMUX: '', ZSB_SESSION: '', ZSB_PORT: String(port) },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '', stderr = '';
    let timedOut = false;
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGKILL');
    }, 30000);
    child.once('error', error => {
      clearTimeout(timer);
      reject(error);
    });
    child.once('close', (code, signal) => {
      clearTimeout(timer);
      if (timedOut || signal) {
        reject(new Error(`zsb ${argv[0]} ${timedOut ? 'timed out' : `received ${signal}`}: stdout=${stdout} stderr=${stderr}`));
        return;
      }
      resolve({ code, stdout, stderr });
    });
  });
}

async function bridge(run, reply = { ok: true, tab: 42 }) {
  const requests = [];
  const sockets = new Set();
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    let wire = '';
    socket.on('data', chunk => {
      wire += chunk;
      if (!wire.endsWith('\n')) return;
      requests.push(wire);
      socket.end(JSON.stringify(reply) + '\n');
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(server.address().port, requests);
  } finally {
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  }
}

function decoded(wire) {
  assert.match(wire, /^AUTH:relay-test-token:ZSB:workspace:[A-Za-z0-9+/=]+\n$/);
  return Buffer.from(wire.trim().split(':')[4], 'base64').toString().split('\x1f').slice(0, -1);
}

test('global and per-command help document the tab repair commands without a tunnel', async () => {
  const help = await cli(['--help'], 1);
  assert.equal(help.code, 0);
  assert.match(help.stdout, /session-close --tab ID/);
  assert.match(help.stdout, /session-rebind --tab ID \[--host HOST\] --tmux SESSION/);
  assert.match(help.stdout, /session-rename --tab ID --name TITLE/);
  assert.match(help.stdout, /session-move --tab ID \[--workspace NAME\] \[--group NAME \| --ungrouped\]/);
  for (const verb of verbs) {
    const result = await cli([verb, '--help'], 1);
    assert.equal(result.code, 0);
    assert.match(result.stdout, new RegExp(`usage: zsb ${verb}`));
    const short = await cli([verb, '-h'], 1);
    assert.equal(short.code, 0);
    assert.equal(short.stdout, result.stdout);
  }
  assert.match((await cli(['session-close', '--help'], 1)).stdout, /active_tab/);
  assert.match((await cli(['session-rebind', '--help'], 1)).stdout, /duplicate_session/);
});

const valid = [
  ['session-close', '--tab', '42'],
  ['session-rename', '--name', 'Runner "🧪" \\ 7', '--tab', '42'],
  ['session-rebind', '--tab', '42', '--tmux', 'runner-9.alpha_2'],
  ['session-rebind', '--tmux', 'runner-9', '--host', 'remote-2', '--tab', '4294967295'],
  ['session-move', '--tab', '42', '--workspace', 'Research lab'],
  ['session-move', '--tab', '42', '--group', 'Ops team'],
  ['session-move', '--group', 'Ops team', '--workspace', 'Research lab', '--tab', '42'],
  ['session-move', '--tab', '42', '--ungrouped'],
  ['session-move', '--ungrouped', '--workspace', 'Home', '--tab', '42'],
];

for (const argv of valid) {
  test(`${argv.join(' ')} reaches the app unchanged over the session-independent wire`, async () => {
    const reply = { ok: true, tab: 42, state: 'connecting' };
    await bridge(async (port, requests) => {
      const result = await cli(argv, port);
      assert.equal(result.code, 0, result.stderr);
      assert.deepEqual(JSON.parse(result.stdout), reply);
      assert.deepEqual(requests.map(decoded), [argv]);
      assert.ok(!decoded(requests[0]).includes('--activate'));
    }, reply);
  });
}

test('tab repair commands reject missing duplicate unknown and malformed arguments before transport', async () => {
  const invalid = [
    ['session-close'], ['session-close', '--tab'], ['session-close', '--tab', '42', 'extra'],
    ['session-close', '--tab', '42', '--tab', '43'], ['session-close', '--tab', '42', '--name', 'x'],
    ['session-close', '--unknown', '42'],
    ...['', '0', '-1', '+1', ' 42', '42 ', '1_0', '1.0', '0x2a', '4294967296', '４２', '42\x1f'].flatMap(tab => verbs.map(verb => {
      const rest = { 'session-close': [], 'session-rename': ['--name', 'x'], 'session-rebind': ['--tmux', 'a'], 'session-move': ['--ungrouped'] }[verb];
      return [verb, '--tab', tab, ...rest];
    })),
    ['session-rename', '--tab', '42'], ['session-rename', '--name', 'x'], ['session-rename', '--tab', '42', '--name', ''],
    ['session-rename', '--tab', '42', '--workspace', 'Home', '--name', 'x'],
    ['session-rebind', '--tab', '42'], ['session-rebind', '--tmux', 'runner-9'], ['session-rebind', '--tab', '42', '--tmux', ''],
    ['session-rebind', '--tab', '42', '--tmux', 'a', '--tmux', 'b'], ['session-rebind', '--tab', '42', '--tmux', 'a', '--group', 'Ops'],
    ['session-move', '--tab', '42'], ['session-move', '--tab', '42', '--workspace'],
    ['session-move', '--tab', '42', '--group', 'Ops', '--ungrouped'], ['session-move', '--tab', '42', '--ungrouped', '--ungrouped'],
    ['session-move', '--tab', '42', '--workspace', ''], ['session-move', '--tab', '42', '--host', 'remote-1'],
    ['session-move', '--tab', '42', '--workspace', 'Home\nEvil'],
  ];
  await bridge(async (port, requests) => {
    for (const argv of invalid) {
      const result = await cli(argv, port);
      assert.equal(result.code, 1, JSON.stringify(argv));
      assert.equal(JSON.parse(result.stdout).error, 'bad_args', JSON.stringify(argv));
    }
    assert.equal(requests.length, 0);
  });
});

test('session-rebind and session-rename reject tmux injection and oversized titles before transport', async () => {
  await bridge(async (port, requests) => {
    for (const tmux of ['space here', 'a;b', '$(id)', 'a:b', 'a/b', 'café', 'a'.repeat(64), 'a\x1fb']) {
      const result = await cli(['session-rebind', '--tab', '42', '--tmux', tmux], port);
      assert.equal(result.code, 1);
      assert.ok(['invalid_tmux', 'bad_args'].includes(JSON.parse(result.stdout).error));
    }
    for (const title of ['a'.repeat(64), '🧪'.repeat(32), 'line\nbreak', 'a\x1fb', 'a\x7fb', 'a\u0085b']) {
      const result = await cli(['session-rename', '--tab', '42', '--name', title], port);
      assert.equal(result.code, 1);
      assert.ok(['invalid_name', 'bad_args'].includes(JSON.parse(result.stdout).error));
    }
    assert.equal(requests.length, 0);
  });
});

test('tab repair commands accept exact tmux and UTF-16 title length boundaries', async () => {
  await bridge(async (port, requests) => {
    const rebind = ['session-rebind', '--tab', '42', '--tmux', 'a'.repeat(63)];
    const rename = ['session-rename', '--tab', '42', '--name', '🧪'.repeat(31) + 'a'];
    for (const argv of [rebind, rename]) {
      const result = await cli(argv, port);
      assert.equal(result.code, 0, result.stderr);
    }
    assert.deepEqual(requests.map(decoded), [rebind, rename]);
  });
});

for (const reply of [
  { ok: false, error: 'active_tab' },
  { ok: false, error: 'pinned_tab' },
  { ok: false, error: 'unknown_tab' },
  { ok: false, error: 'duplicate_session', tab: 43 },
  { ok: false, error: 'workspace_snoozed' },
  { ok: false, error: 'account_locked' },
  { ok: false, error: 'not_remote_tab' },
  { ok: false, error: 'unknown_workspace', valid_names: ['Home'] },
  { ok: false, error: 'unknown_group', valid_names: ['Ops'] },
  { ok: false, error: 'unknown_host', valid_names: ['remote-1'] },
]) {
  test(`app refusal ${reply.error} is preserved with a nonzero exit and no browser advice`, async () => {
    await bridge(async port => {
      const result = await cli(['session-move', '--tab', '42', '--ungrouped'], port);
      assert.equal(result.code, 1);
      assert.deepEqual(JSON.parse(result.stdout), reply);
      assert.match(result.stderr, /workspace-list/);
      assert.doesNotMatch(result.stderr, /extension|browser pane/);
    }, reply);
  });
}

test('app dispatch runs the tab repair verbs on the UI thread through the workspace mailbox', () => {
  const source = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
  const worker = source.slice(source.indexOf('fn zsbWorkerThread('), source.indexOf('fn zsbBuildBridgeCmd('));
  assert.ok(worker.indexOf('zsbIsTabVerb(argv[0])') > 0);
  assert.ok(worker.indexOf('sendZsbWorkspaceResponse(') < worker.indexOf('zsbStripAgentActivation('));
  const handler = source.slice(source.indexOf('pub fn handleZsbWorkspaceRequest('), source.indexOf('fn sendZsbWorkspaceResponse('));
  assert.match(handler, /zsbIsTabVerb\(args\[0\]\)\)\s*zsbTabCommand\(args, out, ZsbTabOps\)/);
  for (const verb of verbs) {
    assert.ok(source.includes(`"${verb}"`), verb);
  }
  const ops = source.slice(source.indexOf('const ZsbTabOps = struct'), source.indexOf('fn zsbIsTabVerb('));
  assert.match(ops, /closeShell\(idx\)/);
  assert.match(ops, /respawnShellInPlace\(idx, true\)/);
  assert.match(ops, /commitPillMove\(workspace, false\)/);
  assert.doesNotMatch(ops, /switchTo|SetForegroundWindow|SetFocus\(|ShowWindow\(/);
});

test('the tab repair verbs refuse the active tab and ship Zig coverage for every refusal', () => {
  const source = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
  const close = source.slice(source.indexOf('fn zsbTabClose('), source.indexOf('fn zsbTabRename('));
  const move = source.slice(source.indexOf('fn zsbTabMove('), source.indexOf('fn zsbTabRebind('));
  for (const body of [close, move]) assert.match(body, /idx == app_state\.active_shell\) return zsbWorkspaceError\(out, "active_tab"\)/);
  for (const name of [
    'tab verbs reject malformed arguments before touching any tab',
    'session-close removes a background tab and refuses the active, pinned and unknown tab',
    'session-rename sets a manual title with Unicode and keeps the active tab',
    'session-move changes workspace and group by name and refuses the active tab and unknown names',
    'session-rebind points a tab at another session and refuses duplicates locked accounts and local tabs',
  ]) assert.ok(source.includes(`test "${name}"`), name);
  assert.match(source, /state\\":null/);
});

test('documentation and changelog cover the tab repair commands and their safety contract', () => {
  for (const file of ['docs-site/src/content/docs/docs/browser-pane-zsb.mdx', 'openwiki/browser/zsb-selftest.md']) {
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    for (const verb of verbs) assert.match(text, new RegExp(verb), `${file} ${verb}`);
    assert.match(text, /active_tab/);
    assert.match(text, /duplicate_session/);
  }
  const fragment = readChangelogEntry('IGSH-988').trim();
  assert.equal(fragment.split('\n').length, 1);
  assert.match(fragment, /tabs/);
});

test('changed code contains no removable comments', async () => {
  const { tokenize } = await import('./strip-comments.mjs');
  for (const file of ['src/browser_bridge.zig', 'src/workspaces.zig', 'tools/vps-multiprompt-browser.sh', 'tools/zsb-session-edit.test.js']) {
    const language = file.endsWith('.zig') ? 'zig' : file.endsWith('.sh') ? 'shell' : 'javascript';
    const comments = tokenize(fs.readFileSync(path.join(root, file), 'utf8'), language).comments.filter(c => !c.reason);
    assert.equal(comments.length, 0, file);
  }
});
