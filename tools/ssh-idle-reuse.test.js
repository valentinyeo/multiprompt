const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const between = (source, start, end) => source.slice(source.indexOf(start), source.indexOf(end, source.indexOf(start)));

test('an idle health probe rides the shared transport instead of spawning one ssh.exe', () => {
  const probe = between(read('src/chat_send.zig'), 'fn sshProbeThread', 'fn sshProbeFinish');
  assert.match(probe, /captureSharedCommand\(item\.host/, 'the probe reads over the shared connection');
  assert.doesNotMatch(probe, /sshOneShotCaptureInput|appendSshExe/, 'the probe must not start its own ssh.exe');
});

test('an idle usage read rides the shared transport too', () => {
  const fetch = between(read('src/telemetry_panel.zig'), 'fn ladderFetchRemote', '\nfn ');
  assert.match(fetch, /captureSharedCommand\(/, 'the usage card reads over the shared connection');
  assert.doesNotMatch(fetch, /sshOneShotCapture|appendSshExe/, 'the usage card must not start its own ssh.exe');
});

test('the shared channel waits for a handshake that is already starting', () => {
  const transport = read('src/chat_transport.zig');
  assert.match(transport, /pub fn openCommandWait\(/, 'a caller can wait for the shared handshake');
  assert.match(transport, /WaitForSingleObject\(ready, timeout_ms\)/, 'the wait is bounded by the caller timeout');
  const vps = read('src/vps.zig');
  assert.match(vps, /pub fn captureSharedCommand\(/, 'one entry point captures over the shared channel');
  assert.match(vps, /openCommandWait\(host, command, 15_000\)/, 'the shared channel waits instead of opening a second login');
});

test('a reader retry keeps a pending handshake instead of cancelling it', () => {
  const respawn = between(read('src/chat_transport.zig'), 'pub fn respawn(', '\nfn ');
  assert.doesNotMatch(respawn, /host\.starting = false/, 'a retry must not abandon a handshake that is still starting');
  assert.match(respawn, /if \(host\.running and host\.process != null\)/, 'only a running process is terminated');
});
