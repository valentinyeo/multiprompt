const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const lib = import('./chat-bench/lib.mjs');

test('capture helpers are limited to one thread without changing the GUI workload', () => {
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const start = source.indexOf('async function run() {') + 'async function run() {'.length;
  const preamble = source.slice(start, source.indexOf('  const prefix =', start));
  const env = { MAGICK_THREAD_LIMIT: '18', WINEPREFIX: '/fixture' };
  require('node:vm').runInNewContext(preamble, { process: { env } });
  assert.equal(env.MAGICK_THREAD_LIMIT, '1');
  assert.equal(env.WINEPREFIX, '/fixture');
});

test('slow captures cannot truncate the configured settling period and idle tail', async () => {
  const { defaults } = await lib;
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const measure = source.slice(source.indexOf('  async function measure(name) {'), source.indexOf('\n  try {', source.indexOf('  async function measure(name) {')));
  let now = 0, captures = 0;
  const context = require('node:vm').createContext({
    config: defaults, performance: { now: () => now },
    instances: [{ tabs: Array.from({ length: 7 }, () => ({ browser: 'none' })), mailbox: '/fixture', index: 0 }],
    pump: async () => {}, snapshot: () => new Map(),
    delay: async ms => { now += ms; },
    capture: async () => { now += 3000; captures++; },
    parseLog: () => ({ paints: [] }), atomic: () => {}, path,
    seq: 0, lastAction: 0,
  });
  await require('node:vm').runInContext(`${measure}\nmeasure('cold')`, context);
  assert.equal(captures, 7, 'every tab must still be captured');
  assert(now >= context.lastAction + (defaults.idleSettleSeconds + defaults.idleSeconds) * 1000,
    'measurement must retain the full idle tail after the last action settles');
});

