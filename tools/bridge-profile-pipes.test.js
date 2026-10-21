const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const exe = path.resolve(root, process.env.BRIDGE_EXE || 'zig-out/bin/zigshell-bridge.exe');
const source = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const version = JSON.parse(fs.readFileSync(path.join(root, 'extension/manifest.json'), 'utf8')).version;
const legacyOrigin = 'chrome-extension://eakdogphfehclpdnjecifppkcnfjnheh/';
const isolatedOrigin = 'chrome-extension://fgclkhodglfogcckilgnihofmlpmiiao/';

function launch(args, profile, extraEnv = {}) {
  const env = { ...process.env, WINEDEBUG: '-all', ...extraEnv };
  delete env.MULTIPROMPT_BROWSER_PROFILE;
  if (profile !== undefined) env.MULTIPROMPT_BROWSER_PROFILE = profile;
  return spawn(process.platform === 'win32' ? exe : 'wine', process.platform === 'win32' ? args : [exe, ...args], {
    cwd: root, env, stdio: ['pipe', 'pipe', 'pipe'],
  });
}

async function cli(args, profile, extraEnv) {
  const child = launch(args, profile, extraEnv);
  let stdout = '', stderr = '';
  child.stdout.on('data', data => { stdout += data; });
  child.stderr.on('data', data => { stderr += data; });
  const timer = setTimeout(() => child.kill('SIGKILL'), 9000);
  const started = Date.now();
  try {
    const [status, signal] = await once(child, 'exit');
    assert.equal(signal, null, stderr);
    return { status, stdout, stderr, elapsed: Date.now() - started };
  } finally {
    clearTimeout(timer);
  }
}

class Host {
  constructor(profile, label, args = ['native']) {
    this.child = launch(args, profile);
    this.label = label;
    this.requests = [];
    this.buffer = Buffer.alloc(0);
    this.stderr = '';
    this.exit = once(this.child, 'exit');
    const deadline = Date.now() + 15000;
    let timer;
    this.ready = new Promise((resolve, reject) => {
      timer = setTimeout(() => reject(new Error(`host startup timed out: ${this.stderr}`)), 15000);
      this.child.once('error', reject);
      this.child.once('exit', code => reject(new Error(`host exited ${code}: ${this.stderr}`)));
      this.child.stdout.on('data', data => {
        this.buffer = Buffer.concat([this.buffer, data]);
        while (this.buffer.length >= 4 && this.buffer.length >= 4 + this.buffer.readUInt32LE(0)) {
          const length = this.buffer.readUInt32LE(0);
          const message = JSON.parse(this.buffer.subarray(4, 4 + length));
          this.buffer = this.buffer.subarray(4 + length);
          if (message.bridgeVersion && !message.method) {
            assert.equal(message.bridgeVersion, version);
            resolve();
          } else {
            this.requests.push(message);
            const payload = Buffer.from(JSON.stringify({
              id: message.id, replyPipe: message.replyPipe, ok: true, extensionVersion: version,
              result: { profile: this.label, windowId: message.windowId },
            }));
            const header = Buffer.alloc(4);
            header.writeUInt32LE(payload.length);
            this.child.stdin.write(Buffer.concat([header, payload]));
          }
        }
      });
    }).then(async () => {
      if (process.platform !== 'win32') return;
      const pipe = args[0] === legacyOrigin ? 'zigshell-browser' : `multiprompt-browser-isolated${profile ? `-${profile}` : ''}`;
      while (Date.now() < deadline) {
        if (this.child.exitCode !== null || this.child.signalCode !== null) {
          throw new Error(`host exited before pipe readiness: ${this.stderr}`);
        }
        if ((await fs.promises.readdir('\\\\.\\pipe\\')).includes(pipe)) return;
        await new Promise(resolve => setTimeout(resolve, 50));
      }
      throw new Error(`host pipe startup timed out (${pipe}): ${this.stderr}`);
    }).finally(() => clearTimeout(timer));
    this.child.stderr.on('data', data => { this.stderr += data; });
  }

  async close() {
    this.child.stdin.end();
    const timer = setTimeout(() => this.child.kill('SIGKILL'), 5000);
    try {
      const [code, signal] = await this.exit;
      assert.equal(signal, null, this.stderr);
      assert.equal(code, 0, this.stderr);
    } finally {
      clearTimeout(timer);
    }
  }
}

test('issue: CLI rejects invalid profile tokens before transport and names the rule', async () => {
  for (const token of ['Upper', '-leading', '..\\x', 'a/b', 'a_b', 'a b', 'a'.repeat(33), 'x'.repeat(1024), 'bad"token', 'prófíl', 'profile😀']) {
    for (const args of [['tabs'], ['--profile', token, 'tabs']]) {
      const result = await cli(args, token);
      assert.notEqual(result.status, 0);
      const reply = JSON.parse(result.stdout);
      assert.equal(reply.ok, false);
      assert.ok(reply.error.includes(token), reply.error);
      assert.match(reply.error, /1 to 32.*\[a-z0-9-\].*not starting with '-'/);
      assert.ok(result.elapsed < 10000);
    }
  }
  const missing = await cli(['--profile']);
  assert.equal(missing.status, 2);
  assert.match(JSON.parse(missing.stdout).message, /^usage: --profile/);
  for (const args of [[], ['native'], [isolatedOrigin]]) {
    const result = await cli(args, 'Invalid');
    assert.notEqual(result.status, 0);
    assert.equal(result.stdout, '');
  }
});

