const test = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawn, spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const shim = path.join(root, 'src/completer_sync_shim.py');
const completer = path.join(root, 'tools/agent-notifications/mp_complete.py');
const linux = process.platform === 'linux';

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function cmdline(pid) {
  try {
    return fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0').filter(Boolean);
  } catch {
    return [];
  }
}

async function startServer(destination) {
  const child = spawn('python3', ['-c', 'import time; time.sleep(60)', destination, '--serve'], { stdio: 'ignore' });
  for (let i = 0; i < 100; i += 1) {
    if (cmdline(child.pid).includes('--serve')) return child;
    await sleep(20);
  }
  child.kill('SIGKILL');
  throw new Error('the scratch completer server did not start');
}

function exited(child, ms) {
  return new Promise((resolve, reject) => {
    if (child.exitCode !== null || child.signalCode !== null) return resolve(child.signalCode);
    const timer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('the completer server kept running'));
    }, ms);
    child.once('exit', (code, signal) => {
      clearTimeout(timer);
      resolve(signal);
    });
  });
}

test('SOFT-3053 the app ships the completer the installer deploys', () => {
  const result = spawnSync(process.execPath, [path.join(root, 'tools/sync-completer.mjs'), '--check'], { encoding: 'utf8' });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  assert.ok(fs.readFileSync(path.join(root, 'src/mp_complete.py')).equals(fs.readFileSync(completer)));
});

test('SOFT-3053 a stale completer on the inne login is replaced and its server stops', { skip: linux ? false : 'reads the Linux process table' }, async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'completer-inne-'));
  try {
    const destination = path.join(home, '.local/share/zigshell/mp_complete.py');
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.writeFileSync(destination, 'stale completer\n');
    const server = await startServer(destination);
    const result = spawnSync('python3', [shim, destination], { input: fs.readFileSync(completer), encoding: 'utf8', timeout: 20000 });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /^installed /);
    assert.match(result.stdout, /stopped=1\b/);
    assert.ok(fs.readFileSync(destination).equals(fs.readFileSync(completer)));
    assert.ok(!fs.existsSync(destination + '.new'));
    assert.equal(await exited(server, 10000), 'SIGTERM');
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('SOFT-3053 a current completer stays and keeps its server', { skip: linux ? false : 'reads the Linux process table' }, async () => {
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'completer-current-'));
  try {
    const destination = path.join(home, '.local/share/zigshell/mp_complete.py');
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(completer, destination);
    const before = fs.statSync(destination).mtimeMs;
    const server = await startServer(destination);
    const result = spawnSync('python3', [shim, destination], { input: fs.readFileSync(completer), encoding: 'utf8', timeout: 20000 });
    assert.equal(result.status, 0, result.stderr || result.stdout);
    assert.match(result.stdout, /^current /);
    assert.equal(fs.statSync(destination).mtimeMs, before);
    assert.equal(server.exitCode, null);
    server.kill('SIGKILL');
    await exited(server, 10000);
  } finally {
    fs.rmSync(home, { recursive: true, force: true });
  }
});

test('SOFT-3053 the app refreshes the completer before it opens the completer channel', () => {
  const composer = fs.readFileSync(path.join(root, 'src/chat_composer.zig'), 'utf8');
  const fetch = composer.indexOf('fetchAcPersistent(ac_host');
  assert.ok(fetch > 0, 'chat_composer.zig must fetch the completer channel');
  assert.ok(composer.indexOf('syncAcCompleter(ac_host);') > 0 && composer.indexOf('syncAcCompleter(ac_host);') < fetch, 'the completer sync runs before the channel opens');
  assert.match(composer, /@embedFile\("completer_sync_shim\.py"\)/);
  assert.match(composer, /@embedFile\("mp_complete\.py"\)/);
  const sync = composer.slice(composer.indexOf('fn acSyncCommand'), composer.indexOf('fn acSyncPayload'));
  assert.match(sync, /tmuxSshTarget\(host\)/);
  assert.match(composer, /TMUX_HOST_INNE/);
  const vps = fs.readFileSync(path.join(root, 'src/vps.zig'), 'utf8');
  assert.match(vps, /python3 ~\/\.local\/share\/zigshell\/mp_complete\.py --serve/);
});
