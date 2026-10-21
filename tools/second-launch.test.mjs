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
  const decisions = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').split('\n').slice(-120).join('\n') : '';
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
      return !fs.readFileSync(`/proc/${pid}/cmdline`, 'utf8').includes('--usage-telemetry')
        && fs.readFileSync(`/proc/${pid}/environ`, 'utf8').split('\0').includes(`WINEPREFIX=${prefix}`)
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
    const log = prefix && path.join(prefix, 'drive_c/ad/ZigShell/debug.log');
    if (process.env.MP_LAUNCH_LOG && log && fs.existsSync(log)) fs.copyFileSync(log, process.env.MP_LAUNCH_LOG);
    if (env && prefix) stopApps();
  } finally {
    for (const child of launches) child.kill('SIGKILL');
    xvfb?.kill('SIGTERM');
    if (prefix) fs.rmSync(prefix, { recursive: true, force: true });
  }
});

test('ISSUE-308 frozen copy is replaced', { timeout: 240000 }, async () => {
  launch();
  await until('first app window', 90000, () => windows('multiprompt v').length);
  const original = appPids();
  assert.ok(original.length, 'First app has no Unix process');
  for (const pid of original) process.kill(pid, 'SIGSTOP');
  launch();
  await until('frozen owner replacement without an already-open dialog', 60000, () => {
    const current = appPids();
    return original.every(pid => !current.includes(pid)) && current.length > 0
      && windows('multiprompt v').length > 0 && windows('^multiprompt$').length === 0;
  });
  if (process.env.IGSH308_SHOT) {
    const shot = run('import', ['-window', 'root', process.env.IGSH308_SHOT]);
    assert.equal(shot.status, 0, shot.stderr);
  }
});

test('ISSUE-308 live copy is focused', { timeout: 240000 }, async () => {
  launch();
  await until('first app window', 90000, () => windows('multiprompt v').length);
  const original = appPids();
  assert.ok(original.length, 'First app has no Unix process');
  const second = launch();
  await until('second launch to exit and leave only the live owner without a dialog', 45000, () => {
    const current = appPids();
    return second.exitCode !== null && JSON.stringify(current) === JSON.stringify(original)
      && windows('multiprompt v').length > 0 && windows('^multiprompt$').length === 0;
  });
});

