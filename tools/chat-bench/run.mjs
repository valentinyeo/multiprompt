#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, execFileSync, execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import readline from 'node:readline';
import { setTimeout as delay } from 'node:timers/promises';
import { defaults, atomic, hash, winPath, generate, records, parseLog, procSnapshot, cpuDelta, imageInk, geometryInside as containsLayout, capacity, isOutsideKill, evaluate } from './lib.mjs';

const execute = promisify(execFile);
const script = fileURLToPath(import.meta.url);
const options = {};
for (let i = 2; i < process.argv.length; i += 2) {
  const key = process.argv[i];
  if (!['--exe', '--minutes', '--out', '--config'].includes(key) || !process.argv[i + 1]) throw new Error('Usage: node tools/chat-bench/run.mjs --exe <path> [--minutes N] [--out dir] [--config file]');
  options[key.slice(2)] = process.argv[i + 1];
}
if (!options.exe) throw new Error('--exe is required (cross-build with zig build -Dtarget=x86_64-windows-gnu)');
const requestedExe = path.resolve(options.exe);
const override = options.config ? JSON.parse(fs.readFileSync(options.config)) : {};
const config = { ...defaults, ...override, rules: { ...defaults.rules, ...override.rules }, capacity: { ...defaults.capacity, ...override.capacity } };
if (options.minutes) config.minutes = Number(options.minutes);
for (const key of ['minutes', 'tabs', 'windows', 'width', 'height', 'warmupSeconds', 'switchSeconds', 'idleSettleSeconds', 'idleSeconds', 'appendSeconds', 'sampleMs', 'hangSeconds', 'startupSeconds']) {
  if (!Number.isFinite(config[key]) || config[key] <= 0) throw new Error(`Invalid config ${key}`);
}
for (const [key, value] of Object.entries(config.rules)) {
  if (!Number.isFinite(value) || value <= 0) throw new Error(`Invalid rule ${key}`);
}
for (const [key, value] of Object.entries(config.capacity)) {
  if (!Number.isFinite(value) || value <= 0) throw new Error(`Invalid capacity ${key}`);
}
if (![config.tabs, config.windows, config.width, config.height].every(Number.isInteger) || config.windows > config.tabs) throw new Error('Invalid fixture dimensions');
const out = options.out ? path.resolve(options.out) : fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-'));
fs.mkdirSync(out, { recursive: true });
if (!process.env.CHAT_BENCH_XVFB) {
  if (os.getPriority() < 15) os.setPriority(15);
  const child = spawn('systemd-run', ['--user', '--scope', '--quiet', '-p', `MemoryMax=${config.rules.maxRssMiB}M`, '-p', 'MemorySwapMax=0', '--', 'xvfb-run', '-a', '-n', String(1000 + process.pid % 50000), '-e', path.join(out, 'xvfb.log'), '-s', `-screen 0 ${config.width * 3}x${config.height * Math.ceil(config.windows / 3)}x24 -nolisten tcp`, process.execPath, script,
    ...process.argv.slice(2).filter((_, i, a) => !(a[i - 1] === '--out' || a[i] === '--out')), '--out', out],
  { stdio: 'inherit', detached: true, env: { ...process.env, CHAT_BENCH_XVFB: '1' } });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => {
    try { process.kill(-child.pid, signal); } catch {  }
  });
  child.on('exit', (code, signal) => process.exit(code ?? (signal ? 1 : 0)));
} else {
  await run();
}

