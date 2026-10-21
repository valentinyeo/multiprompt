const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const path = require('node:path');
const { spawn } = require('node:child_process');
const test = require('node:test');
const wrapper = process.env.ZSB_WRAPPER_SH || path.join(__dirname, 'vps-multiprompt-browser.sh');

async function run(args, timeout, respond = () => {}, budget = Number(timeout)) {
  const sockets = new Set();
  const cleanups = [];
  const requests = [];
  const server = net.createServer(socket => {
    sockets.add(socket);
    socket.on('error', () => {});
    socket.on('close', () => sockets.delete(socket));
    socket.once('data', data => {
      const wire = data.toString();
      assert.match(wire, /^ZSB:deadline-fixture:/);
      requests.push(Buffer.from(wire.trim().split(':')[2], 'base64').toString().split('\x1f').slice(0, -1));
      const cleanup = respond(socket);
      if (cleanup) cleanups.push(cleanup);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const env = { ...process.env, TMUX: '', ZSB_SESSION: 'deadline-fixture', ZSB_PORT: String(server.address().port) };
  if (timeout === undefined) delete env.ZSB_TIMEOUT;
  else env.ZSB_TIMEOUT = timeout;
  const started = performance.now();
  let child, timer;
  try {
    child = spawn('bash', [wrapper, ...args], { env });
    let stdout = '', stderr = '', killed = false;
    child.stdout.on('data', chunk => stdout += chunk);
    child.stderr.on('data', chunk => stderr += chunk);
    timer = setTimeout(() => {
      killed = true;
      for (const socket of sockets) socket.destroy();
      child.kill('SIGKILL');
    }, (budget + 3) * 1000);
    const code = await new Promise((resolve, reject) => {
      child.once('error', reject);
      child.once('close', resolve);
    });
    return { code, stdout, stderr, killed, elapsed: performance.now() - started, requests };
  } finally {
    clearTimeout(timer);
    for (const cleanup of cleanups) cleanup();
    for (const socket of sockets) socket.destroy();
    await new Promise(resolve => server.close(resolve));
  }
}

function timedOut(result, deadline) {
  assert.equal(result.killed, false, 'wrapper must time itself out, not be killed by the fixture');
  assert.equal(result.code, 1, result.stdout + result.stderr);
  const reply = JSON.parse(result.stdout);
  assert.equal(reply.ok, false);
  assert.equal(reply.error, 'reply_timeout');
  assert.equal(reply.session, 'deadline-fixture');
  assert.equal(typeof reply.port, 'number');
  assert.match(reply.hint, /[Rr]econnect/);
  assert.match(reply.message, new RegExp(`after [0-9.]+s \\(deadline ${deadline}s\\)`));
  const elapsed = Number(/after ([0-9.]+)s/.exec(reply.message)[1]);
  assert.ok(elapsed >= deadline - 0.01, `reported elapsed ${elapsed}s`);
  assert.ok(result.elapsed >= deadline * 1000 - 10, `premature timeout: ${result.elapsed}ms`);
  assert.ok(result.elapsed < (deadline + 3) * 1000, `late timeout: ${result.elapsed}ms`);
  assert.doesNotMatch(result.stdout + result.stderr, /Traceback/);
}

test('silent server hits the total deadline', async () => {
  timedOut(await run(['open', 'https://example.com'], '0.2'), 0.2);
});

test('trickling server cannot reset the total deadline with a byte every second', async () => {
  let bytes = 0;
  const result = await run(['text'], '2.5', socket => {
    const timer = setInterval(() => { bytes++; socket.write(' '); }, 1000);
    return () => clearInterval(timer);
  });
  timedOut(result, 2.5);
  assert.ok(bytes >= 2, `fixture sent ${bytes} bytes`);
});

for (const command of ['status', 'version']) {
  test(`${command} defaults to five seconds against a silent server`, async () => {
    timedOut(await run([command], undefined, undefined, 5), 5);
  });
  test(`${command} accepts a shorter explicit deadline`, async () => {
    timedOut(await run([command], '0.1'), 0.1);
  });
}

test('ZSB_TIMEOUT can extend the short status default', async () => {
  const reply = '{"ok":true,"result":{}}\n';
  const result = await run(['status'], '7', socket => {
    const timer = setTimeout(() => socket.end(reply), 5200);
    return () => clearTimeout(timer);
  });
  assert.equal(result.killed, false);
  assert.equal(result.code, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, reply);
  assert.ok(result.elapsed > 5000);
});

test('ordinary commands default to fifteen seconds', async () => {
  timedOut(await run(['open'], undefined, undefined, 15), 15);
});

for (const timeout of ['', '0', '-1', 'NaN', 'Infinity', '-Infinity', '1e309', '86401', 'oops']) {
  test(`invalid ZSB_TIMEOUT ${JSON.stringify(timeout)} fails with bad_args before sending`, async () => {
    const result = await run(['open'], timeout, undefined, 1);
    assert.equal(result.code, 1, result.stdout + result.stderr);
    assert.equal(JSON.parse(result.stdout).error, 'bad_args');
    assert.deepEqual(result.requests, []);
    assert.equal(result.killed, false);
  });
}

test('valid decimal deadline allows fragmented success and preserves command parameters', async () => {
  const args = ['cdp', 'Runtime.evaluate', '{"expression":"1","timeout":20000,"awaitPromise":true}'];
  const reply = '{"ok":true,"result":{"value":1}}\n';
  const result = await run(args, '1.5', socket => {
    socket.write(reply.slice(0, 10));
    const timer = setTimeout(() => socket.end(reply.slice(10)), 200);
    return () => clearTimeout(timer);
  });
  assert.equal(result.code, 0, result.stdout + result.stderr);
  assert.equal(result.stdout, reply);
  assert.deepEqual(result.requests, [args]);
});

test('selftest has one deadline shared across requests', async () => {
  let requests = 0;
  const result = await run(['selftest'], '0.5', socket => {
    if (++requests !== 1) return;
    const timer = setTimeout(() => socket.end('ok\n'), 100);
    return () => clearTimeout(timer);
  });
  timedOut(result, 0.5);
  assert.equal(result.requests.length, 2);
  assert.equal(result.requests[0][0], 'open');
  assert.deepEqual(result.requests[1], ['tabs']);
});

test('selftest rejects invalid ZSB_TIMEOUT before sending', async () => {
  const result = await run(['selftest'], 'NaN', undefined, 1);
  assert.equal(result.code, 1);
  assert.equal(JSON.parse(result.stdout).error, 'bad_args');
  assert.deepEqual(result.requests, []);
});

test('long-running command defaults and CI wiring are explicit', () => {
  const source = fs.readFileSync(wrapper, 'utf8');
  const defaults = JSON.parse(/default_timeout = (\{[^}]+\})\.get\(args\[0\], 15\)/s.exec(source)[1]);
  assert.deepEqual(defaults, {
    status: 5, version: 5, doctor: 20,
    text: 30, 'get-text': 30, snapshot: 30, cdp: 30, eval: 30, script: 30,
    screenshot: 60, shoturl: 60,
  });
  assert.match(source, /os\.environ\.get\("ZSB_TIMEOUT", "180"\)/);
  const build = fs.readFileSync(path.join(__dirname, '..', 'build.zig'), 'utf8');
  assert.match(build, /const zsb_deadline_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-deadline\.test\.js" \}\);/);
  for (const step of ['test_step', 'vps_test_step']) {
    assert.ok(build.includes(`${step}.dependOn(&zsb_deadline_tests.step);`), step);
    assert.ok(build.includes(`${step}.dependOn(&zsb_reply_tests.step);`), step);
  }
});
