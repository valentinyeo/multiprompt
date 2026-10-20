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

for (const agent of ['claude', 'codex']) test(`ISSUE-266 ${agent} permission buttons deliver one digit and disappear`, { timeout: 175000 }, async () => {
  os.setPriority(15);
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'openbox', 'import', 'convert']) {
    assert.equal(spawnSync('which', [command]).status, 0, `Required tool missing: ${command}`);
  }
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'igsh266-permission-buttons-'));
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
    const stub = path.join(out, 'permission-agent.exe');
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', 'tools/chat-permission-agent.c', '-o', stub], 60000);
    xvfb = spawn('Xvfb', [env.DISPLAY, '-screen', '0', '1280x900x24', '-nolisten', 'tcp'], { env, stdio: ['ignore', logFd, logFd] });
    await until('Xvfb', () => run('xdotool', ['getdisplaygeometry']).status === 0, 10000);
    wm = spawn('openbox', ['--sm-disable'], { env, stdio: ['ignore', logFd, logFd] });
    checked('wineboot', ['--init'], 60000);
    const settings = path.join(prefix, 'drive_c/ad/ZigShell');
    fs.mkdirSync(settings, { recursive: true });
    fs.copyFileSync(path.join(root, `src/testdata/chat-permission-${agent}.txt`), path.join(prefix, 'drive_c/permission-menu.txt'));
    fs.writeFileSync(path.join(settings, 'session.json'), JSON.stringify({
      active_tab: 0, single_window: false, chat_active: true, chat_view_mode: 'everywhere',
      tabs: [{ kind: 'cmd', name: 'Permission buttons test', manual: true, cv: true, cwd: 'C:\\', pid: 0 }],
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
    const rect = await until('painted Always allow button', () => [...read(logFile).matchAll(/\[chat\] permission rect Always allow (\d+),(\d+),(\d+),(\d+)/g)].at(-1));
    await until('all permission choices painted', () => /\[chat\] permission rect Allow /.test(read(logFile)) && /\[chat\] permission rect Deny /.test(read(logFile)));
    const [l, t, r, b] = rect.slice(1).map(Number);
    assert.ok(r > l && b > t);
    const screenshot = path.join(out, 'issue-266-permission-buttons.png');
    checked('import', ['-window', window, screenshot]);
    const colors = Number(checked('convert', [screenshot, '-crop', `${r - l}x${b - t}+${l}+${t}`, '-format', '%k', 'info:']).trim());
    assert.ok(colors > 4, `Always allow button has no text ink: ${colors} colors`);
    console.log(`SCREENSHOT ${screenshot}`);
    const click = () => checked('xdotool', ['mousemove', '--window', window, String(Math.floor((l + r) / 2)), String(Math.floor((t + b) / 2)), 'click', '--repeat', '2', '--delay', '80', '1']);
    const events = path.join(prefix, 'drive_c/stub-events.txt');
    const keys = path.join(prefix, 'drive_c/stub-keys.txt');
    click();
    await until('one approval digit', () => read(keys) === '2');
    await until('permission delivery audit', () => /\[chat\] permission sent shell=\d+ via=console/.test(read(logFile)));
    const pending = path.join(out, 'permission-answered-menu-still-live.png');
    await until('answered buttons hidden before the console menu clears', () => {
      checked('import', ['-window', window, pending]);
      return Number(checked('convert', [pending, '-crop', `${r - l}x${b - t}+${l}+${t}`, '-format', '%k', 'info:']).trim()) === 1;
    }, 3000);
    assert.ok(!read(logFile).includes('[chat] permission cleared'), 'The menu must remain live during the hiding check');
    click();
    assert.equal(read(keys), '2', 'Double clicking a still-live answered menu must not send another key');
    fs.writeFileSync(path.join(prefix, 'drive_c/permission-clear.txt'), 'clear');
    await until('menu cleared and buttons removed', () => read(logFile).includes('[chat] permission cleared'));
    assert.equal(read(keys), '2', 'Every keydown, including Enter or duplicate digits, is recorded');
    assert.equal((read(events).match(/KEY .*down=1/g) || []).length, 1);
    assert.equal((read(events).match(/KEY vk=0x32 down=0/g) || []).length, 1);
    assert.equal((read(logFile).match(/\[chat\] permission sent/g) || []).length, 1);
    const after = path.join(out, 'permission-buttons-cleared.png');
    checked('import', ['-window', window, after]);
    assert.doesNotMatch(read(logFile).split('[chat] permission cleared').at(-1), /\[chat\] permission rect/);
    const clearedColors = Number(checked('convert', [after, '-crop', `${r - l}x${b - t}+${l}+${t}`, '-format', '%k', 'info:']).trim());
    assert.equal(clearedColors, 1, 'The former button rectangle must be blank after the menu clears');
    click();
    checked('import', ['-window', window, path.join(out, 'permission-no-menu.png')]);
    assert.equal(read(keys), '2', 'Clicking former buttons without a menu must do nothing');
    fs.writeFileSync(path.join(prefix, 'drive_c/permission-next.txt'), 'next');
    const nextDeny = await until('new menu rearms permission buttons', () => [...read(logFile).split('[chat] permission cleared').at(-1).matchAll(/\[chat\] permission rect Deny (\d+),(\d+),(\d+),(\d+)/g)].at(-1));
    const [dl, dt, dr, db] = nextDeny.slice(1).map(Number);
    checked('xdotool', ['mousemove', '--window', window, String(Math.floor((dl + dr) / 2)), String(Math.floor((dt + db) / 2)), 'click', '--repeat', '2', '--delay', '80', '1']);
    const expected = agent === 'claude' ? '24' : '23';
    await until('new menu uses the actual printed denial number', () => read(keys) === expected);
    assert.equal((read(events).match(/KEY .*down=1/g) || []).length, 2);
    fs.copyFileSync(keys, path.join(out, 'stub-keys.txt'));
    fs.copyFileSync(events, path.join(out, 'stub-events.txt'));
    fs.copyFileSync(logFile, path.join(out, 'debug.log'));
  } finally {
    try {
      const debug = path.join(prefix, 'drive_c/ad/ZigShell/debug.log');
      if (fs.existsSync(debug)) fs.copyFileSync(debug, path.join(out, 'debug.log'));
      for (const file of ['stub-events.txt', 'stub-keys.txt']) {
        const source = path.join(prefix, 'drive_c', file);
        if (fs.existsSync(source)) fs.copyFileSync(source, path.join(out, file));
      }
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
