const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const readline = require('node:readline');
const test = require('node:test');
const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function broker() {
  const child = spawn('python3', ['-u', path.join(root, 'src/chat_transport.py')], { stdio: ['pipe', 'pipe', 'inherit'] });
  const lines = readline.createInterface({ input: child.stdout });
  const queue = [];
  const waiters = [];
  lines.on('line', line => {
    const value = JSON.parse(line);
    const waiter = waiters.shift();
    if (waiter) waiter(value); else queue.push(value);
  });
  const next = () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('broker reply timed out')), 10000);
    waiters.push(value => { clearTimeout(timer); resolve(value); });
  });
  const send = value => child.stdin.write(JSON.stringify(value) + '\n');
  child.stdin.write(Buffer.from('unused reader').toString('base64') + '\n');
  return { child, next, send };
}

test('broker runs a helper command as its own channel and keeps it open across requests', async () => {
  const { child, next, send } = broker();
  try {
    assert.deepEqual(await next(), { ready: true });
    const command = "while IFS= read -r line; do printf 'got:%s\\n' \"$line\"; printf 'bad:\\377\\n'; printf '@@ZS_END@@\\n'; done";
    send({ channel: 3, command, data: 'first' });
    assert.deepEqual(await next(), { channel: 3, data: 'got:first' });
    assert.deepEqual(await next(), { channel: 3, data: 'bad:�' });
    assert.deepEqual(await next(), { channel: 3, data: '@@ZS_END@@' });
    send({ channel: 3, data: '' });
    assert.deepEqual(await next(), { channel: 3, data: 'got:' });
    assert.deepEqual(await next(), { channel: 3, data: 'bad:�' });
    assert.deepEqual(await next(), { channel: 3, data: '@@ZS_END@@' });
    send({ channel: 3, close: true });
    send({ channel: 4, command: 'exit 0', data: '' });
    assert.deepEqual(await next(), { channel: 4, closed: true });
  } finally {
    child.kill();
  }
});

test('session list poll and autocomplete ride the shared server connection when the switch is on', () => {
  const vps = read('src/vps.zig');
  assert.match(vps, /if \(app_state\.g_shared_server_connection\) \{\s+if \(app_state\.g_vps_channels\[host\]\.alive\) closeVpsChannelUnlocked\(host\);\s+return sharedChannelRequest\(&g_shared_poll_channels\[host\], host, VPS_CHANNEL_LOOP_SCRIPT, "", buf, VPS_CHANNEL_SENTINEL\);/);
  assert.match(vps, /if \(app_state\.g_shared_server_connection\) \{\s+if \(app_state\.g_ac_channels\[host\]\.alive\) closeAcChannelUnlocked\(host\);\s+const n = sharedChannelRequest\(&g_shared_ac_channels\[host\], host, AC_SERVE_SCRIPT,/);
  assert.match(vps, /slot\.\* = chat_transport\.openCommand\(host, command\);/);
  assert.match(read('src/chat_transport.zig'), /packet\(host, \.\{ \.channel = channel\.id, \.command = channel\.command, \.data = line \}\)/);
});

test('a host whose ssh fails is backed off and its error text is never listed as a session', () => {
  const vps = read('src/vps.zig');
  assert.match(vps, /if \(host >= g_poll_retry_at\.len or GetTickCount64\(\) < g_poll_retry_at\[host\]\) return;/);
  assert.match(vps, /if \(result\.success\) total = result\.len;/);
  assert.match(vps, /g_poll_retry_at\[host\] = GetTickCount64\(\) \+ @import\("console\.zig"\)\.tunnelRetryMs\(g_poll_failures\[host\]\);/);
});
