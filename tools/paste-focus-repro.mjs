import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import http from 'node:http';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { atomic, generate, defaults, winPath, hash } from './chat-bench/lib.mjs';

const execute = promisify(execFile);
const cases = [['chat-text', 'pasted words '], ['chat-url', 'https://example.invalid/path?q=one '], ['chat-image', null], ['terminal-text', 'terminalPaste']];
const script = fileURLToPath(import.meta.url);
const options = {};
for (let i = 2; i < process.argv.length; i += 2) {
  if (!['--exe', '--out', '--setting'].includes(process.argv[i]) || !process.argv[i + 1]) throw new Error('Usage: node tools/paste-focus-repro.mjs --exe <path> [--out dir] [--setting true|false]');
  options[process.argv[i].slice(2)] = process.argv[i + 1];
}
if (!options.exe) throw new Error('--exe is required');
if (options.setting && !['true', 'false'].includes(options.setting)) throw new Error('--setting must be true or false');
const out = path.resolve(options.out || fs.mkdtempSync(path.join(os.tmpdir(), 'paste-focus-')));
fs.mkdirSync(out, { recursive: true });
if (!process.env.PASTE_FOCUS_XVFB) {
  const child = spawn('xvfb-run', ['-a', '-n', String(1000 + process.pid % 50000), '-e', path.join(out, 'xvfb.log'), '-s', '-screen 0 1280x900x24 -nolisten tcp', process.execPath, script, '--exe', path.resolve(options.exe), '--out', out, ...(options.setting ? ['--setting', options.setting] : [])], { stdio: 'inherit', env: { ...process.env, PASTE_FOCUS_XVFB: '1' } });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => child.kill(signal));
  child.on('exit', code => process.exit(code ?? 1));
} else {
  await run();
}

