import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';

const root = fileURLToPath(new URL('../', import.meta.url));
const zig = process.env.ZIG || 'zig';
const exe = path.resolve(root, process.env.MP_EXE || 'zig-out/bin/multiprompt.exe');
const winPath = file => `Z:${file.replaceAll('/', '\\')}`;

test('ISSUE-419 context Reply delivers the exact quote and reply once', { timeout: 175000 }, async () => {
  os.setPriority(15);
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'openbox', 'import', 'convert']) {
    assert.equal(spawnSync('which', [command]).status, 0, `Required tool missing: ${command}`);
  }
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh419-chat-reply-'));
  const prefix = path.join(out, 'wine-prefix');
  const display = Array.from({ length: 500 }, (_, i) => 1000 + (process.pid + i) % 500)
    .find(n => !fs.existsSync(`/tmp/.X11-unix/X${n}`) && !fs.existsSync(`/tmp/.X${n}-lock`));
  assert.notEqual(display, undefined);
  const env = { ...process.env, DISPLAY: `:${display}`, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', ZIGSHELL_DEBUG: '1', MULTIPROMPT_NO_LOGIN: '1' };
  const run = (command, args = [], timeout = 15000) => {
    const result = spawnSync(command, args, { cwd: root, env, encoding: 'utf8', timeout });
    if (result.error) throw result.error;
    return result;
  };
  const checked = (command, args, timeout) => {
    const result = run(command, args, timeout);
    assert.equal(result.status, 0, `${command}: ${result.stdout}\n${result.stderr}`);
    return result.stdout;
  };
  const until = async (description, check, timeout = 25000) => {
    const deadline = Date.now() + timeout;
    do {
      const value = check();
      if (value) return value;
      await delay(150);
    } while (Date.now() < deadline);
    assert.fail(`Timed out: ${description}; output ${out}`);
  };
  const read = file => fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
  let xvfb, wm, app;
  const logFd = fs.openSync(path.join(out, 'wine.log'), 'a');
  try {
    assert.match(checked(zig, ['version']).trim(), /^0\.16\./, 'Set ZIG to the Zig 0.16 compiler');
    if (!fs.existsSync(exe)) checked(zig, ['build', '-j1', '-Dtarget=x86_64-windows-gnu'], 90000);
    assert.ok(fs.existsSync(exe), `Executable missing: ${exe}`);
    const stub = path.join(out, 'claude.exe');
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', 'tools/chat-reply-agent.c', '-o', stub], 60000);
    const inspector = path.join(out, 'reply-probe.exe');
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', '-Wl,--subsystem,windows', 'tools/chat-reply-agent.c', '-o', inspector], 60000);
    xvfb = spawn('Xvfb', [env.DISPLAY, '-screen', '0', '1280x900x24', '-nolisten', 'tcp'], { env, stdio: ['ignore', logFd, logFd] });
    await until('Xvfb', () => run('xdotool', ['getdisplaygeometry']).status === 0, 10000);
    wm = spawn('openbox', ['--sm-disable'], { env, stdio: ['ignore', logFd, logFd] });
    checked('wineboot', ['--init'], 60000);
    const settings = path.join(prefix, 'drive_c/ad/ZigShell');
    fs.mkdirSync(settings, { recursive: true });
    fs.writeFileSync(path.join(settings, 'session.json'), JSON.stringify({
      active_tab: 0, single_window: false, chat_active: true, chat_view_mode: 'everywhere',
      tabs: [{ kind: 'cmd', name: 'Reply test', manual: true, cv: true, cwd: 'C:\\', pid: 0 }],
    }));
    fs.writeFileSync(path.join(prefix, 'drive_c/launch.cmd'), `@echo off\r\nset "APPDATA=C:\\ad"\r\n"${winPath(exe)}" --no-window-restore\r\n`);
    app = spawn('wine', ['cmd', '/d', '/c', 'C:\\launch.cmd'], { env, stdio: ['ignore', logFd, logFd] });
    const logFile = path.join(settings, 'debug.log');
    const window = await until('app window', () => run('xdotool', ['search', '--onlyvisible', '--name', 'multiprompt']).stdout.trim().split(/\s+/).filter(Boolean)[0]);
    checked('xdotool', ['windowactivate', '--sync', window]);
    const sessionFile = path.join(settings, 'session.json');
    const shellPid = await until('restored CMD pid', () => {
      try { return JSON.parse(read(sessionFile)).tabs[0].pid; } catch { return false; }
    });
    checked('wine', [winPath(stub), '--start', String(shellPid)]);
    await until('agent started inside CMD', () => read(path.join(prefix, 'drive_c/stub-pid.txt')));
    await until('captured agent message', () => /PERF\[chat\]: reconcile ms=\d+ size=[1-9]/.test(read(logFile)));
    const rectFile = path.join(prefix, 'drive_c/reply-rects.json');
    const probe = () => {
      checked('wine', [winPath(inspector), '--probe']);
      return JSON.parse(read(rectFile));
    };
    const before = probe();
    checked('import', ['-window', window, path.join(out, 'before-reply.png')]);
    const [left, , , bottom] = before.transcript;
    checked('xdotool', ['mousemove', String(left + 100), String(bottom - 35), 'click', '3']);
    checked('import', ['-window', window, path.join(out, 'reply-menu.png')]);
    checked('xdotool', ['key', 'End', 'Return']);
    const selected = await until('quote bar reserves composer space', () => {
      const rect = probe();
      return rect.transcript[3] < before.transcript[3] ? rect : false;
    });
    assert.equal(selected.transcript[3], before.transcript[3] - 36);
    checked('import', ['-window', window, path.join(out, 'reply-preview.png')]);
    checked('xdotool', ['key', 'Escape']);
    await until('Escape cancels an empty reply', () => probe().transcript[3] === before.transcript[3]);
    checked('xdotool', ['key', 'ctrl+k']);
    checked('xdotool', ['type', '--clearmodifiers', '--delay', '20', 'Reply to latest agent message']);
    checked('xdotool', ['key', 'Return']);
    await until('palette Reply opens the quote bar', () => probe().transcript[3] === selected.transcript[3]);
    checked('xdotool', ['mousemove', String(selected.transcript[2] - 20), String(selected.composer[1] - 29), 'click', '1']);
    await until('x cancels Reply', () => probe().transcript[3] === before.transcript[3]);
    checked('xdotool', ['mousemove', String(left + 100), String(bottom - 35), 'click', '3']);
    checked('xdotool', ['key', 'End', 'Return']);
    await until('context Reply reopens after cancel', () => probe().transcript[3] === selected.transcript[3]);
    checked('xdotool', ['type', '--clearmodifiers', '--delay', '30', 'my answer']);
    checked('import', ['-window', window, path.join(out, 'typed-reply.png')]);
    checked('xdotool', ['key', 'Return']);
    checked('import', ['-window', window, path.join(out, 'after-enter.png')]);
    const keys = path.join(prefix, 'drive_c/stub-keys.txt');
    const expected = '> Reply fixture line\n\nmy answer\n';
    const wireExpected = '\x1b[200~' + expected.slice(0, -1) + '\x1b[201~\n';
    await until('exact quoted reply received', () => read(keys).replaceAll('\r', '') === wireExpected);
    await until('quote bar clears after sending', () => probe().transcript[3] === before.transcript[3]);
    await delay(3500);
    assert.equal(read(keys).replaceAll('\r', ''), wireExpected, 'Quote, reply, and final Enter must each be delivered exactly once');
    console.log('REPLY_EXACTLY_ONCE ' + JSON.stringify(expected));
    fs.copyFileSync(keys, path.join(out, 'stub-keys.txt'));
    fs.copyFileSync(logFile, path.join(out, 'debug.log'));

  } finally {
    try {
      if (app) run('import', ['-window', 'root', path.join(out, 'final-screen.png')]);
      const debug = path.join(prefix, 'drive_c/ad/ZigShell/debug.log');
      if (fs.existsSync(debug)) fs.copyFileSync(debug, path.join(out, 'debug.log'));
      const keys = path.join(prefix, 'drive_c/stub-keys.txt');
      if (fs.existsSync(keys)) fs.copyFileSync(keys, path.join(out, 'stub-keys.txt'));
      console.log(`ARTIFACTS ${out}`);
      if (fs.existsSync(prefix)) {
        run('wineserver', ['-k']);
        checked('wineserver', ['-w']);
      }
    } finally {
      app?.kill('SIGKILL');
      wm?.kill('SIGTERM');
      xvfb?.kill('SIGTERM');
      fs.closeSync(logFd);
      fs.rmSync(prefix, { recursive: true, force: true });
    }
  }
});
