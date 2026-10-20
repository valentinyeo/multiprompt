import test, { before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../', import.meta.url));
const exe = path.resolve(root, process.env.MP_EXE || 'zig-out/bin/multiprompt-dev.exe');
let prefix, env, xvfb;
const launches = [];

function run(command, args = [], timeout = 15000) {
  const result = spawnSync(command, args, { env, encoding: 'utf8', timeout });
  if (result.error) throw result.error;
  return result;
}

async function until(description, timeout, check) {
  const deadline = Date.now() + timeout;
  let state;
  do {
    state = check();
    if (state) return state;
    await delay(250);
  } while (Date.now() < deadline);
  const log = path.join(prefix, 'drive_c/ad/ZigShell/debug.log');
  const decisions = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').split('\n').filter(line => line.includes('second-launch:')).join('\n') : '';
  assert.fail(`Timed out waiting for ${description}; app pids=${appPids()}, windows=${run('xdotool', ['search', '--name', 'multiprompt']).stdout.trim()}, already-open dialogs=${windows('^multiprompt$')}\n${decisions}`);
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
        && !fs.readFileSync(`/proc/${pid}/stat`, 'utf8').match(/\) Z /);
    } catch { return false; }
  }).sort((a, b) => a - b);
}

function launch() {
  const child = spawn('nice', ['-n', '10', 'wine', 'cmd', '/c', 'C:\\go.bat'], { env, stdio: 'ignore' });
  launches.push(child);
  return child;
}

function stopApps() {
  for (const pid of appPids()) {
    try { process.kill(pid, 'SIGCONT'); } catch {}
  }
  const result = run('wineserver', ['-k']);
  assert.ok(result.status === 0 || (result.status === 1 && appPids().length === 0 && !result.stderr), `wineserver -k failed: ${result.stderr}`);
  const waited = run('wineserver', ['-w']);
  assert.equal(waited.status, 0, waited.stderr);
}

before(async () => {
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'pgrep', 'import', 'nice']) {
    const found = spawnSync('which', [command], { encoding: 'utf8' });
    assert.equal(found.status, 0, `Required tool missing: ${command}`);
  }
  assert.ok(fs.existsSync(exe), `Executable missing: ${exe}`);
  prefix = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh308-'));
  const display = Array.from({ length: 500 }, (_, i) => 90 + ((Math.floor(Math.random() * 500) + i) % 500))
    .find(n => !fs.existsSync(`/tmp/.X11-unix/X${n}`) && !fs.existsSync(`/tmp/.X${n}-lock`));
  assert.notEqual(display, undefined, 'No free X display');
  env = { ...process.env, DISPLAY: `:${display}`, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', ZIGSHELL_DEBUG: '1' };
  delete env.MULTIPROMPT_NO_LOGIN;
  xvfb = spawn('Xvfb', [env.DISPLAY, '-screen', '0', '1600x1000x24', '-nolisten', 'tcp'], { env, stdio: 'ignore' });
  await until('Xvfb display', 10000, () => run('xdotool', ['getdisplaygeometry']).status === 0);
  const boot = run('wineboot', ['--init'], 180000);
  assert.equal(boot.status, 0, `wineboot failed (signal=${boot.signal}): ${boot.stderr}`);
  fs.writeFileSync(path.join(prefix, 'drive_c/go.bat'), `@echo off\r\nset "APPDATA=C:\\ad"\r\n"Z:${exe.replaceAll('/', '\\')}"\r\n`);
}, { timeout: 200000 });

beforeEach(() => {
  stopApps();
  fs.rmSync(path.join(prefix, 'drive_c/ad'), { recursive: true, force: true });
  fs.mkdirSync(path.join(prefix, 'drive_c/ad'), { recursive: true });
});

after(() => {
  try {
    if (env && prefix) stopApps();
  } finally {
    for (const child of launches) child.kill('SIGKILL');
    xvfb?.kill('SIGTERM');
    if (prefix) fs.rmSync(prefix, { recursive: true, force: true });
  }
});

test('ISSUE-308 frozen copy is replaced', { timeout: 240000 }, async () => {
  launch();
  await until('first app window', 90000, () => windows('^multiprompt v').length);
  const original = appPids();
  assert.ok(original.length, 'First app has no Unix process');
  for (const pid of original) process.kill(pid, 'SIGSTOP');
  launch();
  await until('frozen owner replacement without an already-open dialog', 60000, () => {
    const current = appPids();
    return original.every(pid => !current.includes(pid)) && current.length > 0
      && windows('^multiprompt v').length > 0 && windows('^multiprompt$').length === 0;
  });
  if (process.env.IGSH308_SHOT) {
    const shot = run('import', ['-window', 'root', process.env.IGSH308_SHOT]);
    assert.equal(shot.status, 0, shot.stderr);
  }
});

test('ISSUE-308 live copy is focused', { timeout: 240000 }, async () => {
  launch();
  await until('first app window', 90000, () => windows('^multiprompt v').length);
  const original = appPids();
  assert.ok(original.length, 'First app has no Unix process');
  const second = launch();
  await until('second launch to exit and leave only the live owner without a dialog', 45000, () => {
    const current = appPids();
    return second.exitCode !== null && JSON.stringify(current) === JSON.stringify(original)
      && windows('^multiprompt v').length > 0 && windows('^multiprompt$').length === 0;
  });
});
