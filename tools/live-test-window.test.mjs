import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../', import.meta.url));
const exe = path.resolve(root, process.env.MP_EXE || 'zig-out/bin/multiprompt.exe');
const toolExe = path.resolve(root, process.env.LIVETEST_EXE || 'zig-out/bin/mp-livetest.exe');
let prefix, env, xvfb, wm, wineLock, realWindow, testWindow, realPids, testPids, state, folder;
let batchId = 0;
const launches = [];

function run(command, args = [], timeout = 15000) {
  const result = spawnSync(command, args, { env, encoding: 'utf8', timeout });
  if (result.error) throw result.error;
  return result;
}

async function until(description, timeout, check) {
  const deadline = Date.now() + timeout;
  do {
    const result = check();
    if (result) return result;
    await delay(250);
  } while (Date.now() < deadline);
  assert.fail(`Timed out waiting for ${description}; app pids=${appPids()}, windows=${windows('multiprompt')}`);
}

function windows(pattern) {
  const result = run('xdotool', ['search', '--onlyvisible', '--name', pattern]);
  assert.ok(result.status === 0 || result.status === 1, result.stderr);
  return result.stdout.trim().split(/\s+/).filter(Boolean);
}

function appPids() {
  const pattern = path.basename(exe).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const result = run('pgrep', ['-f', pattern]);
  assert.ok(result.status === 0 || result.status === 1, result.stderr);
  return result.stdout.trim().split(/\s+/).filter(Boolean).map(Number).filter(pid => {
    try {
      return fs.readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0').includes(`WINEPREFIX=${prefix}`)
        && !fs.readFileSync(`/proc/${pid}/stat`, 'utf8').match(/\) Z /)
        && !fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').split('\0').includes('--usage-telemetry');
    } catch { return false; }
  }).sort((a, b) => a - b);
}

function stopApps() {
  for (const pid of appPids()) {
    try { process.kill(pid, 'SIGCONT'); } catch {}
  }
  const result = run('wineserver', ['-k']);
  assert.ok(result.status === 0 || (result.status === 1 && appPids().length === 0 && !result.stderr), result.stderr);
  assert.equal(run('wineserver', ['-w']).status, 0);
}

function winPath(file) {
  return `Z:${file.replaceAll('/', '\\')}`;
}

function batch(command) {
  const name = `lt-${batchId++}.bat`;
  fs.writeFileSync(path.join(prefix, 'drive_c', name), `@echo off\r\nset "APPDATA=C:\\ad"\r\n${command}\r\nexit /b %errorlevel%\r\n`);
  return `C:\\${name}`;
}

function tool(...args) {
  const output = `lt-output-${batchId}.txt`;
  const file = batch(`"${winPath(toolExe)}" --state C:\\lt\\state.txt ${args.map(arg => `"${arg}"`).join(' ')} > C:\\${output} 2>&1`);
  const result = spawnSync('nice', ['-n', '10', 'wine', 'cmd', '/c', file], { env, stdio: 'ignore', timeout: 150000 });
  if (result.error) throw result.error;
  result.output = fs.readFileSync(path.join(prefix, 'drive_c', output), 'utf8');
  return result;
}

function status() {
  const result = tool('status');
  assert.equal(result.status, 0, result.output);
  return result.output;
}

function activate(window) {
  try {
    run('xdotool', ['windowactivate', window], 5000);
    run('xdotool', ['mousemove', '--window', window, '640', '300', 'click', '1'], 5000);
  } catch {}
}

async function focus(window, mine) {
  await until(`foreground_mine=${mine}`, 60000, () => {
    const now = status();
    if (now.includes(`foreground_mine=${mine}`)) return true;
    activate(window);
    return false;
  });
}

async function steadyFocus(window, mine) {
  await until(`steady foreground_mine=${mine}`, 60000, () => {
    if (!status().includes(`foreground_mine=${mine}`)) {
      activate(window);
      return false;
    }
    for (let i = 0; i < 4; i++) {
      spawnSync('sleep', ['0.5']);
      if (!status().includes(`foreground_mine=${mine}`)) return false;
    }
    return true;
  });
}

function unixPath(windowsPath) {
  const match = /^([a-z]):\\(.*)$/i.exec(windowsPath);
  assert.ok(match, windowsPath);
  if (match[1].toLowerCase() === 'z') return '/' + match[2].replaceAll('\\', '/');
  return path.join(prefix, `drive_${match[1].toLowerCase()}`, ...match[2].split('\\'));
}