test('issue: real host pipes isolate profiles, preserve default, and serialize duplicate hosts', { timeout: 30000 }, async () => {
  const token = `issue-375-${process.pid}`;
  const hosts = [];
  function host(profile, label, args) {
    const value = new Host(profile, label, args);
    hosts.push(value);
    return value;
  }
  const defaultHost = host(undefined, 'default', []);
  const first = host(token, 'first', [isolatedOrigin]);
  const other = host(`${token}-b`, 'other');
  const legacy = host('Invalid', 'legacy', [legacyOrigin]);
  try {
    await Promise.all(hosts.map(value => value.ready));
    async function expectProfile(args, env, label, windowId) {
      const result = await cli(args, env);
      assert.equal(result.status, 0, result.stderr);
      const reply = JSON.parse(result.stdout);
      assert.equal(reply.ok, true, result.stdout);
      assert.equal(reply.result.profile, label);
      if (windowId !== undefined) assert.equal(reply.result.windowId, windowId);
    }
    await expectProfile(['tabs'], undefined, 'default');
    await expectProfile(['tabs'], '', 'default');
    await expectProfile(['tabs'], token, 'first');
    await expectProfile(['--window', '42', '--profile', token, 'tabs'], 'Invalid', 'first', 42);
    await expectProfile(['--profile', `${token}-b`, '--window', '43', 'tabs'], token, 'other', 43);
    await expectProfile(['--profile', '', 'tabs'], token, 'default');
    const longest = await cli(['--profile', 'a'.repeat(32), 'version']);
    assert.equal(longest.status, 0);
    assert.equal(longest.stdout.trim(), version);
    const defaultRequests = defaultHost.requests.length;
    const unknown = `${token}-missing`;
    const missing = await cli(['--profile', unknown, 'tabs'], token);
    const reply = JSON.parse(missing.stdout);
    assert.equal(reply.ok, false);
    assert.ok(reply.error.includes(unknown), reply.error);
    assert.ok(missing.elapsed < 10000);
    assert.equal(defaultHost.requests.length, defaultRequests);
    assert.equal(legacy.requests.length, 0);
    const second = host(token, 'second');
    const waiting = await Promise.race([second.ready.then(() => 'served'), new Promise(resolve => setTimeout(() => resolve('blocked'), 300))]);
    assert.equal(waiting, 'blocked');
    await expectProfile(['tabs'], token, 'first');
    await first.close();
    hosts.splice(hosts.indexOf(first), 1);
    await second.ready;
    await expectProfile(['tabs'], token, 'second');
    const third = host(token, 'third');
    const abandonedWait = await Promise.race([third.ready.then(() => 'served'), new Promise(resolve => setTimeout(() => resolve('blocked'), 300))]);
    assert.equal(abandonedWait, 'blocked');
    second.child.kill('SIGKILL');
    await second.exit;
    hosts.splice(hosts.indexOf(second), 1);
    await third.ready;
    await expectProfile(['tabs'], token, 'third');
    const duplicateDefault = host('', 'duplicate-default');
    await duplicateDefault.ready;
    assert.equal(defaultHost.requests.length, defaultRequests);
  } finally {
    for (const value of hosts) await value.close();
  }
});

test('CLI waits for a delayed profile pipe and handles immediate replies', { timeout: 15000 }, async () => {
  const token = `pipe-ready-${process.pid}`;
  const pending = cli(['--profile', token, 'tabs']);
  await new Promise(resolve => setTimeout(resolve, 750));
  const host = new Host(token, 'delayed');
  try {
    await host.ready;
    const first = await pending;
    assert.equal(first.status, 0, first.stderr);
    assert.equal(JSON.parse(first.stdout).ok, true, first.stdout);
    for (let index = 0; index < 20; index++) {
      const result = await cli(['--profile', token, 'tabs']);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(JSON.parse(result.stdout).result?.profile, 'delayed', result.stdout);
    }
    assert.equal(host.requests.length, 21);
  } finally {
    await pending;
    await host.close();
  }
});

test('ISSUE-154 transport uses a deadline without blocking the host on unread replies', () => {
  const request = source.slice(source.indexOf('fn requestBrowser('), source.indexOf('fn saveScreenshotResponse('));
  assert.match(request, /const connect_until = @min\(until, GetTickCount64\(\) \+ 1500\)/);
  assert.match(request, /if \(remaining == 0\) return if \(GetTickCount64\(\) >= until\) error\.BrowserRequestTimeout else error\.PipeUnavailable/);
  assert.match(request, /WaitNamedPipeA\(command_pipe_name\.ptr, @intCast\(@min\(50, remaining\)\)\)/);
  const reply = source.slice(source.indexOf('fn routeReplyPipe('), source.indexOf('fn readPipeMessage('));
  assert.match(reply, /defer _ = CloseHandle\(pipe\);[\s\S]*SetNamedPipeHandleState\(pipe, &mode, null, null\)[\s\S]*writeAll\(pipe, payload\) catch \{\};/);
});

