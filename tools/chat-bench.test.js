const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const lib = import('./chat-bench/lib.mjs');
const fixture = import('./chat-bench/good-run.mjs');

test('capture helpers are limited to one thread without changing the GUI workload', () => {
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const start = source.indexOf('  process.env.MAGICK_THREAD_LIMIT');
  const preamble = source.slice(start, source.indexOf('  const prefix =', start));
  const env = { MAGICK_THREAD_LIMIT: '18', WINEPREFIX: '/fixture' };
  require('node:vm').runInNewContext(preamble, { process: { env } });
  assert.equal(env.MAGICK_THREAD_LIMIT, '1');
  assert.equal(env.WINEPREFIX, '/fixture');
});

test('outer launch inherits nice 15 and scopes Xvfb with the configured maxRssMiB', () => {
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const launch = source.slice(source.indexOf("if (!process.env.CHAT_BENCH_XVFB) {") + "if (!process.env.CHAT_BENCH_XVFB) {".length, source.indexOf('} else {\n    await run('));
  assert.match(launch, /spawn\('systemd-run'/);
  assert.match(launch, /MemoryMax=\$\{config\.rules\.maxRssMiB\}M/);
  for (const priority of [0, 15, 19]) for (const smoke of [false, true]) {
    const args = smoke ? ['--smoke', '--exe', 'app.exe', '--minutes', '5', '--config', 'custom.json'] : ['--exe', 'app.exe'];
    const changes = [], calls = [];
    require('node:vm').runInNewContext(launch, {
      os: { getPriority: () => priority, setPriority: value => changes.push(value) },
      process: { env: {}, pid: 42, execPath: '/node', argv: ['node', 'run.mjs', ...args, '--out', '/original'], on: () => {} },
      config: { width: 1280, height: 800, windows: 6, rules: { maxRssMiB: 4321 } },
      path, out: '/bench', script: '/run.mjs',
      spawn: (...args) => { calls.push(args); return { on: () => {} }; },
    });
    assert.deepEqual(changes, priority < 15 ? [15] : []);
    assert.equal(calls.length, 1);
    assert.equal(calls[0][0], 'systemd-run');
    assert.deepEqual(Array.from(calls[0][1].slice(0, 10)), ['--user', '--scope', '--quiet', '-p', 'MemoryMax=4321M', '-p', 'MemorySwapMax=0', '--', 'xvfb-run', '-a']);
    assert.deepEqual(Array.from(calls[0][1].slice(calls[0][1].indexOf('/run.mjs') + 1)), [...args, '--out', '/bench']);
    assert.equal(calls[0][2].env.CHAT_BENCH_XVFB, '1');
    assert.equal(calls[0][2].detached, true);
  }
});

test('OOM evidence reads this process cgroup and defaults to zero for missing files', () => {
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const collect = source.slice(source.indexOf('  run.oomKills = 0;'), source.indexOf('  const verdict = evaluate(run, config);'));
  assert(collect.includes('/proc/self/cgroup'));
  for (const events of ['low 0\nhigh 0\noom 3\noom_kill 2\noom_group_kill 0\n', 'oom 3\n', null]) {
    const run = {}, reads = [];
    require('node:vm').runInNewContext(collect, { run, fs: { readFileSync: file => {
      reads.push(file);
      if (file === '/proc/self/cgroup') return '1:name=systemd:/unrelated\n0::/user.slice/bench.scope\n';
      assert.equal(file, '/sys/fs/cgroup/user.slice/bench.scope/memory.events');
      if (events === null) throw Object.assign(new Error('missing'), { code: 'ENOENT' });
      return events;
    } } });
    assert.equal(run.oomKills, events?.includes('oom_kill 2') ? 2 : 0);
    assert.equal(reads.length, 2);
  }
});

test('own-scope OOM kills are memory FAILs, not outside-SIGKILL INFRA', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
  const run = goodRun();
  const kill = 'app 0 killed by SIGKILL from outside the bench (server capacity)';
  run.oomKills = 2; run.infra = [kill]; run.errors = [kill];
  const result = evaluate(run, defaults);
  assert.equal(result.status, 'FAIL');
  assert.equal(result.pass, false);
  assert.deepEqual(result.failures, [`memory cap ${defaults.rules.maxRssMiB} MiB exceeded (2 process(es) killed by the bench's own memory limit)`]);
});

