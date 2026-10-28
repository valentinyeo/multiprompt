const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const test = require('node:test');
const wrapper = process.env.ZSB_WRAPPER_SH || path.join(__dirname, 'vps-multiprompt-browser.sh');

async function run(args, reply, script = wrapper, env = {}) {
  const sockets = new Set();
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
    socket.on('error', () => {});
    socket.once('data', data => {
      assert.match(data.toString(), /^AUTH:relay-test-token:ZSB:fixture:/);
      if (typeof reply === 'function') reply(socket);
      else socket.end(reply);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  if (reply === null) await new Promise(resolve => server.close(resolve));
  try {
    const child = spawn('bash', [script, ...args], {
      env: { ...process.env, MULTIPROMP_NOTIFY_RELAY_TOKEN: "relay-test-token", TMUX: '', ZSB_SESSION: 'fixture', ZSB_PORT: String(port), ...env },
    });
    let stdout = '', stderr = '';
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    const timer = setTimeout(() => child.kill('SIGKILL'), 5000);
    try {
      const code = await new Promise((resolve, reject) => {
        child.on('error', reject);
        child.on('close', resolve);
      });
      return { code, stdout, stderr };
    } finally { clearTimeout(timer); }
  } finally {
    for (const socket of sockets) socket.destroy();
    if (server.listening) await new Promise(resolve => server.close(resolve));
  }
}

test('notify token lookup failure sends nothing and does not expose the lookup output', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-token-'));
  try {
    const result = await run(['status'], () => assert.fail('unauthenticated request was sent'), wrapper,
      { HOME: dir, MULTIPROMP_NOTIFY_RELAY_TOKEN: '' });
    assert.equal(result.code, 1);
    assert.equal(JSON.parse(result.stdout).error, 'notify_token_unavailable');
    assert.match(result.stderr, /Notify relay token unavailable/);
    assert.doesNotMatch(result.stdout + result.stderr, /Traceback|FileNotFoundError|relay-test-token/);
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

function failed(result, cause, fix) {
  assert.equal(result.code, 1, result.stdout + result.stderr);
  assert.equal(result.stderr.trim().split('\n').length, 1, 'one plain-language error line');
  assert.match(result.stderr, cause);
  assert.match(result.stderr, fix);
  assert.doesNotMatch(result.stderr + result.stdout, /Traceback|Expecting value|JSONDecodeError|AttributeError/);
  assert.equal(JSON.parse(result.stdout).ok, false);
}

for (const command of ['status', 'doctor', 'tabs', 'screenshot', 'text', 'extension-reload']) {
  for (const reply of ['', ' \n', 'not JSON', '{"ok":true', 'null', '[]', '{"result":{}}']) {
    test(`${command} diagnoses ${JSON.stringify(reply)} instead of silence or a parser error`, async () => {
      failed(await run([command], reply), /multiprompt app.*(not reachable|invalid reply)/, /[Rr]econnect|[Rr]estart/);
    });
  }
}

test('screenshot -o validates the reply before creating or overwriting the file', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-reply-'));
  try {
    const file = path.join(dir, 'shot.png');
    fs.writeFileSync(file, 'keep');
    failed(await run(['screenshot', '-o', file], ''), /without a reply/, /[Rr]econnect/);
    assert.equal(fs.readFileSync(file, 'utf8'), 'keep');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});

for (const flag of ['-o', '--output']) {
  test(`screenshot ${flag} creates missing nested output directories`, async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-screenshot-'));
    try {
      const file = path.join(dir, 'evidence', 'nested', 'initial.png');
      const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aBZkAAAAASUVORK5CYII=', 'base64');
      assert.equal(fs.existsSync(path.dirname(file)), false);
      const result = await run(['screenshot', flag, file, '--tab', '42'], JSON.stringify({
        ok: true, result: { data: png.toString('base64') },
      }));
      assert.equal(result.code, 0, result.stdout + result.stderr);
      assert.equal(result.stderr, '');
      assert.deepEqual(fs.readFileSync(file), png);
      assert.deepEqual(JSON.parse(result.stdout), {
        ok: true, path: file, bytes: png.length, via: 'Page.captureScreenshot',
      });
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  });
}

test('selftest reports the transport cause for open, hosting and cleanup, not JSON parsing or null hosting', async () => {
  for (const reply of ['', 'not JSON']) {
    const result = await run(['selftest'], reply);
    assert.equal(result.code, 1);
    assert.equal(result.stderr, '');
    const [json, human] = result.stdout.trim().split('\n');
    const summary = JSON.parse(json);
    for (const step of ['open', 'hosting', 'close']) {
      assert.match(summary.steps[step].error, /multiprompt app.*(not reachable|invalid reply)/);
      assert.match(summary.steps[step].error, /[Rr]econnect|[Rr]estart/);
    }
    assert.match(human, /^FAIL: open: multiprompt app/);
    assert.doesNotMatch(result.stdout, /Expecting value|Traceback|on tab null/);
  }
});

test('tunnel down, app gone, closed pane and structured bridge failures exit nonzero', async () => {
  failed(await run(['status'], null), /app not reachable.*tunnel down/, /Reconnect/);
  failed(await run(['tabs'], socket => socket.destroy()), /without a reply|connection closed/, /[Rr]econnect/);
  failed(await run(['status'], '{"ok":true,"tunnel":"up","pane":"closed"}'), /browser pane closed/, /open\/rebind/);
  failed(await run(['doctor'], '{"ok":true,"tunnel":"down"}'), /app not reachable/, /Reconnect/);
  for (const command of ['status', 'tabs', 'screenshot', 'text']) {
    failed(await run([command], '{"ok":false,"error":"bridge_failed","message":"bridge exited with no output","hint":"Reload the Edge extension."}'), /bridge exited with no output/, /Reload/);
    failed(await run([command], '{"ok":false,"error":"PipeUnavailable"}'), /PipeUnavailable/, /Reload/);
  }
});

test('stalled and abruptly truncated connections return actionable errors', async () => {
  failed(await run(['status'], () => {}, wrapper, { ZSB_TIMEOUT: '0.05' }), /timeout/, /[Rr]econnect/);
  failed(await run(['tabs'], socket => { socket.write('{"ok":'); socket.destroy(); }), /invalid reply|connection closed/, /[Rr]econnect/);
});

test('version mismatch names both versions and the reload fix; explicit reload is allowed', async () => {
  const mismatch = '{"ok":true,"extensionVersion":"1.0.64","bridgeVersion":"1.0.65","result":{}}';
  failed(await run(['tabs'], mismatch), /extension version 1\.0\.64 does not match bridge 1\.0\.65/, /reload the extension/);
  const result = await run(['extension-reload'], mismatch);
  assert.equal(result.code, 0);
  assert.equal(result.stderr, '');
});

test('healthy JSON, fragmented responses and documented app acknowledgements remain unchanged', async () => {
  const reply = '{"ok":true,"result":{"tabs":[{"id":42}]}}';
  for (const command of ['status', 'tabs', 'screenshot', 'text']) {
    const result = await run([command], socket => { socket.write(reply.slice(0, 12)); socket.end(reply.slice(12)); });
    assert.equal(result.code, 0);
    assert.equal(result.stderr, '');
    assert.equal(result.stdout.trim(), reply);
  }
  for (const command of ['open', 'sidebar', 'navigate', 'back', 'forward', 'reload']) {
    const result = await run([command], 'ok\n');
    assert.equal(result.code, 0);
    assert.equal(result.stdout, 'ok\n');
    assert.equal(result.stderr, '');
  }
  failed(await run(['status'], 'ok\n'), /invalid reply/, /[Rr]econnect/);
});

test('issue: a bridge usage reply is a wrong-arguments error, not a reconnect request', async () => {
  const usage = 'multiprompt-browser [--window <id>] <command> [args]\r\n\r\nGlobal flags (before the command):\r\n';
  const result = await run(['navigate', '--new-tab', 'https://valentinyeo.com/'], usage);
  assert.equal(result.code, 1);
  const reply = JSON.parse(result.stdout);
  assert.equal(reply.error, 'bad_args');
  assert.match(result.stderr, /rejected the arguments of 'navigate'/);
  assert.doesNotMatch(result.stderr, /[Rr]estart|[Rr]econnect|reload/);
});

test('issue: an invalid reply names what came back', async () => {
  const result = await run(['tabs'], 'garbled text\n{"ok":true}');
  failed(result, /Reply started with: garbled text/, /[Rr]estart/);
});

test('issue: the bridge bad_args reply keeps its own hint', async () => {
  const reply = '{"ok":false,"error":"bad_args","message":"usage: navigate <url> [--new-tab] [--activate]","hint":"Check the URL and flags; the app and pane are fine."}\n';
  const result = await run(['navigate', '--bogus'], reply);
  assert.equal(result.code, 1);
  assert.equal(JSON.parse(result.stdout).error, 'bad_args');
  assert.doesNotMatch(result.stderr, /[Rr]estart|[Rr]econnect|[Rr]eload/);
});


test('private user socket controls its own pane without a vault token', { skip: process.platform === 'win32' }, async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'zsb-user-'));
  fs.chmodSync(dir, 0o700);
  const endpoint = path.join(dir, 'browser');
  const server = net.createServer(socket => {
    socket.once('data', data => {
      assert.match(data.toString(), /^ZSB:inne-cro:/);
      assert.doesNotMatch(data.toString(), /AUTH:/);
      socket.end('{"ok":true,"session":"inne-cro"}\n');
    });
  });
  await new Promise(resolve => server.listen(endpoint, resolve));
  fs.chmodSync(endpoint, 0o600);
  try {
    const child = spawn('bash', [wrapper, 'status'], { env: { ...process.env, TMUX: '',
      HOME: dir, ZSB_SESSION: 'inne-cro', ZSB_SOCKET: endpoint, MULTIPROMP_NOTIFY_RELAY_TOKEN: '' } });
    let stdout = '', stderr = '';
    child.stdout.on('data', data => stdout += data);
    child.stderr.on('data', data => stderr += data);
    const code = await new Promise(resolve => child.on('close', resolve));
    assert.equal(code, 0, stdout + stderr);
    assert.equal(JSON.parse(stdout).session, 'inne-cro');
    assert.doesNotMatch(stdout + stderr, /yeo-key|token|AUTH:/);
  } finally {
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
