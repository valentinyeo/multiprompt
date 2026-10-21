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

test('ISSUE-438 Chat View drag selection and context Copy', { timeout: 175000 }, async t => {
  os.setPriority(15);
  for (const command of ['wine', 'wineboot', 'wineserver', 'Xvfb', 'xdotool', 'openbox', 'import', 'convert', 'tesseract']) {
    assert.equal(spawnSync('which', [command]).status, 0, `Required tool missing: ${command}`);
  }
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-select-'));
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
    const first = 'Opening words Anchor amber birch cedar drift elm forest garden hill island jasmine kettle lantern maple north ocean pine quiet river silver trail under violet willow yellow zenith across the valley until the winding road reaches its peaceful closing.';
    const second = 'Second message reaches harbor meadow with enough additional words to show that copying a message is different from copying only the selected text.';
    const agentSource = fs.readFileSync(path.join(root, 'tools/chat-reply-agent.c'), 'utf8');
    const fixture = 'const WCHAR message[] = L"\\x25cf Reply fixture line\\r\\n\\r\\n";';
    assert.ok(agentSource.includes(fixture), 'Reply fixture source must still provide the shared agent setup');
    const agent = path.join(out, 'select-agent.c');
    fs.writeFileSync(agent, agentSource.replace(fixture, `const WCHAR message[] = L"\\x25cf ${first}\\r\\n\\r\\n\\x25cf ${second}\\r\\n\\r\\n";`));
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', agent, '-o', stub], 60000);
    const clipboardSource = path.join(out, 'clipboard.c');
    fs.writeFileSync(clipboardSource, String.raw`
#include <windows.h>
#include <stdio.h>
#include <string.h>
int main(int argc, char **argv) {
    if (!OpenClipboard(NULL)) return 30;
    if (argc == 3 && strcmp(argv[1], "--seed") == 0) {
        int n = MultiByteToWideChar(CP_UTF8, 0, argv[2], -1, NULL, 0);
        HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, n * sizeof(WCHAR));
        WCHAR *text = GlobalLock(data);
        if (!text) return 31;
        MultiByteToWideChar(CP_UTF8, 0, argv[2], -1, text, n);
        GlobalUnlock(data);
        if (!EmptyClipboard() || !SetClipboardData(CF_UNICODETEXT, data)) return 32;
    } else {
        HANDLE data = GetClipboardData(CF_UNICODETEXT);
        const WCHAR *text = data ? GlobalLock(data) : NULL;
        if (!text) return 33;
        int n = WideCharToMultiByte(CP_UTF8, 0, text, -1, NULL, 0, NULL, NULL);
        char *bytes = HeapAlloc(GetProcessHeap(), 0, n);
        if (!bytes) return 34;
        WideCharToMultiByte(CP_UTF8, 0, text, -1, bytes, n, NULL, NULL);
        FILE *file = fopen("C:\\clipboard.txt", "wb");
        if (!file) return 35;
        fwrite(bytes, 1, n - 1, file);
        fclose(file);
        HeapFree(GetProcessHeap(), 0, bytes);
        GlobalUnlock(data);
    }
    return CloseClipboard() ? 0 : 36;
}
`);
    const clipboard = path.join(out, 'clipboard.exe');
    checked(zig, ['cc', '-target', 'x86_64-windows-gnu', '-O2', '-Wl,--subsystem,windows', clipboardSource, '-o', clipboard], 60000);
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
    const [left, top, right, bottom] = before.transcript;
    const screen = path.join(out, 'before-select.png');
    checked('import', ['-window', 'root', screen]);
    const crop = path.join(out, 'transcript.png');
    checked('convert', [screen, '-crop', `${right - left}x${bottom - top}+${left}+${top}`, '+repage', '-resize', '400%', crop]);
    const ocr = checked('tesseract', [crop, 'stdout', '--psm', '6', 'tsv']);
    fs.writeFileSync(path.join(out, 'transcript.tsv'), ocr);
    const words = ocr.trim().split('\n').slice(1).map(line => {
      const fields = line.split('\t');
      return { text: fields[11], left: left + Number(fields[6]) / 4, top: top + Number(fields[7]) / 4, width: Number(fields[8]) / 4, height: Number(fields[9]) / 4 };
    }).filter(word => word.text);
    const word = text => {
      const matches = words.filter(word => word.text === text);
      assert.equal(matches.length, 1, `Expected one visible ${text}: ${JSON.stringify(words)}`);
      return matches[0];
    };
    const point = word => [Math.floor(word.left + 1), Math.floor(word.top + word.height / 2)];
    const anchor = word('Anchor');
    const amber = word('amber');
    const closing = word('closing.');
    const secondStart = word('Second');
    const harbor = word('harbor');
    const meadow = word('meadow');
    assert.ok(closing.top > anchor.top + anchor.height, 'The first message must wrap across lines');
    assert.ok(secondStart.top > closing.top + closing.height + 6, 'Messages must have a visible gap');
    assert.ok(Math.abs(harbor.top - meadow.top) < 3, 'The final space must be on one rendered line');
    const start = point(anchor);
    const end = [right - 27, point(word('text.'))[1]];
    const expectedDrag = first.slice(first.indexOf('Anchor')) + '\r\n\r\n' + second;
    const expectedSelection = first.slice(first.indexOf('Anchor')) + '\r\n\r\n' + second.slice(0, second.indexOf('meadow'));
    const seed = name => checked('wine', [winPath(clipboard), '--seed', `UNCHANGED-${name}`]);
    const copied = () => {
      checked('wine', [winPath(clipboard)]);
      return read(path.join(prefix, 'drive_c/clipboard.txt'));
    };
    const move = async ([x, y]) => {
      checked('xdotool', ['mousemove', '--sync', String(x), String(y)]);
      await delay(100);
    };
    const drag = async (name, finish = end) => {
      checked('xdotool', ['key', 'Escape']);
      await move(start);
      checked('xdotool', ['mousedown', '1']);
      for (const p of [
        [Math.floor(amber.left - 2), start[1]],
        [right - 27, start[1]],
        [left + 25, Math.floor(closing.top + closing.height + 3)],
        [left + 100, Math.floor((closing.top + closing.height + secondStart.top) / 2)],
        point(secondStart),
        [Math.floor(meadow.left - 2), point(meadow)[1]],
        finish,
      ]) await move(p);
      checked('xdotool', ['mouseup', '1']);
      const screenshot = path.join(out, `${name}-selection.png`);
      checked('import', ['-window', window, screenshot]);
      console.log(`SELECTION_SCREENSHOT ${screenshot}`);
    };
    const contextCopy = async p => {
      await move(p);
      checked('xdotool', ['click', '3']);
      checked('import', ['-window', window, path.join(out, 'copy-menu.png')]);
      checked('xdotool', ['key', 'Home', 'Return']);
    };
    await t.test('a) mouse drag across spaces, line ends and message gap then Ctrl+C copies the exact span', async () => {
      seed('drag');
      await drag('ctrl-c');
      checked('xdotool', ['key', 'ctrl+c']);
      const actual = copied();
      console.log(`DRAG_CLIPBOARD ${JSON.stringify(actual)}`);
      assert.equal(actual, expectedDrag);
    });
    await t.test('b) right-click Copy without a selection copies the whole message', async () => {
      checked('xdotool', ['key', 'Escape']);
      seed('message');
      await contextCopy(point(secondStart));
      const actual = copied();
      console.log(`MESSAGE_CLIPBOARD ${JSON.stringify(actual)}`);
      assert.equal(actual, second);
    });
    await t.test('c) right-click inside a selection then Copy copies the exact selection', async () => {
      seed('selection');
      await drag('context', point(meadow));
      await contextCopy(point(amber));
      const actual = copied();
      console.log(`SELECTION_CLIPBOARD ${JSON.stringify(actual)}`);
      assert.equal(actual, expectedSelection);
    });

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