test('peak RSS above maxRssMiB is a memory FAIL without an OOM kill', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
  const run = goodRun();
  run.samples[0].rssBytes = (defaults.rules.maxRssMiB + 1) * 1048576;
  const result = evaluate(run, defaults);
  assert.equal(result.status, 'FAIL');
  assert.equal(result.pass, false);
  assert(result.failures.some(f => f.startsWith(`memory cap ${defaults.rules.maxRssMiB} MiB exceeded`)));
});

test('unchanged good run and peak RSS at the memory cap remain PASS', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
  const run = goodRun();
  assert.equal(defaults.rules.maxRssMiB, 12000);
  assert.equal(evaluate(run, defaults).status, 'PASS');
  run.oomKills = 0;
  run.samples[0].rssBytes = defaults.rules.maxRssMiB * 1048576;
  assert.equal(evaluate(run, defaults).status, 'PASS');
  run.infra = ['app 0 killed by SIGKILL from outside the bench (server capacity)'];
  assert.equal(evaluate(run, defaults).status, 'INFRA');
});

test('slow captures cannot truncate the configured settling period and idle tail', async () => {
  const { defaults, earlyCaptureDue, tornFrame, finalCaptureDue } = await lib;
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
    seq: 0, lastAction: 0, earlyCaptureDue, tornFrame, finalCaptureDue, geometryFor: () => null,
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

test('acceptance is fail-closed with positive controls for CPU, spikes, timing, empty chat, crash and hang', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
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
    ['transport missing', r => { r.readerResponses = []; }],
    ['two browser panes on screen', r => { r.switches[0].foreignBrowsersOnScreen = 2; }],
    ['browser panes not counted', r => { delete r.switches[0].foreignBrowsersOnScreen; }]
  ]) {
    const run = goodRun(); mutate(run); assert.equal(evaluate(run, defaults).pass, false, name);
  }
});

test('missing switch paint cannot masquerade as a fast p95 from successful switches', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
  const run = goodRun(); run.switches[0].firstPaintMs = null;
  const result = evaluate(run, defaults);
  assert.equal(result.metrics.switchPaintP95Ms, null);
  assert.equal(result.metrics.acknowledgedPaintP95Ms, 20);
  assert.equal(result.pass, false);
});