async function run() {
  const prefix = path.join(out, 'wine-prefix');
  if (fs.existsSync(prefix)) throw new Error('Choose a fresh --out directory');
  const env = { ...process.env, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', MULTIPROMPT_NO_LOGIN: '1', ZIGSHELL_DEBUG: '1', MAGICK_THREAD_LIMIT: '1' };
  const exe = path.join(out, 'multiprompt.exe');
  fs.copyFileSync(options.exe, exe);
  const helper = path.join(out, 'paste-focus-helper.exe');
  await execute(process.env.ZIG || 'zig', ['cc', '-target', 'x86_64-windows-gnu', path.join(path.dirname(script), 'paste-focus-helper.c'), '-o', helper, '-luser32', '-lgdi32'], { env, timeout: 120000 });
  const fixture = generate(out, { ...defaults, tabs: 2, windows: 1, browserTabs: false }).instances[0];
  const session = { hide_pills: false, active_tab: 0, single_window: false, tabs: [{ kind: 'cmd', name: 'Paste Chat', manual: true, cv: true, cwd: 'C:\\', pid: 0 }, { kind: 'cmd', name: 'Paste Terminal', manual: true, cv: false, cwd: 'C:\\', pid: 0 }], ...(options.setting ? { igsh354_paste_focus: options.setting === 'true' } : {}) };
  const sessionFile = path.join(fixture.appdata, 'ZigShell/session-paste-focus.json');
  atomic(sessionFile, JSON.stringify(session));
  atomic(path.join(fixture.appdata, 'ZigShell/session.json'), JSON.stringify(session));
  const local = path.join(out, 'localappdata');
  fs.mkdirSync(path.join(local, 'screencast2-go'), { recursive: true });
  let uploads = 0;
  const server = http.createServer((req, res) => {
    const parts = [];
    req.on('data', part => parts.push(part));
    req.on('end', () => {
      const body = Buffer.concat(parts);
      if (req.url !== '/api/upload-screenshot' || !body.includes(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) { res.writeHead(400); res.end('bad PNG'); return; }
      fs.writeFileSync(path.join(out, `upload-${++uploads}.bin`), body);
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ success: true, url: 'https://example.invalid/paste-image.png' }));
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  fs.writeFileSync(path.join(local, 'screencast2-go/config.toml'), `api_base_url = "http://127.0.0.1:${server.address().port}"\nupload_secret = "isolated-repro-only"\n`);
  const log = fs.openSync(path.join(out, 'wine.log'), 'a');
  const wine = args => execute('wine', args, { env, timeout: 20000, maxBuffer: 2e6 });
  const probe = async () => JSON.parse((await wine([winPath(helper), 'probe'])).stdout);
  let app;
  const results = [];
  async function until(fn, timeout = 15000, label = 'condition') {
    const end = Date.now() + timeout;
    let error;
    while (Date.now() < end) {
      try { const result = await fn(); if (result) return result; } catch (e) { error = e; }
      await delay(100);
    }
    throw new Error(`Timed out waiting for ${label}${error ? `: ${error.message}` : ''}`);
  }
  try {
    await execute('wineboot', ['-u'], { env, timeout: 120000 });
    atomic(path.join(prefix, 'drive_c/paste-focus.cmd'), `@echo off\r\nset "APPDATA=${winPath(fixture.appdata)}"\r\nset "LOCALAPPDATA=${winPath(local)}"\r\n"${winPath(exe)}" --name paste-focus --no-window-restore\r\n`);
    app = spawn('wine', ['C:\\windows\\system32\\cmd.exe', '/c', 'C:\\paste-focus.cmd'], { env: { ...env, ZIGSHELL_CHAT_FIXTURE_DIR: winPath(fixture.mailbox) }, stdio: ['ignore', log, log] });
    await until(async () => {
      const text = fs.readFileSync(path.join(fixture.appdata, 'ZigShell/debug.log'), 'utf8');
      return /\[bench\] heartbeat.*tabs=2/.test(text);
    }, 90000);
    const window = (await execute('xdotool', ['search', '--name', 'multiprompt v'])).stdout.trim().split(/\s+/)[0];
    await execute('xdotool', ['windowsize', window, '1280', '800', 'windowmove', window, '0', '0', 'windowfocus', '--sync', window]);
    let seq = 0;
    async function select(index) {
      atomic(path.join(fixture.mailbox, 'command'), `${++seq} ${index}`);
      await until(() => fs.readFileSync(path.join(fixture.appdata, 'ZigShell/debug.log'), 'utf8').includes(`[bench] heartbeat seq=${seq} tabs=2 active=${index}`));
      return until(async () => { const p = await probe(); return (index === 0 ? p.composer : p.console) && p; });
    }
    for (const [name, payload] of cases) {
      try {
        const terminal = name === 'terminal-text';
        const p = await select(terminal ? 1 : 0);
        const r = terminal ? p.consoleRect : p.composerRect;
        await execute('xdotool', ['mousemove', String(Math.round((r[0] + r[2]) / 2)), String(Math.round((r[1] + r[3]) / 2)), 'click', '1']);
        await until(async () => {
          const state = await probe();
          if (state.focus === (terminal ? state.console : state.composer)) return true;
          await execute('xdotool', ['mousemove', String(r[0] + 30), String(r[1] + 30), 'click', '1']);
          return false;
        }, 3000, 'input focus before paste');
        if (!terminal) {
          await wine([winPath(helper), 'clear']);
          await until(async () => (await probe()).text === '');
        }
        await wine([winPath(helper), ...(payload === null ? ['image'] : ['text', payload])]);
        const before = await probe();
        if (before.focus !== (terminal ? before.console : before.composer)) throw new Error('precondition: click did not focus input');
        await execute('xdotool', ['key', '--clearmodifiers', 'ctrl+v']);
        if (payload === null) await until(async () => (await probe()).text.includes('https://example.invalid/paste-image.png'), 15000);
        await delay(1800);
        const afterPaste = await probe();
        await execute('xdotool', ['type', '--clearmodifiers', '--delay', '35', 'QZX']);
        await delay(250);
        const after = await probe();
        let text = after.text;
        if (terminal) {
          const saved = JSON.parse(fs.readFileSync(sessionFile));
          const pid = saved.tabs.find(t => t.name === 'Paste Terminal')?.pid;
          if (!pid) throw new Error('terminal PID absent from saved session');
          text = JSON.parse((await wine([winPath(helper), 'console', String(pid)])).stdout);
        }
        const expected = payload === null ? 'https://example.invalid/paste-image.png QZX' : `${payload}QZX`;
        const pass = text.includes(expected) && after.focus === (terminal ? after.console : after.composer);
        const reason = pass ? 'paste and QZX landed in the same input' : `expected ${JSON.stringify(expected)}; focus=${after.focus}, target=${terminal ? after.console : after.composer}`;
        results.push({ name, pass, reason, before, afterPaste, after, text });
      } catch (error) { results.push({ name, pass: false, reason: error.message.replace(/\s+/g, ' '), state: await probe().catch(() => null) }); }
      const result = results.at(-1);
      await execute('import', ['-window', 'root', path.join(out, `${name}.png`)], { env }).catch(error => { result.pass = false; result.reason += `; capture: ${error.message}`; });
      console.log(`CASE ${name} ${result.pass ? 'PASS' : 'FAIL'} ${result.reason}`);
    }
  } catch (error) {
    for (const [name] of cases) {
      if (results.some(result => result.name === name)) continue;
      const reason = `infrastructure: ${error.message.replace(/\s+/g, ' ')}`;
      results.push({ name, pass: false, reason });
      console.log(`CASE ${name} FAIL ${reason}`);
    }
  } finally {
    atomic(path.join(fixture.mailbox, 'command'), '999 quit');
    await execute('wineserver', ['-k'], { env, timeout: 15000 }).catch(() => {});
    await execute('wineserver', ['-w'], { env, timeout: 15000 }).catch(() => {});
    app?.kill();
    server.close();
    fs.closeSync(log);
    fs.rmSync(prefix, { recursive: true, force: true });
  }
  const pass = results.length === 4 && results.every(result => result.pass);
  atomic(path.join(out, 'results.json'), JSON.stringify({ exe: path.resolve(options.exe), sha256: hash(exe), setting: options.setting ?? 'default', results, uploads, pass }, null, 2));
  console.log(`Evidence: ${out}`);
  console.log(`REPRO ${pass ? 'PASS' : 'FAIL'}`);
  process.exitCode = pass ? 0 : 1;
}
