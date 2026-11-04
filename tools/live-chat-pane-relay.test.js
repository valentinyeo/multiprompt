const assert = require('node:assert/strict');
const fs = require('node:fs');
const net = require('node:net');
const os = require('node:os');
const path = require('node:path');
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const test = require('node:test');

test('desktop relay strips only fixture authentication and preserves chat requests and app replies', { timeout: 10000 }, async t => {
  const script = path.join(__dirname, 'verify-live-chat-pane-relay.py');
  assert.ok(fs.existsSync(script), 'desktop relay boundary exists');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'pane-relay-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const received = [];
  const app = net.createServer(socket => {
    socket.once('data', data => {
      received.push(data.toString());
      socket.end('{"ok":true,"result":{"tab_name":"Live chat one"}}\n');
    });
  });
  app.listen(0, '127.0.0.1');
  await once(app, 'listening');
  t.after(() => app.close());
  const ready = path.join(dir, 'ready.json');
  const watcher = fs.watch(dir);
  const created = once(watcher, 'change');
  t.after(() => watcher.close());
  const relay = spawn(process.platform === 'win32' ? 'python' : 'python3', [script, '--app-port', String(app.address().port), '--ready', ready], { stdio: 'ignore' });
  t.after(async () => {
    relay.kill();
    await once(relay, 'exit');
  });
  await created;
  const { port } = JSON.parse(fs.readFileSync(ready, 'utf8'));
  async function request(wire) {
    const socket = net.connect(port, '127.0.0.1');
    let reply = '';
    socket.setEncoding('utf8');
    socket.on('data', chunk => reply += chunk);
    const ended = once(socket, 'end');
    socket.end(wire);
    await ended;
    return reply;
  }
  const reply = await request('AUTH:live-chat-pane-fixture:ZSB:live-1:c3RhdHVzHw==\n');
  assert.equal(reply, '{"ok":true,"result":{"tab_name":"Live chat one"}}\n');
  assert.deepEqual(received, ['ZSB:live-1:c3RhdHVzHw==\n']);
  const rejected = await request('AUTH:wrong:ZSB:live-2:c3RhdHVzHw==\n');
  assert.equal(JSON.parse(rejected).error, 'invalid_fixture_auth');
  assert.equal(received.length, 1);
});