before(async () => {
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'pgrep', 'nice', 'flock', 'openbox', 'xprop']) {
    assert.equal(spawnSync('which', [command]).status, 0, `Required tool missing: ${command}`);
  }
  assert.ok(fs.existsSync(exe), `Executable missing: ${exe}`);
  assert.ok(fs.existsSync(toolExe), `Executable missing: ${toolExe}`);
  wineLock = spawn('flock', ['-x', '/tmp/multiprompt-wine-tests.lock', 'sh', '-c', 'printf locked; cat'], { stdio: ['pipe', 'pipe', 'inherit'] });
  await new Promise((resolve, reject) => {
    wineLock.stdout.once('data', resolve);
    wineLock.once('error', reject);
    wineLock.once('exit', code => reject(new Error(`Wine lock exited ${code}`)));
  });
  prefix = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh369-'));
  const display = Array.from({ length: 500 }, (_, i) => 90 + ((Math.floor(Math.random() * 500) + i) % 500))
    .find(n => !fs.existsSync(`/tmp/.X11-unix/X${n}`) && !fs.existsSync(`/tmp/.X${n}-lock`));
  assert.notEqual(display, undefined, 'No free X display');
  env = { ...process.env, DISPLAY: `:${display}`, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', ZIGSHELL_DEBUG: '1' };
  delete env.MULTIPROMPT_NO_LOGIN;
  xvfb = spawn('nice', ['-n', '10', 'Xvfb', env.DISPLAY, '-screen', '0', '1600x1000x24', '-nolisten', 'tcp'], { env, stdio: 'ignore' });
  await until('Xvfb display', 10000, () => run('xdotool', ['getdisplaygeometry']).status === 0);
  wm = spawn('nice', ['-n', '10', 'openbox', '--sm-disable'], { env, stdio: 'ignore' });
  await until('private window manager', 10000, () => run('xprop', ['-root', '_NET_SUPPORTING_WM_CHECK']).stdout.includes('window id'));
  const boot = run('nice', ['-n', '10', 'wineboot', '--init'], 180000);
  assert.equal(boot.status, 0, `wineboot failed: ${boot.stderr}`);
  fs.mkdirSync(path.join(prefix, 'drive_c/ad'), { recursive: true });
  const file = batch(`"${winPath(exe)}"`);
  launches.push(spawn('nice', ['-n', '10', 'wine', 'cmd', '/c', file], { env, stdio: 'ignore' }));
  await until('real app window', 90000, () => windows('multiprompt v').length === 1);
  realWindow = windows('multiprompt v')[0];
  realPids = appPids();
  assert.ok(realPids.length);
}, { timeout: 300000 });

after(() => {
  try {
    if (env && prefix) stopApps();
  } finally {
    for (const child of launches) child.kill('SIGKILL');
    wm?.kill('SIGTERM');
    xvfb?.kill('SIGTERM');
    if (prefix) fs.rmSync(prefix, { recursive: true, force: true });
    wineLock?.stdin.end();
  }
});

test('separate settings: test window starts beside the real app without handover', { timeout: 180000 }, async () => {
  await delay(2500);
  const result = tool('start', '--exe', winPath(exe), '--idle-seconds', '2');
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, /started pid=\d+ hwnd=[0-9a-f]+ appdata=/);
  await until('two visible app windows', 90000, () => windows('multiprompt v').length === 2);
  testWindow = windows('multiprompt v').find(window => window !== realWindow);
  state = JSON.parse(fs.readFileSync(path.join(prefix, 'drive_c/lt/state.txt'), 'utf8'));
  assert.ok(state.pid > 0);
  testPids = appPids().filter(pid => !realPids.includes(pid));
  assert.ok(testPids.length, 'The test launch did not create a separate process');
  const testUnixPid = Number(run('xdotool', ['getwindowpid', testWindow]).stdout.trim());
  assert.ok(testPids.includes(testUnixPid), 'The test window must belong to a new PID, not a real app PID');
  assert.deepEqual(appPids().filter(pid => !testPids.includes(pid)), realPids);
  folder = unixPath(state.folder);
  assert.notEqual(path.resolve(folder, 'appdata'), path.join(prefix, 'drive_c/ad'));
  await until('isolated ZigShell settings', 20000, () => fs.existsSync(path.join(folder, 'appdata/ZigShell')));
  const again = tool('start', '--exe', winPath(exe), '--idle-seconds', '0');
  assert.equal(again.status, 4, again.output);
  assert.match(again.output, /still alive/);
});

test('own window: types only when the test window is in front', { timeout: 90000 }, async () => {
  await steadyFocus(testWindow, 1);
  await delay(2500);
  const result = tool('type', 'hi', '--idle-seconds', '2');
  assert.equal(result.status, 0, result.output);
  assert.match(status(), /foreground_mine=1/);
  const key = tool('key', 'esc', '--idle-seconds', '0');
  assert.equal(key.status, 0, key.output);
});

test('idle: refuses while the user is active', { timeout: 90000 }, async () => {
  await focus(testWindow, 1);
  assert.equal(run('xdotool', ['mousemove', '500', '400', 'mousemove_relative', '--', '1', '1']).status, 0);
  const result = tool('type', 'x', '--idle-seconds', '30');
  assert.equal(result.status, 3, result.output);
  assert.match(result.output, /refused: user active/);
});

test('refuses to type when the real window is in front', { timeout: 90000 }, async () => {
  await steadyFocus(realWindow, 0);
  const result = tool('type', 'hello', '--idle-seconds', '0');
  assert.equal(result.status, 3, result.output);
  assert.match(result.output, /refused: foreground is not the test window/);
  const key = tool('key', 'enter', '--idle-seconds', '0');
  assert.equal(key.status, 3, key.output);
  assert.match(key.output, /refused: foreground is not the test window/);
});

test('own window: stop closes only the test window and removes its folder', { timeout: 120000 }, async () => {
  const result = tool('stop');
  assert.equal(result.status, 0, result.output);
  assert.match(result.output, new RegExp(`stopped pid=${state.pid} folder_removed=1`));
  await until('test process gone, real processes intact', 20000, () => JSON.stringify(appPids()) === JSON.stringify(realPids));
  assert.ok(windows('multiprompt v').includes(realWindow));
  assert.ok(!windows('multiprompt v').includes(testWindow));
  assert.ok(!fs.existsSync(folder));
  assert.ok(!fs.existsSync(path.join(prefix, 'drive_c/lt/state.txt')));
  assert.match(status(), /alive=0/);
  const missing = tool('type', 'no', '--idle-seconds', '0');
  assert.equal(missing.status, 4, missing.output);
});
