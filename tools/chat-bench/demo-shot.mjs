#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import readline from 'node:readline';
import { atomic, winPath } from './lib.mjs';
import { sessions, transcript, usage } from './demo-workspace.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, i, all) => i % 2 ? pairs : [...pairs, [all[i].replace(/^--/, ''), all[i + 1]]], []));
if (!args.exe || !args.png) throw new Error('Usage: xvfb-run -a -s "-screen 0 1600x1000x24" node tools/chat-bench/demo-shot.mjs --exe zig-out/bin/multiprompt.exe --png hero.png [--width 1600 --height 1000]');
if (!process.env.DISPLAY) throw new Error('Run under xvfb-run so the app never draws on a real desktop');
const width = Number(args.width || 1600), height = Number(args.height || 1000);
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'demo-shot-'));
const home = path.join(root, 'home'), appdata = path.join(root, 'appdata'), mailbox = path.join(root, 'mailbox'), prefix = path.join(root, 'wine-prefix');
const env = { ...process.env, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', MULTIPROMPT_NO_LOGIN: '1', ZIGSHELL_DEBUG: '1' };
fs.mkdirSync(path.join(appdata, 'ZigShell'), { recursive: true });
fs.mkdirSync(mailbox, { recursive: true });
const exe = path.join(root, 'multiprompt.exe');
fs.copyFileSync(path.resolve(args.exe), exe);
for (const s of sessions) {
  const file = path.join(home, '.claude/projects/-home-dev-notebook', `${s.sid}.jsonl`);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, transcript(s).map(r => JSON.stringify(r) + '\n').join(''));
}
const active = sessions.findIndex(s => s.hero);
const workspace = JSON.stringify({ hide_pills: false, active_tab: active, single_window: false, chat_view_mode: 'everywhere', chat_active: true,
  tabs: sessions.map(s => ({ kind: 'tmux', name: s.name, favorite: !!s.favorite, manual: true, cv: true, cwd: 'C:\\', pid: 0, tmux_session: s.sid, csid: s.sid, ccwd: '/home/dev/notebook' })) });
for (const name of ['session.json', 'session-demo.json']) atomic(path.join(appdata, 'ZigShell', name), workspace);
atomic(path.join(appdata, 'ZigShell/usage-telemetry.json'), JSON.stringify(usage));
atomic(path.join(appdata, 'ZigShell/sidebar-status-card.txt'), '2');
const reader = spawn('python3', [path.join(here, 'reader-service.py'), path.resolve(here, '../../src/chat_history_reader.py')], { env: { ...process.env, HOME: home }, stdio: ['pipe', 'pipe', 'inherit'] });
const jobs = new Map(); let job = 0;
readline.createInterface({ input: reader.stdout }).on('line', line => {
  const value = JSON.parse(line), response = jobs.get(value.job); jobs.delete(value.job);
  if (value.error) throw new Error(`reader: ${value.error}`);
  atomic(response, value.wire);
});
const pump = () => {
  for (const name of fs.readdirSync(mailbox).filter(n => n.endsWith('.request'))) {
    const file = path.join(mailbox, name), request = fs.readFileSync(file, 'utf8'); fs.unlinkSync(file);
    jobs.set(++job, file.replace(/\.request$/, '.response'));
    reader.stdin.write(JSON.stringify({ job, protocol: 'history', request }) + '\n');
  }
};
const log = () => { try { return fs.readFileSync(path.join(appdata, 'ZigShell/debug.log'), 'utf8'); } catch { return ''; } };
const window = () => { try { return execFileSync('xdotool', ['search', '--name', 'multiprompt v'], { encoding: 'utf8' }).trim().split(/\s+/)[0]; } catch { return ''; } };
let app;
try {
  atomic(path.join(root, 'launch.cmd'), `@echo off\r\nset "APPDATA=${winPath(appdata)}"\r\n"${winPath(exe)}" --name demo --no-window-restore\r\n`);
  app = spawn('wine', ['C:\\windows\\system32\\cmd.exe', '/c', winPath(path.join(root, 'launch.cmd'))], { env: { ...env, ZIGSHELL_CHAT_FIXTURE_DIR: winPath(mailbox) }, stdio: 'ignore' });
  const deadline = Date.now() + 180_000;
  let id = '';
  while (!(id = window()) || !new RegExp(`\\[bench\\] heartbeat seq=\\d+ tabs=${sessions.length} `).test(log())) {
    if (Date.now() > deadline) throw new Error('App did not start with the demo workspace');
    pump(); await delay(200);
  }
  execFileSync('xdotool', ['windowsize', id, String(width), String(height), 'windowmove', id, '0', '0']);
  const seq = 1;
  atomic(path.join(mailbox, 'command'), `${seq} ${active} none `);
  const painted = new RegExp(`\\[bench\\] painted seq=${seq} tab=${active} ms=\\d+ blocks=[1-9]`);
  while (!painted.test(log())) {
    if (Date.now() > deadline) throw new Error('Demo chat never painted');
    pump(); await delay(200);
  }
  for (let i = 0; i < 60; i++) { pump(); await delay(200); }
  const client = execFileSync('xwininfo', ['-id', id], { encoding: 'utf8' });
  const size = name => Number(new RegExp(`${name}: +(\\d+)`).exec(client)[1]);
  execFileSync('import', ['-window', 'root', '-crop', `${size('Width')}x${Math.min(size('Height'), height)}+${size('Absolute upper-left X')}+${size('Absolute upper-left Y')}`, '+repage', path.resolve(args.png)]);
  const rgb = execFileSync('convert', [path.resolve(args.png), '-depth', '8', 'rgb:-'], { maxBuffer: 64 << 20 });
  const shotWidth = size('Width');
  let rows = rgb.length / 3 / shotWidth;
  while (rows > 1 && rgb.subarray((rows - 1) * shotWidth * 3, rows * shotWidth * 3).every(v => v < 8)) rows--;
  execFileSync('convert', [path.resolve(args.png), '-crop', `${shotWidth}x${rows}+0+0`, '+repage', path.resolve(args.png)]);
  console.log(`Saved ${path.resolve(args.png)}`);
} finally {
  try { atomic(path.join(mailbox, 'command'), '2 quit'); await delay(2000); } catch {}
  try { execFileSync('wineserver', ['-k'], { env }); } catch {}
  app?.kill('SIGKILL'); reader.kill();
  if (!process.env.DEMO_KEEP) fs.rmSync(root, { recursive: true, force: true });
}
