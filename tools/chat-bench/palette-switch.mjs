import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import readline from 'node:readline';
import { spawn, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';
import { atomic, defaults, hash, imageInk, parseLog, records, winPath } from './lib.mjs';

const execute = promisify(execFile);
const script = fileURLToPath(import.meta.url);
const here = path.dirname(script);
const options = {};
for (let i = 2; i < process.argv.length; i += 2) {
  if (!['--exe', '--out', '--rounds'].includes(process.argv[i]) || !process.argv[i + 1]) throw new Error('Usage: node tools/chat-bench/palette-switch.mjs --exe <path> [--out <dir>] [--rounds N]');
  options[process.argv[i].slice(2)] = process.argv[i + 1];
}
if (!options.exe) throw new Error('--exe is required');
const rounds = Number(options.rounds || 3);
if (!Number.isInteger(rounds) || rounds < 1) throw new Error('--rounds must be a positive integer');
const out = options.out ? path.resolve(options.out) : fs.mkdtempSync(path.join(os.tmpdir(), 'palette-switch-'));
fs.mkdirSync(out, { recursive: true });
if (!process.env.PALETTE_SWITCH_XVFB) {
  if (os.getPriority() < 15) os.setPriority(15);
  const child = spawn('systemd-run', ['--user', '--scope', '--quiet', '-p', `MemoryMax=${defaults.rules.maxRssMiB}M`, '-p', 'MemorySwapMax=0', '--', 'xvfb-run', '-a', '-n', String(1000 + process.pid % 50000), '-e', path.join(out, 'xvfb.log'), '-s', '-screen 0 1280x800x24 -nolisten tcp', process.execPath, script, '--exe', path.resolve(options.exe), '--out', out, '--rounds', String(rounds)],
    { stdio: 'inherit', detached: true, env: { ...process.env, PALETTE_SWITCH_XVFB: '1' } });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => { try { process.kill(-child.pid, signal); } catch {} });
  child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
} else {
  try { await run(); }
  catch (error) {
    const summary = `PALETTE_SWITCH_FAIL ${error.message}\nOutput: ${out}\n`;
    if (!fs.existsSync(path.join(out, 'summary.txt'))) atomic(path.join(out, 'summary.txt'), summary);
    console.error(summary);
    process.exitCode = 1;
  }
}

