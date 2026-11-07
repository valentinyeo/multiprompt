const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const { createInterface } = require('node:readline');
const path = require('node:path');
const test = require('node:test');
const remoteOnly = { skip: process.platform === 'win32' ? 'The PTY lives on the Linux SSH server' : false };

async function terminal(t, command, size = [24, 80], multiplex = false) {
  const worker = path.join(__dirname, '../src/terminal_channel.py');
  const args = multiplex ? ['-u', '-c', 'import base64,sys;exec(base64.b64decode(sys.stdin.buffer.readline()))'] : ['-u', worker];
  const child = spawn('python3', args, { stdio: ['pipe', 'pipe', 'pipe'] });
  let output = '';
  let stderr = '';
  const waiters = [];
  child.stderr.on('data', (data) => { stderr += data; });
  let ready;
  const handshake = new Promise((resolve) => { ready = resolve; });
  const lines = createInterface({ input: child.stdout });
  lines.on('line', (line) => {
    if (multiplex) {
      const packet = JSON.parse(line);
      if (packet.ready) { ready(); return; }
      if (packet.closed) return;
      line = packet.data;
    }
    output += Buffer.from(line, 'base64').toString('utf8');
    for (const waiter of [...waiters]) {
      if (output.includes(waiter.text)) {
        clearTimeout(waiter.timer);
        waiters.splice(waiters.indexOf(waiter), 1);
        waiter.resolve(output);
      }
    }
  });
  function waitFor(text) {
    if (output.includes(text)) return Promise.resolve(output);
    return new Promise((resolve, reject) => {
      const waiter = { text, resolve };
      waiter.timer = setTimeout(() => reject(new Error(`Missing ${text}: output=${output}; stderr=${stderr}`)), 5000);
      waiters.push(waiter);
    });
  }
  t.after(async () => {
    child.stdin.end();
    if (child.exitCode === null && child.signalCode === null) await new Promise((resolve) => {
      const timer = setTimeout(() => child.kill('SIGKILL'), 3000);
      child.once('exit', () => { clearTimeout(timer); resolve(); });
    });
    for (const waiter of waiters) clearTimeout(waiter.timer);
    lines.close();
    assert.equal(stderr, '');
  });
  function send(value) {
    const packet = multiplex ? { channel: 1, terminal: true, data: JSON.stringify(value) } : value;
    child.stdin.write(JSON.stringify(packet) + '\n');
  }
  if (multiplex) {
    const source = `TERMINAL_SOURCE = '${Buffer.from(fs.readFileSync(worker)).toString('base64')}'\n` + fs.readFileSync(path.join(__dirname, '../src/chat_transport.py'), 'utf8');
    child.stdin.write(Buffer.from(source).toString('base64') + '\n' + Buffer.from('unused reader').toString('base64') + '\n');
    await handshake;
  }
  send({ command, size });
  return { child, waitFor, send, input(value) { send({ input: Buffer.from(value).toString('base64') }); } };
}

test('server PTY has the requested initial size, UTF-8 input and a real terminal environment', remoteOnly, async (t) => {
  const session = await terminal(t, 'stty -echo; stty size; printf "TERM=%s READY\\n" "$TERM"; IFS= read -r text; printf "REPLY=%s\\n" "$text"', [31, 109]);
  const opened = await session.waitFor('READY');
  assert.match(opened, /31 109/);
  assert.match(opened, /TERM=xterm-256color/);
  session.input('orange fox 雪\n');
  assert.match(await session.waitFor('REPLY=orange fox 雪'), /REPLY=orange fox 雪/);
});

test('resizing and subsequent input preserve ordering through one PTY stream', remoteOnly, async (t) => {
  const session = await terminal(t, 'stty -echo; printf "READY\\n"; IFS= read -r text; stty size; printf "DONE\\n"');
  await session.waitFor('READY');
  session.send({ size: [39, 127] });
  session.input('continue\n');
  assert.match(await session.waitFor('DONE'), /39 127/);
});

test('a blocked PTY does not block an independent session', remoteOnly, async (t) => {
  const noisy = await terminal(t, 'stty -echo; printf "READY\\n"; IFS= read -r text; printf "NOISY_FINISHED\\n"');
  await noisy.waitFor('READY');
  const other = await terminal(t, 'printf "OTHER_READY\\n"');
  await other.waitFor('OTHER_READY');
  noisy.input('finish\n');
  await noisy.waitFor('NOISY_FINISHED');
});


test('the existing shared SSH broker carries terminal output and input without another connection', remoteOnly, async (t) => {
  const session = await terminal(t, 'stty -echo; printf "READY\\n"; IFS= read -r text; printf "MUX_REPLY=%s\\n" "$text"', [25, 91], true);
  await session.waitFor('READY');
  session.input('shared-terminal\n');
  assert.match(await session.waitFor('MUX_REPLY=shared-terminal'), /MUX_REPLY=shared-terminal/);
});
