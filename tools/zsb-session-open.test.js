const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const test = require('node:test');
const os = require('node:os');
const { readChangelogFragment } = require('./changelog');

const root = path.resolve(__dirname, '..');
const wrapper = process.env.ZSB_WRAPPER_SH || path.join(__dirname, 'vps-multiprompt-browser.sh');
const args = ['session-open', '--workspace', 'Research', '--group', 'Ops', '--host', 'remote-1', '--tmux', 'runner-7', '--name', 'Agent 🧪'];

function cli(argv, port) {
  return new Promise((resolve, reject) => {
    const child = spawn('bash', [wrapper, ...argv], {
      env: { ...process.env, TMUX: '', ZSB_SESSION: '', ZSB_PORT: String(port) },
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

async function bridge(run, reply = { ok: true, created: true, tab: 42 }) {
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
  assert.match(wire, /^ZSB:workspace:[A-Za-z0-9+/=]+\n$/);
  return Buffer.from(wire.trim().split(':')[2], 'base64').toString().split('\x1f').slice(0, -1);
}

test('global and per-command help document workspace commands without session context or a tunnel', async () => {
  const help = await cli(['--help'], 1);
  assert.equal(help.code, 0);
  assert.match(help.stdout, /workspace-list/);
  assert.match(help.stdout, /session-open --workspace NAME --group NAME --host HOST --tmux SESSION --name TITLE/);
  for (const command of ['workspace-list', 'session-open']) {
    const result = await cli([command, '--help'], 1);
    assert.equal(result.code, 0);
    assert.match(result.stdout, new RegExp(`usage: zsb ${command}`));
    if (command === 'session-open') assert.match(result.stdout, /background/);
  }
});

test('CLI transport connects directly to the IPv4 bridge without localhost address fallback', () => {
  const source = fs.readFileSync(wrapper, 'utf8');
  assert.match(source, /socket\.create_connection\(\("127\.0\.0\.1", int\(port\)\), timeout=5\)/);
});

test('workspace-list sends a session-independent app request and preserves the complete JSON result', async () => {
  const reply = { ok: true, hosts: ['remote-1'], workspaces: [{ id: 0, name: 'Home', active: true, groups: [], tabs: [] }] };
  await bridge(async (port, requests) => {
    const result = await cli(['workspace-list'], port);
    assert.equal(result.code, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), reply);
    assert.deepEqual(requests.map(decoded), [['workspace-list']]);
  }, reply);
});

test('session-open preserves whitespace quotes Unicode and flag ordering without activation', async () => {
  const reordered = ['session-open', '--name', 'Agent "🧪" \\ tab', '--tmux', 'runner-7.alpha_2', '--host', 'remote-2', '--group', 'Ops team', '--workspace', 'Research lab'];
  await bridge(async (port, requests) => {
    const result = await cli(reordered, port);
    assert.equal(result.code, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { ok: true, created: true, tab: 42 });
    assert.deepEqual(requests.map(decoded), [reordered]);
    assert.ok(!decoded(requests[0]).includes('--activate'));
  });
});

test('session-open preserves existing replies with the tab workspace, even when it differs from the requested workspace', async () => {
  await bridge(async (port, requests) => {
    const result = await cli(args, port);
    assert.equal(result.code, 0, result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { ok: true, existing: true, tab: 42, workspace: 'Home' });
    assert.deepEqual(decoded(requests[0]), args);
  }, { ok: true, existing: true, tab: 42, workspace: 'Home' });
});

test('workspace commands reject missing duplicate unknown and extra arguments before contacting the bridge', async () => {
  await bridge(async (port, requests) => {
    const duplicate = [...args];
    duplicate[3] = '--workspace';
    for (const invalid of [['workspace-list', 'extra'], args.slice(0, -1), args.slice(0, -2), [...args, '--activate'], duplicate, [...args.slice(0, -2), '--unknown', 'x'], [...args.slice(0, -1), '']]) {
      const result = await cli(invalid, port);
      assert.equal(result.code, 1);
      assert.equal(JSON.parse(result.stdout).error, 'bad_args', result.stdout);
    }
    assert.equal(requests.length, 0);
  });
});

test('session-open rejects tmux command injection control delimiters and oversized names before transport', async () => {
  await bridge(async (port, requests) => {
    for (const tmux of ['space here', 'a;b', '$(id)', 'a:b', 'a/b', 'café', 'a'.repeat(64), 'a\x1fb']) {
      const invalid = [...args];
      invalid[8] = tmux;
      const result = await cli(invalid, port);
      assert.equal(result.code, 1);
      assert.ok(['invalid_tmux', 'bad_args'].includes(JSON.parse(result.stdout).error));
    }
    for (const title of ['a'.repeat(64), '🧪'.repeat(32), 'line\nbreak', 'a\x1fb', 'a\x7fb', 'a\u0085b']) {
      const result = await cli([...args.slice(0, -1), title], port);
      assert.equal(result.code, 1);
      assert.ok(['invalid_name', 'bad_args'].includes(JSON.parse(result.stdout).error));
    }
    assert.equal(requests.length, 0);
  });
});

test('session-open accepts exact tmux and UTF-16 title length boundaries', async () => {
  await bridge(async (port, requests) => {
    const valid = [...args];
    valid[8] = 'a'.repeat(63);
    valid[10] = '🧪'.repeat(31) + 'a';
    const result = await cli(valid, port);
    assert.equal(result.code, 0, result.stderr);
    assert.deepEqual(decoded(requests[0]), valid);
  });
});

for (const error of ['unknown_workspace', 'unknown_group', 'unknown_host']) {
  test(`session-open preserves ${error} and valid names without browser recovery advice`, async () => {
    const reply = { ok: false, error, valid_names: ['Valid name'] };
    await bridge(async port => {
      const result = await cli(args, port);
      assert.equal(result.code, 1);
      assert.deepEqual(JSON.parse(result.stdout), reply);
      assert.match(result.stderr, /workspace-list/);
      assert.doesNotMatch(result.stderr, /extension|browser pane/);
    }, reply);
  });
}

test('the production source map exposes the new commands and unchanged hand-made spawn entry point', () => {
  const source = require('./app-source').readAppSource();
  assert.match(source, /fn handleZsbWorkspaceRequest\(/);
  assert.match(source, /fn spawnShellWithSession\([^\n]+\) bool \{\s*if \(g_account_locked\) return false/);
  assert.match(source, /fn zsbSessionOpen\(/);
});

test('app dispatch precedes browser routing and uses the UI-thread workspace mailbox', () => {
  const source = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
  const worker = source.slice(source.indexOf('fn zsbWorkerThread('), source.indexOf('fn zsbBuildBridgeCmd('));
  assert.ok(worker.indexOf('sendZsbWorkspaceResponse(') < worker.indexOf('zsbStripAgentActivation('));
  assert.ok(worker.indexOf('sendZsbWorkspaceResponse(') < worker.indexOf('zsbSessionHasWebView2('));
  assert.match(source, /pub fn handleZsbWorkspaceRequest\(\)[\s\S]*g_zsb_workspace_mutex\.tryLock\(\)/);
  assert.match(source, /zsbSessionOpen\(args, out, @import\("console.zig"\)\.spawnBackgroundTmuxSession, saveSession\)/);
  const main = fs.readFileSync(path.join(root, 'src/main.zig'), 'utf8');
  assert.match(main, /WM_APP_ZSB_WORKSPACE => \{\s*@import\("browser_bridge.zig"\)\.handleZsbWorkspaceRequest\(\)/);
  assert.match(source, /test "session-open is idempotent and never changes active tab workspace or group expansion"/);
  assert.match(fs.readFileSync(path.join(root, 'build.zig'), 'utf8'), /"tools\/zsb-session-open.test.js"/);
});

test('background spawning reuses the hand-made path without switching or refocusing and retains global identity', () => {
  const source = fs.readFileSync(path.join(root, 'src/console.zig'), 'utf8');
  const start = source.indexOf('pub fn spawnShellWithSession(');
  const spawning = source.slice(start, source.indexOf('pub fn respawnShellInPlace(', start));
  const background = source.slice(source.indexOf('pub fn spawnBackgroundTmuxSession('), start);
  assert.match(background, /return spawnShellWithSession\(\.tmux, session, null, null\)/);
  assert.match(background, /g_pending_background_workspace = workspace/);
  assert.match(spawning, /const background_workspace = app_state.g_pending_background_workspace/);
  assert.match(spawning, /background_workspace != null\) @import\("win32.zig"\)\.SWP_NOACTIVATE/);
  assert.match(spawning, /if \(!app_state.g_restoring and background_workspace == null\) \{\s*if \(app_state.g_focus_user_action_tick != 0\) switchToShellByUser\(idx\) else switchToShell\(idx\);\s*requestShellRefocus/);
  assert.match(spawning, /if \(background_workspace\) \|workspace\| \{\s*app_state.shells\[idx\]\.workspace = workspace/);
  assert.match(spawning, /if \(findLocalTmuxTab\(app_state.g_pending_tmux_host, session\)\) \|existing\|/);
  assert.doesNotMatch(spawning, /SetForegroundWindow|SetFocus\(/);
});

test('session-open checks global identity before spawning and includes cross-workspace no-op Zig coverage', () => {
  const source = fs.readFileSync(path.join(root, 'src/browser_bridge.zig'), 'utf8');
  const open = source.slice(source.indexOf('fn zsbSessionOpen('), source.indexOf('pub fn handleZsbWorkspaceRequest('));
  assert.match(open, /if \(findLocalTmuxTab\(host, args.tmux\)\) \|existing\|/);
  const existing = open.slice(open.indexOf('if (findLocalTmuxTab('), open.indexOf('if (!spawn('));
  assert.match(existing, /workspaceDisplayName\(shell.workspace, &ws_buf\)/);
  assert.match(existing, /zsbAppendJsonString/);
  assert.match(existing, /return pos;/);
  assert.doesNotMatch(existing, /persist\(|switchToShell|shell\.\w+\s*=/);
  assert.match(source, /test "session-open returns existing across workspaces without changing tabs or active state"/);
  const regression = source.slice(source.indexOf('test "session-open returns existing across workspaces'), source.indexOf('test "session-open separates identical session names'));
  assert.match(regression, /args\[2\] = "Home"/);
  for (const field of ['shell_count', 'active_shell', 'g_active_workspace']) {
    assert.match(regression, new RegExp(`expectEqual\\([^\\n]+app_state\\.${field}\\)`));
  }
  assert.match(regression, /expectEqualDeep\(shells, app_state.shells\[0\.\.count\]\)/);
});

test('documentation and changelog cover both commands and their safety contract', () => {
  for (const file of ['docs-site/src/content/docs/docs/browser-pane-zsb.mdx', 'openwiki/browser/zsb-selftest.md']) {
    const text = fs.readFileSync(path.join(root, file), 'utf8');
    assert.match(text, /workspace-list/);
    assert.match(text, /session-open --workspace/);
    assert.match(text, /existing/);
    assert.match(text, /background/);
  }
  const fragment = readChangelogFragment('IGSH-535-session-open.md').trim();
  assert.equal(fragment.split('\n').length, 1);
  assert.match(fragment, /workspace/);
});

test('changelog lookup preserves pending text and the release script folds the same text by ticket', async t => {
  const { stampTree } = await import('./version-stamp.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'changelog-lookup-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const filename = 'DEMO-1-note.md';
  const fragmentPath = path.join('changelog.d', filename);
  const text = 'A workspace with "quotes", C:\\new and\ta tab.\nSecond line.\n';
  const files = {
    'src/main.zig': 'pub const APP_VERSION = "0.28.797";\n',
    'src/changelog.zig': 'pub const CHANGELOG = [_]ChangelogEntry{\n};\n',
    [fragmentPath.replaceAll(path.sep, '/')]: text,
  };
  fs.mkdirSync(path.join(dir, 'changelog.d'));
  fs.mkdirSync(path.join(dir, 'src'));
  fs.writeFileSync(path.join(dir, fragmentPath), text);
  assert.equal(readChangelogFragment(filename, dir), text);
  const stamp = stampTree(files);
  fs.writeFileSync(path.join(dir, 'src/changelog.zig'), stamp.files['src/changelog.zig']);
  fs.unlinkSync(path.join(dir, fragmentPath));
  assert.equal(readChangelogFragment(filename, dir), text);
  assert.throws(() => readChangelogFragment('DEMO-2-missing.md', dir), /Missing changelog fragment.*DEMO-2/);
  assert.throws(() => readChangelogFragment('../DEMO-1-note.md', dir), /Invalid changelog fragment filename/);
  fs.writeFileSync(path.join(dir, fragmentPath), 'Invalid pending text.\n');
  assert.equal(readChangelogFragment(filename, dir), 'Invalid pending text.\n');
  assert.throws(() => assert.match(readChangelogFragment(filename, dir), /workspace/), assert.AssertionError);
  fs.unlinkSync(path.join(dir, fragmentPath));
  fs.mkdirSync(path.join(dir, fragmentPath));
  assert.throws(() => readChangelogFragment(filename, dir), { code: 'EISDIR' });
});

test('tools tests use readChangelogFragment instead of directly reading fragment paths', () => {
  function check(source, file) {
    assert.doesNotMatch(source, /['"`]changelog\.d[\\/][^'"`]+\.md['"`]|(['"`])changelog\.d\1\s*,\s*['"`][^'"`]+\.md['"`]/,
      `${file}: use readChangelogFragment from tools/changelog.js so tests survive releases`);
  }
  const directory = 'changelog.d';
  const filename = 'DEMO-1-note.md';
  const fragment = `${directory}/${filename}`;
  for (const source of [
    `fs.readFileSync(path.join(root, '${fragment}'), 'utf8')`,
    `read('${fragment}')`,
    `fs.readFileSync(path.join(root, '${directory}', '${filename}'), 'utf8')`,
  ]) {
    assert.throws(() => check(source, 'positive-control.test.js'), /use readChangelogFragment/);
  }
  check(`readChangelogFragment('${filename}')`, 'helper-control.test.js');
  for (const file of fs.readdirSync(__dirname).filter(file => file.endsWith('.test.js'))) {
    check(fs.readFileSync(path.join(__dirname, file), 'utf8'), file);
  }
});

test('changed code contains no removable comments and the comment oracle rejects a positive control', async () => {
  const { tokenize } = await import('./strip-comments.mjs');
  assert.equal(tokenize('const x = 1; // forbidden\n', 'javascript').comments.length, 1);
  const files = ['build.zig', 'src/app_state.zig', 'src/browser_bridge.zig', 'src/console.zig', 'src/main.zig', 'src/win32.zig', 'tools/vps-multiprompt-browser.sh', 'tools/zsb-session-open.test.js', 'tools/changelog.js', 'tools/issue-493-tab-url-shortcut.test.js'];
  for (const file of files) {
    const language = file.endsWith('.zig') ? 'zig' : file.endsWith('.sh') ? 'shell' : 'javascript';
    const comments = tokenize(fs.readFileSync(path.join(root, file), 'utf8'), language).comments.filter(c => !c.reason);
    assert.equal(comments.length, 0, file);
  }
});
