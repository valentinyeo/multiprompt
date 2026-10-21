const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'src/bridge.zig'), 'utf8');
const dispatch = source.slice(source.indexOf('pub fn main('), source.indexOf('const usage_text ='));
const commands = [...new Set([...dispatch.matchAll(/std\.mem\.eql\(u8, command, "([\w-]+)"\)/g)].map(match => match[1]).filter(command => !command.startsWith('-')))];
assert.ok(commands.includes('cdp') && commands.includes('profile-clone') && commands.includes('native'));

function cli(exe, args, env) {
  return new Promise((resolve, reject) => {
    const child = spawn(exe, args, { env, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.once('error', reject);
    const timer = setTimeout(() => child.kill('SIGKILL'), 5000);
    child.once('close', (status, signal) => {
      clearTimeout(timer);
      resolve({ status, signal, stdout, stderr });
    });
    child.stdin.end();
  });
}

test('every native zsb command and alias answers both help flags without transport or files', { timeout: 120000 }, async t => {
  assert.equal(process.platform, 'win32', 'Run this executable sweep on GitHub Windows, never via Wine');
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-help-'));
  const exe = path.join(directory, 'zsb.exe');
  fs.copyFileSync(process.env.BRIDGE_EXE || path.join(root, 'zig-out/bin/zigshell-bridge.exe'), exe);
  const profile = `help-${process.pid}`;
  let requests = 0, notifications = 0;
  const sockets = new Set();
  const track = socket => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    socket.on('error', () => {});
  };
  const bridge = net.createServer(socket => {
    track(socket);
    requests++;
    let data = '';
    socket.on('data', chunk => {
      data += chunk;
      let request;
      try { request = JSON.parse(data); } catch { return; }
      const reply = net.createConnection(request.replyPipe, () => reply.end('{"ok":true,"result":{}}'));
      track(reply);
    });
  });
  const notify = net.createServer(socket => {
    track(socket);
    notifications++;
    socket.resume();
  });
  bridge.listen(`\\\\.\\pipe\\multiprompt-browser-isolated-${profile}`);
  await once(bridge, 'listening');
  notify.listen(0, '127.0.0.1');
  await once(notify, 'listening');
  const env = { ...process.env, MULTIPROMPT_BROWSER_PROFILE: profile, BROWSER_CLI_WINDOW: '42',
    ZIGSHELL_NOTIFY_PORT: String(notify.address().port), ZIGSHELL_SHELL_ID: '1' };
  delete env.BROWSER_CLI_WINDOW_FILE;
  try {
    assert.equal((await cli(exe, ['tabs'], env)).status, 0);
    assert.equal((await cli(exe, ['open', 'https://example.test'], env)).status, 0);
    assert.equal(requests, 1, 'positive control must reach the bridge');
    assert.equal(notifications, 1, 'positive control must reach the app');
    requests = notifications = 0;
    const help = await cli(exe, ['help'], env);
    const listed = [...(help.stdout + help.stderr).matchAll(/^  ([\w-]+)(?: |$)/gm)].map(match => match[1]);
    for (const command of listed.filter(command => !command.startsWith('--'))) {
      assert.ok(commands.includes(command), `Help lists an untested command: ${command}`);
    }
    const invocations = [...commands.map(command => [command]), ['tab', 'close'], ['tabs', '--close']];
    for (const invocation of invocations) {
      for (const flag of ['--help', '-h']) {
        await t.test(`${invocation.join(' ')} ${flag}`, async () => {
          const result = await cli(exe, [...invocation, flag], env);
          assert.equal(result.signal, null, 'help must not hang');
          assert.equal(result.status, 0, result.stdout + result.stderr);
          const output = result.stdout + result.stderr;
          assert.match(output, /^usage: /);
          assert.ok(output.includes(invocation[0]), output);
          assert.doesNotMatch(output, /"ok"|bad_args|-32601|not found|PipeUnavailable/);
          if (invocation[0] === 'cdp') {
            assert.match(output, /cdp <method> \[params-json\]/);
            assert.match(output, /Examples:/);
            assert.match(output, /Page\.enable/);
            assert.match(output, /Runtime\.evaluate.*expression/);
          }
          assert.equal(requests, 0, 'help reached the browser bridge');
          assert.equal(notifications, 0, 'help notified the app');
        });
      }
    }
    for (const command of commands) {
      const result = await cli(exe, ['--profile', 'Invalid profile', command, '--help'], env);
      assert.equal(result.status, 0, `${command}: help must precede profile validation`);
      assert.match(result.stdout + result.stderr, /^usage: /);
    }
    assert.deepEqual(fs.readdirSync(directory), ['zsb.exe']);
    assert.equal(requests, 0);
    assert.equal(notifications, 0);
  } finally {
    for (const socket of sockets) socket.destroy();
    await Promise.all([new Promise(resolve => bridge.close(resolve)), new Promise(resolve => notify.close(resolve))]);
    fs.rmSync(directory, { recursive: true, force: true });
  }
});