test('real-format synthetic Claude/Codex fixtures include tool, image, injected and rich messages', async () => {
  const { generate, defaults, records } = await lib;
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-fixture-test-'));
  try {
    const result = generate(root, { ...defaults, tabs: 5, windows: 2 });
    assert.equal(result.tabs.length, 5);
    const claude = records('claude', 'claude-test', 0);
    assert(claude.some(e => e.message.content.some(p => p.type === 'image')));
    assert(claude.some(e => e.message.content.some(p => p.type === 'tool_use')));
    assert(claude.some(e => e.message.content.some(p => p.type === 'tool_result')));
    assert(claude.some(e => e.message.content.some(p => p.text?.includes('<cross-session-message'))));
    assert(claude.some(e => e.message.content.some(p => p.text?.includes('```zig') && p.text.includes('| Case |'))));
    for (const tab of result.tabs.filter(t => t.file)) {
      assert(fs.statSync(tab.file).size >= tab.targetBytes);
      const query = { id: 7, codex: tab.provider === 'codex', sid: tab.sid, tmux: '', cwd: '/bench/project', cached_sid: '', inode: 0, offset: 0, mtime: 0, probe: '' };
      const wire = execFileSync('python3', ['src/chat_history_reader.py', Buffer.from(JSON.stringify(query)).toString('base64')], { env: { ...process.env, HOME: result.home }, encoding: 'utf8' });
      assert.match(wire, /^@mp\t7\thistory\tok\t/);
      assert.match(wire, /"role":"assistant"/);
      assert.match(wire, /@@MP_END@@\n$/);
      const session = JSON.parse(fs.readFileSync(path.join(result.instances[0].appdata, 'ZigShell/session.json')));
      assert.equal(session.chat_view_mode, 'everywhere');
      assert(session.tabs.every(t => t.cv && !t.bon && (t.csid ? t.kind === 'tmux' : t.kind === 'cmd')));
    }
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

function goodRun() {
  const tabs = ['none', 'pending', 'docked'].map((browser, index) => ({ index, browser, sid: `claude-${index}`, file: '/fixture' }));
  return { errors: [], fixtures: { tabs }, samples: Array.from({ length: 60 }, (_, i) => ({ measured: true, idle: true, phase: 'warm', timeMs: (i + 1) * 1000, elapsedMs: 1000, cpu: 2, rssBytes: 1048576 })),
    switches: ['cold', 'warm'].flatMap(phase => tabs.map(tab => ({ phase, index: tab.index, firstPaintMs: 20, contentPaintMs: 20, screenshot: 'capture.png', nonEmpty: true, geometry: { browser_foreign: true, browser_live: true }, geometryInside: true, headerInk: true, composerInk: true, earlyContent: true }))),
    restarted: true, appends: [{}], readerResponses: tabs.map(t => ({ sid: t.sid, ok: true, hasLive: true })) };
}

test('acceptance is fail-closed with positive controls for CPU, spikes, timing, empty chat, crash and hang', async () => {
  const { evaluate, defaults } = await lib;
  assert.equal(evaluate(goodRun(), defaults).pass, true);
  for (const [name, mutate] of [
    ['idle CPU', r => r.samples.forEach(s => { s.cpu = 12; })],
    ['sustained CPU', r => r.samples.slice(5, 40).forEach(s => { s.cpu = 300; s.idle = false; })],
    ['paint latency', r => r.switches.forEach(s => { s.firstPaintMs = 310; })],
    ['blank screenshot', r => { r.switches[0].nonEmpty = false; }],
    ['missing timing', r => r.switches.forEach(s => { s.firstPaintMs = null; })],
    ['crash', r => r.errors.push('app exited unexpectedly')],
    ['hang', r => r.errors.push('heartbeat stalled')],
    ['no CPU samples', r => { r.samples = []; }],
    ['no restart', r => { r.restarted = false; }],
    ['append never reaches reader', r => r.readerResponses.forEach(response => { response.hasLive = false; })],
    ['transport missing', r => { r.readerResponses = []; }]
  ]) {
    const run = goodRun(); mutate(run); assert.equal(evaluate(run, defaults).pass, false, name);
  }
});

test('missing switch paint cannot masquerade as a fast p95 from successful switches', async () => {
  const { evaluate, defaults } = await lib;
  const run = goodRun(); run.switches[0].firstPaintMs = null;
  const result = evaluate(run, defaults);
  assert.equal(result.metrics.switchPaintP95Ms, null);
  assert.equal(result.metrics.acknowledgedPaintP95Ms, 20);
  assert.equal(result.pass, false);
});

test('thirty-second CPU uses elapsed time, not thirty arbitrarily spaced samples', async () => {
  const { evaluate, defaults } = await lib;
  const run = goodRun();
  run.samples = run.samples.map((s, i) => ({ ...s, elapsedMs: 100, timeMs: (i + 1) * 100, cpu: 100 }));
  const result = evaluate(run, defaults);
  assert.equal(result.metrics.thirtySecondPeakCpu, null);
  assert(result.failures.includes('insufficient thirty-second CPU evidence'));
});

test('screenshot ink oracle rejects a blank area and detects painted pixels', async () => {
  const { imageInk } = await lib;
  const blank = Buffer.alloc(3000, 24);
  assert.equal(imageInk(blank).inkPixels, 0);
  const painted = Buffer.from(blank); painted.fill(200, 0, 600);
  assert.equal(imageInk(painted).inkPixels, 200);
  assert.throws(() => imageInk(Buffer.alloc(2)));
});

test('proc CPU accounts for all app threads, RSS and PID reuse; ignores new-process lifetime', async () => {
  const { cpuDelta } = await lib;
  const old = new Map([[42, { ticks: 100, start: 'a' }], [43, { ticks: 50, start: 'b' }]]);
  const current = new Map([[42, { ticks: 150, start: 'a', rssPages: 100 }], [43, { ticks: 500, start: 'new', rssPages: 20 }]]);
  assert.deepEqual(cpuDelta(old, current, 1000, 100, 4096), { cpu: 50, rssBytes: 120 * 4096, pids: [42, 43] });
});

test('paint logs distinguish first paint from real content and preserve production diagnostics', async () => {
  const { parseLog } = await lib;
  const parsed = parseLog('[bench] painted seq=2 tab=1 ms=20 blocks=0 chars=0 first=1 file=0\n[bench] painted seq=2 tab=1 ms=120 blocks=8 chars=500 first=0 file=1\n[bench] heartbeat seq=2 tabs=7 active=1\nPERF[t=10] paint=9\n[switch] chat painted in 20 ms\n[chat] transcript load shell=1 ok bytes=900 ms=20');
  assert.equal(parsed.paints.length, 2);
  assert.equal(parsed.paints[0].blocks, 0);
  assert.equal(parsed.paints[1].chars, 500);
  assert.equal(parsed.heartbeat.tabs, 7);
  assert.equal(parsed.perf.length, 1);
  assert.equal(parsed.chat.length, 1);
});

test('proc discovery counts only Wine app/collector processes in this prefix, not Node or other runs', async () => {
  const { procSnapshot } = await lib;
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-proc-test-'));
  const prefix = '/scratch/bench/prefix', exe = '/build/multiprompt.exe';
  try {
    const make = (pid, loader, args, env) => {
      const dir = path.join(root, String(pid)); fs.mkdirSync(dir);
      fs.symlinkSync(loader, path.join(dir, 'exe'));
      fs.writeFileSync(path.join(dir, 'cmdline'), args.join('\0') + '\0');
      fs.writeFileSync(path.join(dir, 'environ'), env + '\0');
      const tail = Array(25).fill('0'); tail[0] = 'S'; tail[11] = '123'; tail[12] = '45'; tail[19] = String(pid); tail[21] = '400';
      fs.writeFileSync(path.join(dir, 'stat'), `${pid} (name with ) parentheses) ${tail.join(' ')}`);
    };
    make(100, '/usr/lib/wine/wine64', ['Z:\\build\\multiprompt.exe', '--name', 'bench-0'], `WINEPREFIX=${prefix}`);
    make(101, '/usr/lib/wine/wine64', ['Z:\\build\\multiprompt.exe', '--usage-telemetry'], `WINEPREFIX=${prefix}`);
    make(102, '/usr/bin/node', ['node', 'run.mjs', '--exe', exe], `WINEPREFIX=${prefix}`);
    make(103, '/usr/lib/wine/wine64', [exe], 'WINEPREFIX=/other/prefix');
    make(104, '/usr/lib/wine/wine64', ['C:\\windows\\system32\\cmd.exe'], `WINEPREFIX=${prefix}`);
    const snapshot = procSnapshot(prefix, exe, root);
    assert.deepEqual([...snapshot.keys()], [100, 101]);
    assert.deepEqual(snapshot.get(100), { ticks: 168, rssPages: 400, start: '100', gui: true });
    assert.equal(snapshot.get(101).gui, false);
    fs.writeFileSync(path.join(root, '100/cmdline'), 'Z:\\build\\multiprompt.exe --name bench-0    ');
    fs.writeFileSync(path.join(root, '101/cmdline'), `${exe} --usage-telemetry    `);
    assert.equal(procSnapshot(prefix, exe, root).has(100), true);
    assert.equal(procSnapshot(prefix, exe, root).get(101).gui, false);
    fs.writeFileSync(path.join(root, '100/environ'), 'WINEPREFIX=/changed/environment\0');
    assert.equal(procSnapshot(prefix, exe, root).has(100), false);
    assert.equal(procSnapshot(prefix, exe, root, new Map([[100, '100']])).get(100).gui, true);
    assert.equal(procSnapshot(prefix, exe, root, new Map([[100, 'reused']])).has(100), false);
  } finally { fs.rmSync(root, { recursive: true, force: true }); }
});

test('a five-second cold burst is allowed, but a sustained multi-core loop is rejected', async () => {
  const { evaluate, defaults } = await lib;
  const burst = goodRun();
  burst.samples.slice(5, 10).forEach(s => { s.cpu = 400; s.idle = false; });
  assert.equal(evaluate(burst, defaults).pass, true);
  assert.equal(evaluate(burst, defaults).metrics.fiveSecondPeakCpu, 400);
  const sustained = goodRun();
  sustained.samples.slice(5, 40).forEach(s => { s.cpu = 600; s.idle = false; });
  assert(evaluate(sustained, defaults).failures.includes('thirty-second CPU'));
  const split = goodRun();
  split.samples = split.samples.slice(0, 40).map((s, i) => ({ ...s, phase: i < 20 ? 'cold' : 'warm' }));
  assert(evaluate(split, defaults).failures.includes('insufficient thirty-second CPU evidence'));
});

test('browser regression oracle rejects clipped header, split composer, blank loading and remote-blocked cache', async () => {
  const { evaluate, defaults, geometryInside } = await lib;
  const rect = { left: 250, right: 790, top: 70, bottom: 900 };
  const good = { pane_left: 240, pane_right: 800, title: rect, transcript: rect, composer: rect, layout: { transcript: rect, composer: rect, composer_card: rect, attach_btn: rect, send_btn: rect } };
  assert.equal(geometryInside(good), true);
  for (const mutate of [g => { g.title = { ...rect, left: 700, right: 1000 }; }, g => { g.layout.composer_card = { ...rect, right: 1100 }; }, g => { g.composer = { ...rect, left: 260 }; }]) {
    const g = structuredClone(good); mutate(g); assert.equal(geometryInside(g), false);
  }
  for (const mutate of [r => { r.switches[2].geometry.browser_foreign = false; }, r => { r.switches[0].geometryInside = false; }, r => { r.switches[0].headerInk = false; }, r => { r.switches[0].composerInk = false; }, r => { r.switches[0].earlyContent = false; r.switches[0].loadingInk = false; }, r => { r.switches[3].contentPaintMs = 5000; }, r => { r.switches[3].earlyContent = false; }]) {
    const r = goodRun(); mutate(r); assert.equal(evaluate(r, defaults).pass, false);
  }
});