async function run() {
  process.env.MAGICK_THREAD_LIMIT = '1';
  const prefix = path.join(out, 'wine-prefix');
  if (fs.existsSync(prefix)) throw new Error('Output already contains a Wine prefix; choose a new output directory');
  const manifestPath = `${requestedExe}.chat-bench.json`;
  let binary = fs.existsSync(manifestPath) ? JSON.parse(fs.readFileSync(manifestPath)) : null;
  if (!binary) {
    const root = path.resolve(path.dirname(script), '../..');
    const reader = path.join(root, 'src/chat_history_reader.py');
    const marker = fs.readFileSync(requestedExe).toString('latin1').match(/MPVERSION=([0-9.]+);/);
    binary = { version: marker?.[1] || 'candidate', protocol: 'history', exeSha256: hash(requestedExe), reader, readerSha256: hash(reader) };
  }
  if (hash(requestedExe) !== binary.exeSha256 || hash(binary.reader) !== binary.readerSha256) throw new Error('Binary/reader provenance mismatch');
  const exe = path.join(out, 'multiprompt.exe');
  fs.copyFileSync(requestedExe, exe);
  const sourceReader = binary.reader;
  binary = { ...binary, sourceReader, reader: path.join(out, 'production-reader.py') };
  fs.copyFileSync(sourceReader, binary.reader);
  if (hash(exe) !== binary.exeSha256 || hash(binary.reader) !== binary.readerSha256) throw new Error('Copied artifact provenance mismatch');
  const env = { ...process.env, WINEPREFIX: prefix, WINEARCH: 'win64', WINEDEBUG: '-all', WINEDLLOVERRIDES: 'winemenubuilder.exe=d', MULTIPROMPT_NO_LOGIN: '1', ZIGSHELL_DEBUG: '1' };
  const logFd = fs.openSync(path.join(out, 'wine.log'), 'a');
  const fixtures = generate(out, config);
  const priority = Number(execFileSync('ps', ['-o', 'ni=', '-p', String(process.pid)], { encoding: 'utf8' }).trim());
  const run = { schema: 1, requestedExe, exe, binary, prefix, out, config, fixtures, priority, display: process.env.DISPLAY, runnerHashes: { run: hash(script), lib: hash(path.join(path.dirname(script), 'lib.mjs')), service: hash(path.join(path.dirname(script), 'reader-service.py')) }, started: new Date().toISOString(), samples: [], switches: [], readerResponses: [], appends: [], errors: [], infra: [], processes: [], restarted: false };
  const hz = +execFileSync('getconf', ['CLK_TCK'], { encoding: 'utf8' });
  const pageSize = +execFileSync('getconf', ['PAGESIZE'], { encoding: 'utf8' });
  const screenshots = path.join(out, 'screenshots'); fs.mkdirSync(screenshots);
  const browserExe = path.join(out, 'browser-fixture.exe');
  const reader = spawn('python3', [path.join(path.dirname(script), 'reader-service.py'), binary.reader], { env: { ...process.env, HOME: fixtures.home }, stdio: ['pipe', 'pipe', logFd] });
  const jobs = new Map(); let jobId = 0, seq = 0, phase = 'setup', stopping = false;
  let phaseStart = 0, lastAction = 0, previous = new Map(), previousTime = performance.now(), lastAppend = 0;
  const instances = fixtures.instances.map(instance => ({ ...instance, offset: 0, text: '', lastHeartbeat: 0, heartbeatText: '', child: null, window: null, active: 0, live: true }));
  const snapshot = () => procSnapshot(prefix, exe, '/proc', new Map(instances.filter(i => i.pid).map(i => [i.pid, i.pidStart])));
  const service = readline.createInterface({ input: reader.stdout });
  service.on('line', line => {
    try {
      const value = JSON.parse(line), job = jobs.get(value.job);
      if (!job) throw new Error('Unknown reader job');
      jobs.delete(value.job);
      if (value.error) { run.errors.push(`reader: ${value.error}`); atomic(job.response, '@@MP_END@@\n'); }
      else {
        const wait = phase === 'warm' ? config.remoteDelayMs || 0 : config.browserTabs ? 350 : 0;
        setTimeout(() => { if (!stopping) atomic(job.response, value.wire); }, wait);
      }
      const header = (value.wire || '').split('\n')[0].split('\t');
      const q = binary.protocol === 'history' ? JSON.parse(job.request) : null;
      const sid = q?.sid || job.request.trim().split('\t')[5];
      const hasLive = binary.protocol === 'history' ? (value.wire || '').includes('LIVE-') : (value.wire || '').split('\n').some(l => l.startsWith('M\t') && Buffer.from(l.split('\t')[3] || '', 'base64').toString().includes('LIVE-'));
      run.readerResponses.push({ phase, instance: job.instance, sid, id: q?.id || +header[1], ok: header[3] === 'ok' || header[3] === 'same',
        base: q ? +header[5] : null, offset: q ? +header[6] : null, more: q ? header[8] === '1' : null, bytes: Buffer.byteLength(value.wire || ''), hasLive, error: value.error });
    } catch (error) { run.errors.push(`reader protocol: ${error.message}`); }
  });
  reader.on('exit', code => { if (!stopping) run.errors.push(`reader exited ${code}`); });
  reader.on('error', error => run.errors.push(`reader spawn: ${error.message}`));
  reader.stdin.on('error', error => { if (!stopping) run.errors.push(`reader input: ${error.message}`); });
  let interrupted = null;
  const interrupt = signal => {
    interrupted = signal;
    const cleanup = spawn('wineserver', ['-k'], { env, stdio: 'ignore' });
    cleanup.on('error', () => {});
  };
  const onInt = () => interrupt('SIGINT'), onTerm = () => interrupt('SIGTERM');
  process.on('SIGINT', onInt); process.on('SIGTERM', onTerm);
  let timer;
  const appendedPhases = new Set();
  async function waitForCapacity() {
    const began = performance.now(), deadline = began + config.capacity.waitMinutes * 60_000, cores = os.availableParallelism();
    const read = () => capacity(fs.readFileSync('/proc/loadavg', 'utf8'), fs.readFileSync('/proc/meminfo', 'utf8'), cores, config);
    const start = read(); let ready = start;
    if (!ready.ok) console.log(`waiting for capacity: load ${ready.load}/${cores} cores, ${ready.memAvailableMiB} MiB free`);
    while (!ready.ok && performance.now() < deadline) {
      if (interrupted) throw new Error(`Interrupted by ${interrupted}`);
      await delay(Math.min(config.capacity.pollSeconds * 1000, Math.max(0, deadline - performance.now())));
      ready = read();
    }
    run.capacity = { waitedMs: performance.now() - began, start, ready };
    if (!ready.ok) {
      const message = `capacity: ${ready.reason} after ${config.capacity.waitMinutes} min`;
      run.infra.push(message); run.errors.push(message);
    }
    return ready.ok;
  }
  async function pump() {
    if (interrupted) throw new Error(`Interrupted by ${interrupted}`);
    for (const instance of instances) {
      for (const name of fs.readdirSync(instance.mailbox).filter(n => n.endsWith('.request'))) {
        const file = path.join(instance.mailbox, name), response = file.replace(/\.request$/, '.response');
        const request = fs.readFileSync(file, 'utf8'); fs.unlinkSync(file);
        const tab = instance.tabs[instance.active];
        if (['cold', 'warm'].includes(phase) && instance.index === instances.length - 1 && tab.file && !appendedPhases.has(phase) && binary.protocol === 'history' && JSON.parse(request).sid === tab.sid) {
          const bytes = records(tab.provider, tab.sid, tab.turns++, true).map(r => JSON.stringify(r) + '\n').join('');
          fs.appendFileSync(tab.file, bytes);
          run.appends.push({ phase, index: tab.index, bytes: Buffer.byteLength(bytes), size: fs.statSync(tab.file).size });
          appendedPhases.add(phase);
        }
        const job = ++jobId; jobs.set(job, { request, response, instance: instance.index });
        reader.stdin.write(JSON.stringify({ job, protocol: binary.protocol, request }) + '\n');
      }
      const log = path.join(instance.appdata, 'ZigShell/debug.log');
      if (fs.existsSync(log)) {
        const bytes = fs.readFileSync(log); const fresh = bytes.subarray(instance.offset).toString('utf8');
        instance.offset = bytes.length; instance.text += fresh;
        if (fresh.includes('[bench] heartbeat')) instance.lastHeartbeat = performance.now();
      }
    }
  }
  function sample() {
    pump().catch(error => run.errors.push(`pump: ${error.message}`));
    const now = performance.now(), current = snapshot();
    const value = cpuDelta(previous, current, now - previousTime, hz, pageSize);
    previous = current;
    if (['cold', 'warm'].includes(phase)) {
      const guiCount = [...current.values()].filter(p => p.gui).length;
      run.samples.push({ ...value, guiCount, heartbeatAgeMs: instances.map(i => now - i.lastHeartbeat), timeMs: now, elapsedMs: now - previousTime, phase,
        measured: now - phaseStart >= config.warmupSeconds * 1000,
        idle: now - phaseStart >= config.minutes * 60_000 / 2 - config.idleSeconds * 1000 && now - lastAction >= config.idleSettleSeconds * 1000 });
      if (guiCount !== config.windows) run.errors.push(`${phase}: only ${guiCount}/${config.windows} multiprompt UI processes alive`);
      for (const instance of instances) if (now - instance.lastHeartbeat > config.hangSeconds * 1000) run.errors.push(`${phase}: window ${instance.index} heartbeat stalled`);
    }
    previousTime = now;
  }
  async function start(instance) {
    const before = new Set((await execute('xdotool', ['search', '--name', 'multiprompt v']).catch(() => ({ stdout: '' }))).stdout.trim().split(/\s+/).filter(Boolean));
    const batch = `chat-bench-launch-${instance.index}.cmd`;
    atomic(path.join(prefix, 'drive_c', batch), `@echo off\r\nset "APPDATA=${winPath(instance.appdata)}"\r\n"${winPath(exe)}" --name bench-${instance.index} --no-window-restore\r\n`);
    instance.child = spawn('wine', ['C:\\windows\\system32\\cmd.exe', '/c', `C:\\${batch}`],
      { env: { ...env, ZIGSHELL_CHAT_FIXTURE_DIR: winPath(instance.mailbox) }, stdio: ['ignore', logFd, logFd] });
    const launch = instance.child;
    launch.on('exit', (code, signal) => {
      if (instance.child !== launch || !instance.live || stopping) return;
      const message = isOutsideKill(signal) ? `app ${instance.index} killed by SIGKILL from outside the bench (server capacity)` : `app ${instance.index} exited unexpectedly: ${code}/${signal}`;
      if (isOutsideKill(signal)) run.infra.push(message);
      run.errors.push(message);
    });
    const deadline = performance.now() + config.startupSeconds * 1000;
    while (performance.now() < deadline) {
      await pump();
      const ids = (await execute('xdotool', ['search', '--name', 'multiprompt v']).catch(() => ({ stdout: '' }))).stdout.trim().split(/\s+/).filter(Boolean);
      instance.window ||= ids.find(id => !before.has(id));
      const log = parseLog(instance.text);
      if (instance.window && log.heartbeat?.tabs === instance.tabs.length) {
        instance.pid = Number((await execute('xdotool', ['getwindowpid', instance.window])).stdout.trim());
        const stat = fs.readFileSync(`/proc/${instance.pid}/stat`, 'utf8');
        instance.pidStart = stat.slice(stat.lastIndexOf(')') + 2).trim().split(/\s+/)[19];
        run.processes.push({ phase, instance: instance.index, pid: instance.pid, start: instance.pidStart, window: instance.window });
        await execute('xdotool', ['windowsize', instance.window, String(config.width), String(config.height), 'windowmove', instance.window,
          String((instance.index % 3) * config.width), String(Math.floor(instance.index / 3) * config.height)]);
        return;
      }
      if (instance.child.exitCode !== null) throw new Error(`app ${instance.index} exited during startup`);
      await delay(100);
    }
    throw new Error(`app ${instance.index} did not restore ${instance.tabs.length} tabs / heartbeat`);
  }
  async function browserFixture(instance, localIndex) {
    const title = `chat-bench-browser-${instance.index}-${localIndex}`;
    const find = async () => (await execute('xdotool', ['search', '--name', `^${title}$`]).catch(() => ({ stdout: '' }))).stdout.trim();
    if (await find()) return title;
    spawn('wine', [winPath(browserExe), title], { env, stdio: ['ignore', logFd, logFd] });
    const deadline = performance.now() + 5000;
    while (performance.now() < deadline) { if (await find()) return title; await pump(); await delay(50); }
    throw new Error(`Foreign browser fixture did not open: ${title}`);
  }
  async function stopApps() {
    for (const instance of instances) { instance.live = false; atomic(path.join(instance.mailbox, 'command'), `${++seq} quit`); }
    const deadline = performance.now() + 15_000;
    const guiAlive = () => [...snapshot().values()].some(p => p.gui);
    while (performance.now() < deadline && guiAlive()) { await pump(); await delay(100); }
    if (guiAlive()) {
      run.errors.push(`${phase}: app did not close within 15 s; forced isolated-prefix stop`);
      await execute('wineserver', ['-k'], { env, timeout: 15_000 });
    }
    for (const instance of instances) {
      const child = instance.child; instance.child = null; child?.kill('SIGKILL');
    }
  }
  let imageCache;
  async function screenshotInk(file, rect) {
    if (!rect || rect.right <= rect.left || rect.bottom <= rect.top) return { colors: 0, inkPixels: 0 };
    if (imageCache?.file !== file) {
      const rgb = await execute('convert', [file, '-depth', '8', 'rgb:-'], { encoding: 'buffer', maxBuffer: config.width * config.height * 3 + 1024, timeout: 5000 });
      if (rgb.stdout.length !== config.width * config.height * 3) throw new Error('Unexpected screenshot dimensions');
      imageCache = { file, rgb: rgb.stdout };
    }
    const x = Math.max(0, rect.left), y = Math.max(0, rect.top);
    const width = Math.min(rect.right - x, config.width - x), height = Math.min(rect.bottom - y, config.height - y);
    if (width <= 0 || height <= 0) return { colors: 0, inkPixels: 0 };
    const cropped = Buffer.alloc(width * height * 3);
    for (let row = 0; row < height; row++) imageCache.rgb.copy(cropped, row * width * 3, ((y + row) * config.width + x) * 3, ((y + row) * config.width + x + width) * 3);
    return imageInk(cropped);
  }
  function geometryFor(instance, requestSeq) {
    const file = path.join(instance.mailbox, 'geometry.json');
    if (!fs.existsSync(file)) return null;
    const geometry = JSON.parse(fs.readFileSync(file));
    return geometry.seq === requestSeq ? geometry : null;
  }
  async function captureEarly(instance, requestSeq, localIndex) {
    const geometry = geometryFor(instance, requestSeq);
    const file = path.join(screenshots, `${phase}-${String(requestSeq).padStart(4, '0')}-early-tab-${instance.tabs[localIndex].index}.png`);
    await execute('import', ['-window', instance.window, file], { timeout: 5000 });
    const ink = geometry ? await screenshotInk(file, { left: geometry.pane_left + 26, right: geometry.pane_right - 26, top: geometry.layout.transcript.top + 12, bottom: geometry.layout.transcript.top + 44 }, geometry) : { inkPixels: 0 };
    return { earlyScreenshot: file, earlyGeometry: geometry, earlyContent: (geometry?.blocks || 0) > 0, loadingInk: !!geometry?.loading && ink.inkPixels >= 15 };
  }
  async function countForeignBrowsersOnScreen(instance) {
    const ids = (await execute('xdotool', ['search', '--onlyvisible', '--name', `^chat-bench-browser-${instance.index}-`]).catch(() => ({ stdout: '' }))).stdout.trim().split(/\s+/).filter(Boolean);
    let count = 0;
    for (const id of ids) {
      const shell = (await execute('xdotool', ['getwindowgeometry', '--shell', id]).catch(() => ({ stdout: '' }))).stdout;
      const x = Number(/X=(-?\d+)/.exec(shell)?.[1]), y = Number(/Y=(-?\d+)/.exec(shell)?.[1]);
      const w = Number(/WIDTH=(\d+)/.exec(shell)?.[1]), h = Number(/HEIGHT=(\d+)/.exec(shell)?.[1]);
      if ([x, y, w, h].every(Number.isFinite) && x + w > 0 && y + h > 0 && x < config.width * 3 && y < config.height * 2) count++;
    }
    return count;
  }
  async function capture(instance, requestSeq, localIndex, early) {
    const tab = instance.tabs[localIndex], log = parseLog(instance.text);
    const paints = log.paints.filter(p => p.seq === requestSeq && p.tab === localIndex);
    const first = paints.find(p => p.first), content = paints.find(p => p.blocks > 0 && p.chars > 0 && (tab.provider === 'shell' || p.file));
    const file = path.join(screenshots, `${phase}-${String(requestSeq).padStart(4, '0')}-tab-${tab.index}.png`);
    await execute('import', ['-window', instance.window, file], { timeout: 5000 });
    const geometry = geometryFor(instance, requestSeq);
    const foreignBrowsersOnScreen = await countForeignBrowsersOnScreen(instance);
    const geometryInside = containsLayout(geometry);
    const ink = geometry ? await screenshotInk(file, { left: geometry.pane_left + 16, right: geometry.pane_right - 16, top: geometry.layout.transcript.top, bottom: geometry.layout.transcript.bottom }, geometry) : { colors: 0, inkPixels: 0 };
    const titleInk = geometryInside ? await screenshotInk(file, geometry.title, geometry) : { inkPixels: 0 };
    const attachInk = geometryInside ? await screenshotInk(file, geometry.layout.attach_btn, geometry) : { inkPixels: 0 };
    const sendInk = geometryInside ? await screenshotInk(file, geometry.layout.send_btn, geometry) : { inkPixels: 0 };
    run.switches.push({ phase, seq: requestSeq, index: tab.index, instance: instance.index, localIndex, browser: tab.browser,
      firstPaintMs: first?.ms ?? null, contentPaintMs: content?.ms ?? null, blocks: content?.blocks ?? 0, chars: content?.chars ?? 0,
      screenshot: file, sha256: hash(file), geometry, geometryInside, foreignBrowsersOnScreen, headerInk: titleInk.inkPixels >= 15, composerInk: attachInk.inkPixels >= 15 && sendInk.inkPixels >= 15,
      ...early, ...ink, nonEmpty: ink.colors > 4 && ink.inkPixels >= config.rules.minimumChatInkPixels && (tab.provider === 'shell' || !!content) });
  }
  async function measure(name) {
    phase = name; phaseStart = performance.now(); previousTime = phaseStart; previous = snapshot(); lastAppend = phaseStart;
    let end = phaseStart + config.minutes * 60_000 / 2;
    const rounds = Math.max(...instances.map(i => i.tabs.length));
    let nextSwitch = phaseStart, round = 0;
    while (performance.now() < end) {
      await pump();
      const now = performance.now();
      if (round < rounds && now >= nextSwitch) {
        const pending = [];
        for (const instance of instances) {
          if (round >= instance.tabs.length) continue;
          instance.active = round;
          const commandSeq = ++seq;
          const browserTitle = instance.tabs[round].browser === 'docked' ? await browserFixture(instance, round) : '';
          atomic(path.join(instance.mailbox, 'command'), `${commandSeq} ${round} ${instance.tabs[round].browser} ${browserTitle}`);
          pending.push([instance, commandSeq, round]);
        }
        lastAction = now;
        const until = Math.min(end, now + config.switchSeconds * 1000);
        const early = new Map(), acknowledged = new Map();
        while (performance.now() < until) {
          await pump();
          for (const item of pending) {
            const [instance, commandSeq, localIndex] = item;
            if (!acknowledged.has(commandSeq) && parseLog(instance.text).paints.some(p => p.seq === commandSeq)) acknowledged.set(commandSeq, performance.now());
            if (!early.has(commandSeq) && performance.now() - acknowledged.get(commandSeq) >= (phase === 'warm' ? 800 : 200)) early.set(commandSeq, await captureEarly(instance, commandSeq, localIndex));
          }
          await delay(50);
        }
        for (const item of pending) { await capture(...item, early.get(item[1])); await pump(); }
        nextSwitch = performance.now(); round++;
        if (round === rounds) end = Math.max(end, lastAction + (config.idleSettleSeconds + config.idleSeconds) * 1000);
      }
      const appendNow = performance.now();
      if (appendNow < end - (config.idleSeconds + config.idleSettleSeconds) * 1000 && appendNow - lastAppend >= config.appendSeconds * 1000) {
        for (const instance of instances.filter(i => i.index % 2 === 0)) {
          const tab = instance.tabs[instance.active];
          if (!tab.file) continue;
          const bytes = records(tab.provider, tab.sid, tab.turns++, true).map(r => JSON.stringify(r) + '\n').join('');
          fs.appendFileSync(tab.file, bytes);
          run.appends.push({ phase, index: tab.index, bytes: Buffer.byteLength(bytes), size: fs.statSync(tab.file).size });
        }
        lastAppend = appendNow; lastAction = appendNow;
      }
      await delay(50);
    }
  }
  try {
    if (await waitForCapacity()) {
      await execute(process.env.ZIG || 'zig', ['cc', '-target', 'x86_64-windows-gnu', '-O2', '-municode', '-Wl,--subsystem,windows', path.join(path.dirname(script), 'browser-fixture.c'), '-o', browserExe, '-luser32'], { timeout: 60_000, maxBuffer: 1024 * 1024 });
      run.runnerHashes.browser = hash(path.join(path.dirname(script), 'browser-fixture.c'));
      await execute('xdpyinfo', [], { timeout: 5000, maxBuffer: 1024 * 1024 });
      await execute('wineboot', ['--init'], { env, timeout: 180_000, maxBuffer: 1024 * 1024 });
      timer = setInterval(() => { try { sample(); } catch (error) { run.errors.push(`sample: ${error.message}`); } }, config.sampleMs);
      for (const instance of instances) await start(instance);
      await measure('cold');
      phase = 'restart';
      await stopApps();
      for (const instance of instances) {
        instance.text = ''; instance.offset = fs.statSync(path.join(instance.appdata, 'ZigShell/debug.log')).size;
        instance.window = null; instance.live = true; instance.lastHeartbeat = 0;
        const sessionFile = path.join(instance.appdata, `ZigShell/session-bench-${instance.index}.json`);
        const saved = JSON.parse(fs.readFileSync(sessionFile)); saved.active_tab = 0;
        for (const tab of saved.tabs) tab.bon = false;
        atomic(sessionFile, JSON.stringify(saved));
        for (const file of fs.readdirSync(instance.mailbox)) fs.unlinkSync(path.join(instance.mailbox, file));
        await start(instance);
      }
      run.restarted = true;
      await measure('warm');
      phase = 'shutdown'; await stopApps();
    }
  } catch (error) { if (isOutsideKill(error.signal)) run.infra.push(`command killed by SIGKILL from outside the bench (server capacity): ${error.message}`); run.errors.push(error.stack); }
  finally {
    stopping = true; clearInterval(timer); reader.kill('SIGTERM'); service.close();
    await execute('wineserver', ['-k'], { env, timeout: 15_000 }).catch(error => {
      if (error.code !== 1 || snapshot().size) run.errors.push(`prefix cleanup: ${error.message}`);
    });
    for (const instance of instances) instance.child?.kill('SIGKILL');
    await execute('wineserver', ['-w'], { env, timeout: 15_000 }).then(() => {
      fs.rmSync(prefix, { recursive: true, force: true });
    }).catch(error => run.errors.push(`prefix removal: ${error.message}`));
    process.removeListener('SIGINT', onInt); process.removeListener('SIGTERM', onTerm);
    fs.closeSync(logFd);
  }
  const images = run.switches.map(s => s.screenshot);
  if (images.length) {
    await execute('montage', [...images, '-thumbnail', '256x160', '-tile', '8x', '-geometry', '+2+2', path.join(out, 'contact-sheet.png')], { timeout: 120_000, maxBuffer: 1024 * 1024 }).catch(error => run.errors.push(`contact sheet: ${error.message}`));
  } else run.errors.push('no screenshots');
  run.diagnostics = instances.map(instance => {
    const log = path.join(instance.appdata, 'ZigShell/debug.log');
    return { instance: instance.index, log, sha256: fs.existsSync(log) ? hash(log) : null,
      ...parseLog(fs.existsSync(log) ? fs.readFileSync(log, 'utf8') : '') };
  });
  if (hash(exe) !== binary.exeSha256 || hash(binary.reader) !== binary.readerSha256) run.errors.push('artifacts changed during run');
  run.errors = [...new Set(run.errors)];
  run.finished = new Date().toISOString();
  run.oomKills = 0;
  try {
    const cgroup = fs.readFileSync('/proc/self/cgroup', 'utf8').match(/^0::(.*)$/m)?.[1];
    if (cgroup) run.oomKills = Number(fs.readFileSync(`/sys/fs/cgroup${cgroup}/memory.events`, 'utf8').match(/^oom_kill (\d+)$/m)?.[1] || 0);
  } catch (error) { if (error.code !== 'ENOENT') throw error; }
  const verdict = evaluate(run, config);
  atomic(path.join(out, 'results.json'), JSON.stringify({ ...run, ...verdict }, null, 2));
  const summary = `${verdict.status} ${binary.version}\n${JSON.stringify(verdict.metrics, null, 2)}\n${verdict.failures.join('\n')}\n${verdict.status === 'INFRA' ? 'INFRA: the server killed the bench or had no capacity; this is not a verdict on the build. Retry with a new --out when load is lower.\n' : ''}Output: ${out}\n`;
  atomic(path.join(out, 'summary.txt'), summary); console.log(summary);
  process.exitCode = verdict.status === 'PASS' ? 0 : verdict.status === 'INFRA' ? 75 : 1;
}