test('thirty-second CPU uses elapsed time, not thirty arbitrarily spaced samples', async () => {
  const { evaluate, defaults } = await lib;
  const { goodRun } = await fixture;
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
  const { goodRun } = await fixture;
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
  const { goodRun } = await fixture;
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

test('runner requires an executable before reading a smoke config or starting work', async () => {
  const { parseArgs } = await lib;
  assert.equal(parseArgs([]).options.exe, undefined);
  for (const args of [[], ['--smoke', '--config', '/nonexistent.json']]) {
    const result = spawnSync(process.execPath, [path.join(__dirname, 'chat-bench/run.mjs'), ...args], { encoding: 'utf8', timeout: 5000 });
    assert.equal(result.error, undefined);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /--exe is required/);
    assert.equal(result.stdout, '');
  }
});

test('documented smoke guard rejects duration and config overrides without doing IO', async () => {
  const { parseArgs, defaults } = await lib;
  for (const args of [['--minutes', '5'], ['--config', '/nonexistent.json'], ['--minutes', String(defaults.minutes)]]) {
    assert.throws(() => parseArgs(['--exe', '/nonexistent.exe', ...args]), error => {
      assert.match(error.message, /--smoke/);
      assert.match(error.message, /install-laptop1\.sh only accepts default-config receipts/);
      return true;
    });
  }
});

test('documented smoke overrides parse purely and never become installable', async () => {
  const { parseArgs, defaults } = await lib;
  const before = structuredClone(defaults);
  for (const args of [['--smoke', '--minutes', '5'], ['--minutes', '5', '--smoke']]) {
    const parsed = parseArgs(['--exe', '/nonexistent.exe', ...args]);
    assert.equal(parsed.config.minutes, 5);
    assert.equal(parsed.installable, false);
  }
  assert.equal(parseArgs(['--exe', 'app.exe', '--smoke']).installable, false);
  const override = { minutes: 1, rules: { maxRssMiB: 4321 }, capacity: { waitMinutes: 1 } };
  const parsed = parseArgs(['--exe', 'app.exe', '--smoke', '--config', '/nonexistent.json', '--minutes', '5'], override);
  assert.equal(parsed.config.minutes, 5);
  assert.deepEqual(parsed.config.rules, { ...defaults.rules, maxRssMiB: 4321 });
  assert.deepEqual(parsed.config.capacity, { ...defaults.capacity, waitMinutes: 1 });
  assert.deepEqual(override, { minutes: 1, rules: { maxRssMiB: 4321 }, capacity: { waitMinutes: 1 } });
  assert.deepEqual(defaults, before);
  for (const minutes of ['0', '-1', 'NaN', 'Infinity']) assert.throws(() => parseArgs(['--exe', 'app.exe', '--smoke', '--minutes', minutes]), /Invalid config minutes/);
  assert.throws(() => parseArgs(['--exe', 'app.exe', '--minutes', '--smoke']), /Usage/);
});

test('documented runner import does not parse arguments or start bench work', () => {
  const result = spawnSync(process.execPath, ['--input-type=module', '-e', `
    process.argv = ['node', '/nonexistent-entry.mjs', '--minutes', '5'];
    await import(${JSON.stringify(require('node:url').pathToFileURL(path.join(__dirname, 'chat-bench/run.mjs')).href)});
    console.log('IMPORT_SAFE');
  `], { encoding: 'utf8', timeout: 5000 });
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout.trim(), 'IMPORT_SAFE');
});

test('documented smoke warning precedes output setup and the inner bench launch', async () => {
  const { parseArgs } = await lib;
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const main = source.slice(source.indexOf('async function main() {'), source.indexOf('\nasync function run('));
  for (const smoke of [false, true]) {
    const events = [];
    await require('node:vm').runInNewContext(`${main}\nmain()`, {
      parseArgs, path, process: { argv: ['node', 'run.mjs', '--exe', 'app.exe', '--out', '/bench', ...(smoke ? ['--smoke', '--minutes', '5'] : [])], env: { CHAT_BENCH_XVFB: '1' } },
      console: { log: message => events.push(message) }, fs: { mkdirSync: () => events.push('mkdir') },
      run: async options => { assert.equal(options.installable, !smoke); events.push('run'); },
    });
    assert.deepEqual(events.slice(-2), ['mkdir', 'run']);
    assert.equal(events.length, smoke ? 3 : 2);
    if (smoke) assert.match(events[0], /NOT INSTALLABLE/);
  }
});