test('issue: source preserves token-only lifetime mutex and shared pipe resolver', () => {
  assert.match(source, /fn isolatedPipeName\(buf: \[\]u8, token: \[\]const u8\) !\[:0\]const u8/);
  assert.equal((source.match(/try isolatedPipeName\(&pipe_name_buf, g_profile_token\)/g) || []).length, 1);
  assert.match(source, /const profile_pipe_name = isolatedPipeName\(&pipe_name_buf, g_profile_token\)/);
  assert.match(source, /const profile_mutex = if \(g_profile_token\.len > 0\)[\s\S]*?CreateMutexA\(null, 0, name\.ptr\)[\s\S]*?WaitForSingleObject\(mutex, if \(workspace_profile\.isWorkspaceToken\(g_profile_token\)\) 0 else 0xFFFFFFFF\)[\s\S]*?wait != 0 and wait != 0x80/);
  assert.ok(source.indexOf('defer if (profile_mutex)') < source.indexOf('std.Thread.spawn(.{}, runPipeServer'));
  assert.match(source, /g_profile_token = if \(is_legacy_host\) "" else profile_override orelse profile_env/);
  assert.match(fs.readFileSync(path.join(root, 'build.zig'), 'utf8'), /const bridge_tests = b\.addTest\(\.\{ \.root_module = bridge_exe\.root_module \}\);[\s\S]*test_step\.dependOn\(&run_bridge_tests\.step\);[\s\S]*b\.step\("test-bridge"/);
});

test('IGSH-224 workspace registrations reject duplicates and never route an unknown token to another profile', { timeout: 30000 }, async () => {
  const suffix = process.pid.toString(16).padStart(30, '0');
  const token = `e-${suffix}`;
  const otherToken = `c-${suffix}`;
  const first = new Host(token, 'workspace-edge');
  const other = new Host(otherToken, 'workspace-chrome');
  try {
    await Promise.all([first.ready, other.ready]);
    const duplicate = await cli(['native'], token);
    assert.notEqual(duplicate.status, 0);
    assert.match(duplicate.stderr, /ProfileAlreadyRegistered/);
    const replies = await Promise.all([
      cli(['--window', '42', 'tabs'], token),
      cli(['--window', '42', 'tabs'], otherToken),
    ]);
    assert.equal(JSON.parse(replies[0].stdout).result.profile, 'workspace-edge');
    assert.equal(JSON.parse(replies[1].stdout).result.profile, 'workspace-chrome');
    assert.equal(first.requests.length, 1);
    assert.equal(other.requests.length, 1);
    const unknown = await cli(['tabs'], `e-${'f'.repeat(30)}`);
    assert.equal(JSON.parse(unknown.stdout).ok, false);
    assert.equal(first.requests.length, 1);
    assert.equal(other.requests.length, 1);
  } finally {
    await first.close();
    await other.close();
  }
  const stale = await cli(['tabs'], token);
  assert.equal(JSON.parse(stale.stdout).ok, false);
});

test('IGSH-224 local CLI snapshots the bound window and profile and rejects incomplete bindings', { timeout: 30000 }, async () => {
  const os = require('node:os');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh224-local-binding-'));
  const binding = path.join(dir, 'window.txt');
  const token = `e-${process.pid.toString(16).padStart(30, '1')}`;
  const otherToken = `c-${process.pid.toString(16).padStart(30, '1')}`;
  const first = new Host(token, 'local-workspace');
  const other = new Host(otherToken, 'other-local-workspace');
  const env = { BROWSER_CLI_WINDOW_FILE: binding, BROWSER_CLI_WINDOW: '' };
  try {
    await Promise.all([first.ready, other.ready]);
    fs.writeFileSync(binding, `42\n${token}\n`);
    const firstReply = await cli(['tabs'], undefined, env);
    assert.equal(JSON.parse(firstReply.stdout).result.profile, 'local-workspace');
    assert.equal(JSON.parse(firstReply.stdout).result.windowId, 42);
    fs.writeFileSync(binding, `42\n${otherToken}\n`);
    const secondReply = await cli(['tabs'], undefined, env);
    assert.equal(JSON.parse(secondReply.stdout).result.profile, 'other-local-workspace');
    for (const invalid of ['42\n', '42\nInvalid\n', `0\n${token}\n`, 'partial']) {
      fs.writeFileSync(binding, invalid);
      const result = await cli(['tabs'], undefined, env);
      assert.notEqual(result.status, 0);
      assert.equal(JSON.parse(result.stdout).ok, false);
      assert.match(JSON.parse(result.stdout).error, /workspace profile binding/);
    }
    fs.rmSync(binding);
    const missing = await cli(['tabs'], undefined, env);
    assert.notEqual(missing.status, 0);
    assert.equal(first.requests.length, 1);
    assert.equal(other.requests.length, 1);
  } finally {
    await first.close();
    await other.close();
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