async function run() {
  process.env.MAGICK_THREAD_LIMIT = '1';
  const prefix = path.join(out, 'wine-prefix');
  if (fs.existsSync(prefix) || fs.existsSync(path.join(out, 'results.json'))) throw new Error('Choose a fresh output directory');
  const requestedExe = path.resolve(options.exe), exe = path.join(out, 'multiprompt.exe');
  const metadata = `${requestedExe}.chat-bench.json`;
  const binary = fs.existsSync(metadata) ? JSON.parse(fs.readFileSync(metadata)) : { protocol: 'history', exeSha256: hash(requestedExe), reader: path.resolve(here, '../../src/chat_history_reader.py') };
  if (hash(requestedExe) !== binary.exeSha256 || (binary.readerSha256 && hash(binary.reader) !== binary.readerSha256)) throw new Error('Binary/reader provenance mismatch');
  if (binary.protocol !== 'history') throw new Error('Palette regression requires the current history fixture protocol');
  fs.copyFileSync(requestedExe, exe);
  const readerFile = path.join(out, 'production-reader.py');
  fs.copyFileSync(binary.reader, readerFile);
  const home = path.join(out, 'home'), appdata = path.join(out, 'appdata'), mailbox = path.join(out, 'mailbox');
  fs.mkdirSync(path.join(appdata, 'ZigShell'), { recursive: true });
  fs.mkdirSync(mailbox);
  const tabs = ['Quartz', 'River', 'Cedar', 'Maple'].map((name, index) => {
    const sid = `claude-palette-${index}`, file = path.join(home, '.claude/projects/-bench-project', `${sid}.jsonl`);
    fs.mkdirSync(path.dirname(file), { recursive: true });
    const fd = fs.openSync(file, 'w');
    let bytes = 0, turn = 0;
    while (bytes < [10_000, 100_000, 512_000, 5_000_000][index]) bytes += fs.writeSync(fd, records('claude', sid, turn++).map(r => JSON.stringify(r) + '\n').join(''));
    fs.closeSync(fd);
    return { name, sid, file, bytes, shell: index + 1 };
  });
  const session = JSON.stringify({ hide_pills: false, active_tab: 0, single_window: false, chat_view_mode: 'everywhere', chat_active: true, tabs: tabs.map(t => ({ kind: 'tmux', name: t.name, manual: true, cv: true, cwd: 'C:\\', pid: 0, tmux_session: t.sid, csid: t.sid, ccwd: '/bench/project' })) });
  for (const name of ['session.json', 'session-palette.json']) atomic(path.join(appdata, 'ZigShell', name), session);
  const env = { ...process.env, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', MULTIPROMPT_NO_LOGIN: '1', ZIGSHELL_DEBUG: '1' };
  const logFd = fs.openSync(path.join(out, 'wine.log'), 'a');
  const reader = spawn('python3', [path.join(here, 'reader-service.py'), readerFile], { env: { ...process.env, HOME: home }, stdio: ['pipe', 'pipe', logFd] });
  const jobs = new Map(), errors = [], switches = [];
  let job = 0, seq = 0, app, window, active = 0, geometry, stopping = false;
  const service = readline.createInterface({ input: reader.stdout });
  service.on('line', line => {
    try {
      const value = JSON.parse(line), response = jobs.get(value.job);
      if (!response || value.error) throw new Error(value.error || 'Unknown reader job');
      jobs.delete(value.job); atomic(response, value.wire);
    } catch (error) { errors.push(`reader: ${error.message}`); }
  });
  reader.on('error', error => errors.push(error.message));
  reader.on('exit', code => { if (!stopping) errors.push(`reader exited ${code}`); });
  reader.stdin.on('error', error => { if (!stopping) errors.push(error.message); });
  const log = () => { try { return fs.readFileSync(path.join(appdata, 'ZigShell/debug.log'), 'utf8'); } catch { return ''; } };
  async function pump() {
    if (errors.length) throw new Error(errors.join('; '));
    if (app?.exitCode !== null && app?.exitCode !== undefined) throw new Error(`App exited ${app.exitCode}`);
    for (const name of fs.readdirSync(mailbox).filter(n => n.endsWith('.request'))) {
      const file = path.join(mailbox, name), request = fs.readFileSync(file, 'utf8'); fs.unlinkSync(file);
      jobs.set(++job, file.replace(/\.request$/, '.response'));
      reader.stdin.write(JSON.stringify({ job, protocol: binary.protocol, request }) + '\n');
    }
  }
  async function until(predicate, ms, reason) {
    const deadline = performance.now() + ms;
    do {
      await pump();
      if (await predicate()) return;
      await delay(25);
    } while (performance.now() < deadline);
    throw new Error(reason);
  }
  async function capture(label) {
    const file = path.join(out, `${label}.png`);
    await execute('import', ['-window', window, file], { timeout: 3000 });
    const r = geometry.layout.transcript;
    const rgb = await execute('convert', [file, '-crop', `${r.right - r.left - 32}x${r.bottom - r.top}+${r.left + 16}+${r.top}`, '+repage', '-depth', '8', 'rgb:-'], { encoding: 'buffer', maxBuffer: 4 << 20, timeout: 3000 });
    const ink = imageInk(rgb.stdout);
    return { file, ...ink, nonEmpty: ink.colors > 4 && ink.inkPixels >= defaults.rules.minimumChatInkPixels };
  }
  async function inspect(label) {
    const { stdout } = await execute('wine', [winPath(path.join(out, 'controls.exe'))], { env, timeout: 3000 });
    atomic(path.join(out, `${label}-controls.txt`), stdout);
    return stdout;
  }
  async function switchByInput(target, method) {
    const before = log().length;
    if (method === 'palette') {
      await execute('xdotool', ['key', '--clearmodifiers', 'ctrl+k']);
      await until(() => log().slice(before).includes('posting WM_APP_SEARCH_OPEN'), 2000, 'Ctrl+K did not open the palette');
      await until(async () => /ZigShellChatTranscript visible=0/.test(await inspect(`${switches.length + 1}-overlay`)), 2000, 'Palette did not hide the transcript');
      await execute('xdotool', ['type', '--clearmodifiers', '--delay', '25', tabs[target].name.slice(0, 4)]);
    }
    let started = performance.now();
    if (method === 'palette') await execute('xdotool', ['key', '--clearmodifiers', 'Return']);
    else {
      const picked = new RegExp(`switchToShell: ${active} -> (\\d+) `);
      for (let rowIndex = 0; rowIndex < tabs.length && !picked.test(log().slice(before)); rowIndex++) {
        started = performance.now();
        await execute('xdotool', ['mousemove', '--window', window, '110', String(53 + rowIndex * 38), 'click', '1']);
        await until(() => picked.test(log().slice(before)), 700, '').catch(() => {});
      }
      if (!picked.test(log().slice(before))) throw new Error('no sidebar row switched tabs');
      target = Number(log().slice(before).match(picked)[1]);
    }
    const row = { target, shell: tabs[target].shell, method, from: active };
    switches.push(row);
    const switchPattern = new RegExp(`switchToShell: ${active} -> ${target} `);
    const paintPattern = new RegExp(`\\[switch\\] chat painted[^\\r\\n]*\\(shell ${row.shell}\\)`);
    try {
      await until(async () => {
        const fresh = log().slice(before);
        if (!switchPattern.test(fresh) || !paintPattern.test(fresh)) return false;
        row.paintObservedMs ??= performance.now() - started;
        row.capture = await capture(`${switches.length}-${method}-${target}`);
        row.elapsedMs = performance.now() - started;
        return row.capture.nonEmpty && row.elapsedMs <= 3000;
      }, Math.max(1, 3000 - (performance.now() - started)), `${method} target=${target} shell=${row.shell}: no target paint and non-empty chat within 3000 ms`);
      if (method === 'palette' && !new RegExp(`\\[confirm\\] sel=0 count=\\d+ target=${target}(?:\\D|$)`).test(log().slice(before))) throw new Error('Palette did not confirm the requested tab');
      row.controls = await inspect(`${switches.length}-${method}-${target}`);
      if (!/ZigShellChatTranscript visible=1 style_visible=1 width=[1-9]\d* height=[1-9]\d*/.test(row.controls) || !/Edit visible=1 style_visible=1 width=[1-9]\d* height=[1-9]\d*/i.test(row.controls)) throw new Error('Chat controls are hidden or zero-sized');
      console.log(`PASS ${method} target=${target} shell=${row.shell} ${Math.round(row.elapsedMs)} ms ink=${row.capture.inkPixels}`);
      active = target;
    } catch (error) {
      row.capture = await capture(`${switches.length}-${method}-${target}-failed`);
      row.log = log().slice(before);
      row.controls = await inspect(`${switches.length}-${method}-${target}-failed`);
      throw error;
    }
  }
  const interrupt = () => { spawn('wineserver', ['-k'], { env, stdio: 'ignore' }).on('error', () => {}); };
  process.on('SIGTERM', interrupt); process.on('SIGINT', interrupt);
  let failure = null;
  try {
    const probeSource = path.join(out, 'controls.c');
    atomic(probeSource, `#include <windows.h>\n#include <stdio.h>\n#include <string.h>\nBOOL CALLBACK child(HWND w, LPARAM p) {\n  (void)p; char c[128]; RECT r; GetClassNameA(w,c,sizeof(c)); GetClientRect(w,&r);\n  printf("%s visible=%d style_visible=%d width=%ld height=%ld\\n",c,IsWindowVisible(w),!!(GetWindowLongPtrA(w,GWL_STYLE)&WS_VISIBLE),r.right,r.bottom); return TRUE;\n}\nBOOL CALLBACK top(HWND w, LPARAM p) {\n  (void)p; char t[256]; GetWindowTextA(w,t,sizeof(t));\n  if (!strncmp(t,"palette - multiprompt v",22)) EnumChildWindows(w,child,0); return TRUE;\n}\nint main(void) { EnumWindows(top,0); return 0; }\n`);
    if (!process.env.ZIG) throw new Error('Set ZIG to the Zig 0.16 executable for the control-state probe');
    await execute(process.env.ZIG, ['cc', '-target', 'x86_64-windows-gnu', '-O2', probeSource, '-o', path.join(out, 'controls.exe'), '-luser32'], { timeout: 60_000 });
    await execute('wineboot', ['--init'], { env, timeout: 180_000, maxBuffer: 1 << 20 });
    atomic(path.join(prefix, 'drive_c/launch.cmd'), `@echo off\r\nset "APPDATA=${winPath(appdata)}"\r\n"${winPath(exe)}" --name palette --no-window-restore\r\n`);
    app = spawn('wine', ['C:\\windows\\system32\\cmd.exe', '/c', 'C:\\launch.cmd'], { env: { ...env, ZIGSHELL_CHAT_FIXTURE_DIR: winPath(mailbox) }, stdio: ['ignore', logFd, logFd] });
    await until(async () => {
      window ||= (await execute('xdotool', ['search', '--name', 'multiprompt v']).catch(() => ({ stdout: '' }))).stdout.trim().split(/\s+/)[0];
      return window && parseLog(log()).heartbeat?.tabs === tabs.length;
    }, 180_000, 'App did not restore four Chat View tabs');
    await execute('xdotool', ['windowsize', window, '1280', '800', 'windowmove', window, '0', '0', 'windowfocus', '--sync', window]);
    for (let target = 0; target < tabs.length; target++) {
      atomic(path.join(mailbox, 'command'), `${++seq} ${target} none`);
      await until(() => parseLog(log()).paints.some(p => p.seq === seq && p.tab === target && p.blocks > 0 && p.chars > 0 && p.file), 15_000, `Fixture ${target} did not paint content`);
      await until(() => {
        const file = path.join(mailbox, 'geometry.json');
        if (!fs.existsSync(file)) return false;
        geometry = JSON.parse(fs.readFileSync(file));
        return geometry.seq === seq && geometry.blocks > 0;
      }, 2000, `Fixture ${target} did not publish painted geometry`);
      active = target;
    }
    await capture('ready');
    for (let round = 0; round < rounds; round++) {
      await switchByInput(null, 'sidebar');
      for (let step = 0; step < tabs.length; step++) await switchByInput((active + 1) % tabs.length, 'palette');
    }
  } catch (error) {
    failure = error.message;
    if (window) {
      const tree = await execute('xwininfo', ['-id', window, '-tree']).catch(error => ({ stdout: error.message }));
      atomic(path.join(out, 'window-tree.txt'), tree.stdout);
      for (const id of [...tree.stdout.matchAll(/\b(0x[0-9a-f]+)\s/g)].map(m => m[1])) {
        const details = await execute('xwininfo', ['-id', id, '-all']).catch(error => ({ stdout: error.message }));
        fs.appendFileSync(path.join(out, 'window-details.txt'), details.stdout);
      }
    }
  } finally {
    stopping = true;
    if (app) {
      atomic(path.join(mailbox, 'command'), `${++seq} quit`);
      await until(() => app.exitCode !== null, 3000, 'graceful shutdown timeout').catch(() => {});
    }
    reader.kill('SIGTERM'); service.close();
    await execute('wineserver', ['-k'], { env, timeout: 15_000 }).catch(() => {});
    app?.kill('SIGKILL');
    await execute('wineserver', ['-w'], { env, timeout: 15_000 }).then(() => fs.rmSync(prefix, { recursive: true, force: true })).catch(error => { failure ||= `cleanup: ${error.message}`; });
    process.removeListener('SIGTERM', interrupt); process.removeListener('SIGINT', interrupt);
    fs.closeSync(logFd);
  }
  const result = { pass: !failure, failure, requestedExe, exeSha256: hash(exe), readerSha256: hash(readerFile), display: process.env.DISPLAY, rounds, tabs, switches };
  atomic(path.join(out, 'results.json'), JSON.stringify(result, null, 2));
  const summary = `${failure ? `PALETTE_SWITCH_FAIL ${failure}` : 'PALETTE_SWITCH_PASS'}\nOutput: ${out}\n`;
  atomic(path.join(out, 'summary.txt'), summary); console.log(summary);
  process.exitCode = failure ? 1 : 0;
}