test('documented smoke status is serialized in results.json', async () => {
  const { parseArgs } = await lib;
  const source = fs.readFileSync(path.join(__dirname, 'chat-bench/run.mjs'), 'utf8');
  const create = source.slice(source.indexOf('  const run = { schema:'), source.indexOf("  const hz ="));
  const write = source.match(/atomic\(path\.join\(out, 'results\.json'\),[^\n]+/)[0];
  for (const smoke of [false, true]) {
    const { config, installable } = parseArgs(['--exe', 'app.exe', ...(smoke ? ['--smoke'] : [])]);
    let result;
    require('node:vm').runInNewContext(`${create}\n${write}`, {
      requestedExe: 'app.exe', exe: 'app.exe', binary: {}, prefix: '/prefix', out: '/bench', config, installable, fixtures: {}, priority: 15,
      process: { env: {} }, hash: () => 'hash', script: '/run.mjs', path, verdict: { pass: true },
      atomic: (file, text) => { assert.equal(file, '/bench/results.json'); result = JSON.parse(text); },
    });
    assert.equal(result.installable, !smoke);
  }
});

test('documented smoke receipts are rejected even with default config and a clean PASS', async t => {
  const { defaults, hash } = await lib;
  const { goodRun } = await fixture;
  const { checkReceipt } = await import('./chat-bench/receipt.mjs');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'chat-bench-receipt-'));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  const exe = path.join(dir, 'app.exe'), pe = Buffer.alloc(256);
  pe.write('MZ'); pe.writeUInt32LE(0x80, 0x3c); pe.write('PE\0\0', 0x80); pe.writeUInt16LE(0x8664, 0x84);
  fs.writeFileSync(exe, pe);
  const run = { ...goodRun(), config: structuredClone(defaults), status: 'PASS', pass: true, failures: [], exe,
    binary: { exeSha256: hash(exe) },
    runnerHashes: Object.fromEntries(Object.entries({ run: 'run.mjs', lib: 'lib.mjs', service: 'reader-service.py', browser: 'browser-fixture.c' }).map(([key, file]) => [key, hash(path.join(__dirname, 'chat-bench', file))])) };
  for (const installable of [undefined, true, false]) {
    if (installable === undefined) delete run.installable;
    else run.installable = installable;
    const result = checkReceipt(run, run.binary.exeSha256);
    assert.equal(result.ok, installable !== false, result.reasons.join('; '));
    if (installable === false) assert.deepEqual(result.reasons, ['smoke run is NOT INSTALLABLE; install-laptop1.sh only accepts default-config receipts']);
  }
});

test('IGSH-684 early capture waits for the seq-stamped geometry', async () => {
  const { earlyCaptureDue } = await lib;
  assert.equal(earlyCaptureDue({ phase: 'cold', sinceAckMs: 300, geometry: null, seq: 1 }), false);
  assert.equal(earlyCaptureDue({ phase: 'cold', sinceAckMs: 300, geometry: { seq: 0 }, seq: 1 }), false);
  assert.equal(earlyCaptureDue({ phase: 'cold', sinceAckMs: 300, geometry: { seq: 1 }, seq: 1 }), true);
  assert.equal(earlyCaptureDue({ phase: 'cold', sinceAckMs: 100, geometry: { seq: 1 }, seq: 1 }), false);
  assert.equal(earlyCaptureDue({ phase: 'warm', sinceAckMs: 500, geometry: { seq: 1 }, seq: 1 }), false);
  assert.equal(earlyCaptureDue({ phase: 'warm', sinceAckMs: 900, geometry: { seq: 1 }, seq: 1 }), true);
  assert.equal(earlyCaptureDue({ phase: 'cold', sinceAckMs: NaN, geometry: { seq: 1 }, seq: 1 }), false);
});

test('IGSH-684 a frame without composer ink is torn', async () => {
  const { tornFrame } = await lib;
  assert.equal(tornFrame({ geometry: { seq: 1 }, composerInk: false }), true);
  assert.equal(tornFrame({ geometry: { seq: 1 }, composerInk: true }), false);
  assert.equal(tornFrame({ geometry: null, composerInk: false }), false);
});

test('IGSH-684 final capture waits for content but never past the phase end', async () => {
  const { finalCaptureDue } = await lib;
  assert.equal(finalCaptureDue({ now: 7000, until: 7000, end: 9000, file: true, contentSeen: false }), false);
  assert.equal(finalCaptureDue({ now: 7000, until: 7000, end: 9000, file: true, contentSeen: true }), true);
  assert.equal(finalCaptureDue({ now: 9000, until: 7000, end: 9000, file: true, contentSeen: false }), true);
  assert.equal(finalCaptureDue({ now: 7000, until: 7000, end: 9000, file: false, contentSeen: false }), true);
  assert.equal(finalCaptureDue({ now: 6999, until: 7000, end: 9000, file: false, contentSeen: true }), false);
});
