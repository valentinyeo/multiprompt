const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const pump = path.join(root, 'src/notify_link.py');
const socketDir = '/tmp/mp-notify-' + process.getuid();

function lineReader(stream) {
  let buffer = '';
  const queued = [];
  const waiting = [];
  stream.setEncoding('utf8');
  stream.on('data', chunk => {
    buffer += chunk;
    while (buffer.includes('\n')) {
      const end = buffer.indexOf('\n');
      const line = buffer.slice(0, end);
      buffer = buffer.slice(end + 1);
      const next = waiting.shift();
      if (next) next(line);
      else queued.push(line);
    }
  });
  return () => (queued.length ? Promise.resolve(queued.shift()) : new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('no pump line within 15s')), 15000);
    waiting.push(line => {
      clearTimeout(timer);
      resolve(line);
    });
  }));
}

function startPump({ relay, name }) {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'mp-notify-link-home-'));
  if (relay) {
    const state = path.join(home, '.local/state/multiprompt');
    fs.mkdirSync(state, { recursive: true });
    fs.writeFileSync(path.join(state, 'relay-v1'), '');
  }
  const child = spawn('python3', ['-u', pump, name], {
    env: { ...process.env, HOME: home },
    stdio: ['pipe', 'pipe', 'pipe'],
  });
  const stop = () => {
    child.kill('SIGTERM');
    fs.rmSync(home, { recursive: true, force: true });
  };
  return { child, stop, next: lineReader(child.stdout) };
}

function connect(address, options = {}) {
  return new Promise((resolve, reject) => {
    const socket = net.connect(address, () => resolve(socket));
    socket.once('error', reject);
    socket.setNoDelay(true);
    if (options.timeoutMs) socket.setTimeout(options.timeoutMs, () => reject(new Error('socket stalled')));
  });
}

function collect(socket, limitMs = 10000) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    const timer = setTimeout(() => reject(new Error('peer did not close within ' + limitMs + 'ms')), limitMs);
    socket.on('data', chunk => chunks.push(chunk));
    socket.on('end', () => {
      clearTimeout(timer);
      resolve(Buffer.concat(chunks));
    });
    socket.on('error', error => {
      clearTimeout(timer);
      reject(error);
    });
  });
}

function frame(line) {
  const match = /^a (\d+) ([A-Za-z0-9+/=]*)$/.exec(line);
  assert.ok(match, 'expected an up frame, got ' + JSON.stringify(line));
  return { id: match[1], body: Buffer.from(match[2], 'base64') };
}

test('an alert arrives over the shared link and the reply returns to the caller', async () => {
  const name = 'mp-test-' + process.pid + '-' + Math.random().toString(16).slice(2, 10);
  const socketPath = path.join(socketDir, name + '.sock');
  fs.mkdirSync(socketDir, { recursive: true, mode: 0o700 });
  fs.writeFileSync(socketPath, 'stale');
  const link = startPump({ relay: true, name });
  try {
    const ready = await link.next();
    assert.equal(ready, 'rdy unix ' + socketPath, 'a stale socket file is replaced, not reused');

    const caller = await connect(socketPath);
    const reply = collect(caller);
    const request = 'AUTH:token:ZSBWHO:616263\n';
    caller.write(request);

    const up = frame(await link.next());
    assert.deepEqual(up.body, Buffer.from(request), 'the shared link carries the caller bytes unchanged');

    const answer = '{"has_tab":true,"idle_ms":0,"host":"laptop"}\n';
    link.child.stdin.write('a ' + up.id + ' ' + Buffer.from(answer).toString('base64') + '\n');
    link.child.stdin.write('x ' + up.id + '\n');

    assert.equal((await reply).toString(), answer, 'the caller receives the reply the app produced');
  } finally {
    link.stop();
    fs.rmSync(socketPath, { force: true });
  }
});

test('a plain completion alert needs no reply and the pump closes the caller', async () => {
  const name = 'mp-test-' + process.pid + '-' + Math.random().toString(16).slice(2, 10);
  const link = startPump({ relay: true, name });
  try {
    const ready = await link.next();
    const socketPath = ready.split(' ')[2];
    assert.equal(path.dirname(socketPath), socketDir);

    const caller = await connect(socketPath);
    const reply = collect(caller);
    caller.write('AUTH:token:DONE:work\n');

    const up = frame(await link.next());
    assert.equal(up.body.toString(), 'AUTH:token:DONE:work\n');

    link.child.stdin.write('x ' + up.id + '\n');
    assert.equal((await reply).length, 0, 'no reply is written for a one way alert');
  } finally {
    link.stop();
  }
});

test('without the relay the link takes the old localhost port', async t => {
  const probe = net.createServer();
  const busy = await new Promise(resolve => {
    probe.once('error', () => resolve(true));
    probe.listen(19548, '127.0.0.1', () => probe.close(() => resolve(false)));
  });
  if (busy) {
    t.skip('port 19548 is already in use on this machine');
    return;
  }
  const link = startPump({ relay: false, name: 'mp-test-' + process.pid });
  try {
    assert.equal(await link.next(), 'rdy tcp');
    const caller = await connect({ port: 19548, host: '127.0.0.1' });
    const reply = collect(caller);
    caller.write('DONE:work\n');
    const up = frame(await link.next());
    assert.equal(up.body.toString(), 'DONE:work\n');
    link.child.stdin.write('x ' + up.id + '\n');
    assert.equal((await reply).length, 0);
  } finally {
    link.stop();
  }
});