test('ISSUE-502 cached chat and 45 sidebar sessions paint before deferred startup without a progress bar', { timeout: 240000 }, async () => {
  const dir = path.join(prefix, 'drive_c/ad/ZigShell');
  fs.mkdirSync(dir, { recursive: true });
  const mailbox = path.join(prefix, 'drive_c/mailbox');
  fs.mkdirSync(mailbox, { recursive: true });
  const tabs = Array.from({ length: 45 }, (_, i) => ({
    kind: 'tmux', name: `Launch session ${i + 1}`, tmux_session: `launch-${i + 1}`,
    chat_id: i + 1, csid: `launch-${i + 1}`, ccwd: '/launch-fixture', cv: true, workspace: 0,
  }));
  fs.writeFileSync(path.join(dir, 'session.json'), JSON.stringify({ tabs, active_tab: 17, chat_view_mode: 'everywhere', chat_active: true }));
  const text = Array.from('Saved launch conversation', c => c.charCodeAt(0));
  const rows = tabs.map((tab, i) => ({ id: i + 1, chat_id: i + 1, name: Array.from(tab.name, c => c.charCodeAt(0)), kind: 3 }));
  const cache = { active: 18, rows, chat: true, text, blocks: [{ start: 0, len: text.length, role: 'prose', markdown: true }] };
  fs.writeFileSync(path.join(dir, 'session.json.launch.json'), JSON.stringify(cache));
  fs.writeFileSync(path.join(prefix, 'drive_c/go.bat'), `@echo off\r\nset "APPDATA=C:\\ad"\r\nset "MULTIPROMPT_NO_LOGIN=1"\r\nset "ZIGSHELL_CHAT_FIXTURE_DIR=C:\\mailbox"\r\n"Z:${exe.replaceAll('/', '\\')}" --single-window --no-window-restore\r\n`);
  const log = path.join(dir, 'debug.log');
  const readLog = () => fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '';
  const began = Date.now();
  launch();
  let windowMs;
  await until('launch first paint', 90000, () => {
    if (windowMs === undefined && windows('multiprompt v').length) windowMs = Date.now() - began;
    const output = readLog();
    return process.env.MP_LAUNCH_BASELINE === '1' ? /\[switch\] chat painted/.test(output) : /launch first-paint ms=\d+/.test(output);
  });
  const observedPaintMs = Date.now() - began;
  const output = readLog();
  const version = fs.readFileSync(exe).toString('latin1').match(/MPVERSION=([0-9.]+);/)?.[1];
  if (process.env.MP_LAUNCH_BASELINE === '1') {
    const timestamp = line => Date.parse(line.slice(0, 23).replace(' ', 'T'));
    const lines = output.split('\n');
    const start = lines.find(line => line.includes('[bench] fixture transport enabled'));
    const paint = lines.find(line => line.includes('[switch] chat painted'));
    assert.ok(start && paint, 'Original startup proxies missing');
    console.log(JSON.stringify({ mode: 'before', version, sessions: 45, windowMs, observedPaintMs, fixtureInitToChatPaintProxyMs: timestamp(paint) - timestamp(start), proxy: '[bench] fixture transport enabled -> [switch] chat painted' }));
    assert.ok(fs.readFileSync(exe).includes(Buffer.from('Restoring sessions - ')), 'Positive control must contain the original custom progress paint');
    return;
  }
  const firstPaintMs = Number(output.match(/launch first-paint ms=(\d+)/)[1]);
  assert.ok(firstPaintMs < 1000, `First paint took ${firstPaintMs}ms`);
  const first = output.indexOf('launch first-paint');
  assert.ok(output.indexOf('launch snapshot-restored') < first, 'Snapshot must be installed before paint');
  assert.match(output.slice(0, first), /launch cached-chat rows=45 active=18 blocks=1/);
  assert.ok(!/launch step=(account|telemetry|links|tabs|browser)/.test(output.slice(0, first)), 'Deferred work ran before cached paint');
  await until('all deferred startup steps', 90000, () => /launch step=browser/.test(readLog()));
  const complete = readLog();
  assert.ok(complete.indexOf('launch deferred-start') > first);
  for (const step of ['account', 'telemetry', 'links', 'tabs', 'browser']) assert.ok(complete.indexOf(`launch step=${step}`) > first);
  assert.ok(!fs.readFileSync(exe).includes(Buffer.from('Restoring sessions - ')), 'Custom progress paint remains in the executable');
  assert.equal(windows('Restoring sessions|msctls_progress32').length, 0);
  assert.ok(!/progress.*paint|paint.*progress/i.test(complete), 'Progress paint was logged');
  await until('debounced snapshot worker write', 30000, () => {
    const saved = JSON.parse(fs.readFileSync(path.join(dir, 'session.json.launch.json'), 'utf8'));
    return saved.version === 1 && saved.active === 18 && saved.rows.length === 45 && saved.blocks.length > 0;
  });
  stopApps();
  fs.writeFileSync(log, '');
  launch();
  await until('cached restart first paint', 90000, () => /launch first-paint ms=\d+/.test(readLog()));
  const restart = readLog();
  assert.match(restart, /launch cached-chat rows=45 active=18 blocks=1/);
  const restartPaintMs = Number(restart.match(/launch first-paint ms=(\d+)/)[1]);
  assert.ok(restartPaintMs < 1000, `Persisted snapshot restart took ${restartPaintMs}ms`);
  console.log(JSON.stringify({ mode: 'after', version, sessions: 45, windowMs, observedPaintMs, firstPaintMs, restartPaintMs, deferredStartMs: Number(complete.match(/launch deferred-start ms=(\d+)/)[1]), progressWindows: 0 }));
});
