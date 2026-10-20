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

test('ISSUE-265 working bar Stop pill delivers one Escape to the console agent', { timeout: 175000 }, async () => {
  os.setPriority(15);
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'openbox', 'import', 'convert']) {
    assert.equal(spawnSync('which', [command]).status, 0, `Required tool missing: ${command}`);
  }
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh265-working-bar-'));
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
    const stub = path.join(out, 'working-agent.exe');
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', 'tools/chat-working-agent.c', '-o', stub], 60000);
    xvfb = spawn('Xvfb', [env.DISPLAY, '-screen', '0', '1280x900x24', '-nolisten', 'tcp'], { env, stdio: ['ignore', logFd, logFd] });
    await until('Xvfb', () => run('xdotool', ['getdisplaygeometry']).status === 0, 10000);
    wm = spawn('openbox', ['--sm-disable'], { env, stdio: ['ignore', logFd, logFd] });
    checked('wineboot', ['--init'], 60000);
    const settings = path.join(prefix, 'drive_c/ad/ZigShell');
    fs.mkdirSync(settings, { recursive: true });
    fs.writeFileSync(path.join(settings, 'session.json'), JSON.stringify({
      active_tab: 0, single_window: false, chat_active: true, chat_view_mode: 'everywhere',
      tabs: [{ kind: 'cmd', name: 'Working bar test', manual: true, cv: true, cwd: 'C:\\', pid: 0 }],
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
    const rect = await until('painted Stop pill', () => [...read(logFile).matchAll(/\[chat\] stop rect (\d+),(\d+),(\d+),(\d+)/g)].at(-1));
    const [l, t, r, b] = rect.slice(1).map(Number);
    assert.ok(r > l && b > t);
    const screenshot = path.join(out, 'working-bar.png');
    checked('import', ['-window', window, screenshot]);
    const colors = Number(checked('convert', [screenshot, '-crop', `${r - l}x${b - t}+${l}+${t}`, '-format', '%k', 'info:']).trim());
    assert.ok(colors > 4, `Stop pill has no text ink: ${colors} colors`);
    console.log(`SCREENSHOT ${screenshot}`);
    checked('xdotool', ['mousemove', '--window', window, String(Math.floor((l + r) / 2)), String(Math.floor((t + b) / 2)), 'click', '1']);
    const events = path.join(prefix, 'drive_c/stub-events.txt');
    await until('Escape keydown and keyup', () => /KEY vk=0x1B down=1/.test(read(events)) && /KEY vk=0x1B down=0/.test(read(events)));
    await until('Stop delivery audit', () => /\[chat\] stop sent shell=\d+ via=console/.test(read(logFile)));
    await until('idle bar timer shutdown', () => read(logFile).includes('[chat] working timer stopped'));
    assert.equal((read(events).match(/KEY vk=0x1B down=1/g) || []).length, 1);
    assert.equal((read(logFile).match(/\[chat\] stop sent/g) || []).length, 1);
    fs.copyFileSync(events, path.join(out, 'stub-events.txt'));
    fs.copyFileSync(logFile, path.join(out, 'debug.log'));
  } finally {
    try {
      const debug = path.join(prefix, 'drive_c/ad/ZigShell/debug.log');
      if (fs.existsSync(debug)) fs.copyFileSync(debug, path.join(out, 'debug.log'));
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
