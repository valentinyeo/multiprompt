const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const { createInterface } = require('node:readline');
const test = require('node:test');
const remoteOnly = { skip: process.platform === 'win32' ? 'The SSH broker runs on Linux hosts' : false };

const root = path.resolve(__dirname, '..');
const fixture = `import json,sys,time
for line in sys.stdin.buffer:
    value=json.loads(line)
    if value.get('op') == 'slow':
        time.sleep(0.3)
    print(json.dumps(dict(id=value['id'],value=value.get('value'),watch='--watch' in sys.argv)),flush=True)
`;

async function broker(t) {
  const child = spawn('python3', ['-u', path.join(root, 'src/chat_transport.py')], { stdio: ['pipe', 'pipe', 'pipe'] });
  const messages = [];
  const waiters = [];
  let stderr = '';
  child.stderr.on('data', (bytes) => { stderr += bytes; });
  const lines = createInterface({ input: child.stdout });
  lines.on('line', (line) => {
    const value = JSON.parse(line);
    const index = waiters.findIndex((waiter) => waiter.match(value));
    if (index >= 0) {
      const [waiter] = waiters.splice(index, 1);
      clearTimeout(waiter.timer);
      waiter.resolve(value);
    } else messages.push(value);
  });
  function next(match) {
    const index = messages.findIndex(match);
    if (index >= 0) return Promise.resolve(messages.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const waiter = { match, resolve };
      waiter.timer = setTimeout(() => reject(new Error(`broker response timeout: ${stderr}`)), 5000);
      waiters.push(waiter);
    });
  }
  t.after(async () => {
    child.stdin.end();
    if (child.exitCode === null) await new Promise((resolve) => {
      const timer = setTimeout(() => child.kill('SIGKILL'), 3000);
      child.once('exit', () => { clearTimeout(timer); resolve(); });
    });
    for (const waiter of waiters) clearTimeout(waiter.timer);
    lines.close();
  });
  child.stdin.write(Buffer.from(fixture).toString('base64') + '\n');
  assert.equal((await next((value) => value.ready)).ready, true);
  return {
    send(channel, value, watch = false) { child.stdin.write(JSON.stringify({ channel, watch, data: JSON.stringify(value) }) + '\n'); },
    close(channel) { child.stdin.write(JSON.stringify({ channel, close: true }) + '\n'); },
    async reply(channel) { return JSON.parse((await next((value) => value.channel === channel)).data); },
  };
}

test('one transport isolates simultaneous history and message replies, including duplicate request IDs', remoteOnly, async (t) => {
  const b = await broker(t);
  b.send(1, { id: 7, value: 'history' }, true);
  b.send(2, { id: 7, value: 'message' });
  assert.deepEqual(await b.reply(2), { id: 7, value: 'message', watch: false });
  assert.deepEqual(await b.reply(1), { id: 7, value: 'history', watch: true });
  b.send(2, { id: 8, value: 'second' });
  assert.equal((await b.reply(2)).value, 'second');
});

test('a delayed channel does not delay another channel', remoteOnly, async (t) => {
  const b = await broker(t);
  b.send(1, { id: 1, op: 'slow', value: 'slow' });
  b.send(2, { id: 2, value: 'fast' });
  assert.equal((await b.reply(2)).value, 'fast');
  assert.equal((await b.reply(1)).value, 'slow');
});

test('closing one channel preserves another and allows opening a new channel', remoteOnly, async (t) => {
  const b = await broker(t);
  b.send(1, { id: 1, value: 'before' });
  assert.equal((await b.reply(1)).value, 'before');
  b.close(1);
  b.send(2, { id: 2, value: 'after' });
  assert.equal((await b.reply(2)).value, 'after');
  b.send(3, { id: 3, value: 'new' }, true);
  assert.equal((await b.reply(3)).value, 'new');
});

test('history and live streams use logical channels, never per-stream SSH processes', () => {
  const session = fs.readFileSync(path.join(root, 'src/chat_session.zig'), 'utf8');
  const transport = fs.readFileSync(path.join(root, 'src/chat_transport.zig'), 'utf8');
  assert.doesNotMatch(session, /CreateProcessW\(/);
  assert.match(session, /transport\.open\(host, ch\.watch\)/);
  assert.match(transport, /var hosts: \[3\]Host/);
  assert.match(transport, /if \(!host\.running\)/);
  assert.match(transport, /channel\.bytes\.items\.len \+ bytes\.len \+ 1 > MAX_BUFFER/);
});
