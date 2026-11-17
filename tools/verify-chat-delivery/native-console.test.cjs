const fs = require('node:fs');
const path = require('node:path');

function parse(text) {
  const events = [];
  let start, stop;
  const keys = ['kind', 'tick', 'received', 'hwnd', 'cls', 'parent', 'root', 'pid', 'left', 'top', 'right', 'bottom', 'visible', 'style', 'z', 'foreground'];
  for (const line of text.trim().split(/\r?\n/)) {
    const [type, ...values] = line.split('\t');
    if (type === 'start' && start == null) start = Number(values[0]);
    else if (type === 'stop' && stop == null) stop = Number(values[0]);
    else if (type === 'window' && values.length === keys.length) {
      const event = Object.fromEntries(keys.map((key, i) => [key, ['kind', 'cls'].includes(key) ? values[i] : Number(values[i])]));
      if (keys.some(key => typeof event[key] === 'number' && !Number.isSafeInteger(event[key]))) throw new Error('Invalid native window event');
      events.push({ ...event, sequence: events.length });
    } else throw new Error(`Incomplete native window recording: ${line}`);
  }
  if (!Number.isSafeInteger(start) || !Number.isSafeInteger(stop) || stop <= start) throw new Error('Missing native window hook start/stop');
  if (events.some(event => event.received < start || event.received > stop || event.tick > event.received)) throw new Error('Invalid native window clock');
  return { start, stop, events: events.sort((a, b) => a.tick - b.tick || a.sequence - b.sequence) };
}

function inspect(trace, doctor, phases) {
  if (!doctor.pid || !doctor.hwnd || !phases.length) throw new Error('Missing owned app or journey observations');
  if (phases.some(phase => !phase.end || phase.start < trace.start || phase.end > trace.stop)) throw new Error('Native window hook did not cover the complete journey');
  const windows = new Map();
  const flashes = [];
  const chatIntervals = [];
  let open = null;
  let consoles = 0;
  const overlaps = (a, b) => Math.min(a.right, b.right) > Math.max(a.left, b.left) && Math.min(a.bottom, b.bottom) > Math.max(a.top, b.top);
  for (const event of trace.events) {
    const old = windows.get(event.hwnd);
    const current = { ...old, ...event };
    if (old && event.right <= event.left) for (const key of ['left', 'top', 'right', 'bottom', 'root', 'parent', 'pid']) current[key] = old[key];
    current.shown = old?.shown ?? (event.kind === 'snapshot' && Boolean(event.style & 0x10000000));
    if (event.kind === 'create') current.shown = false;
    if (event.kind === 'show') current.shown = true;
    if (event.kind === 'hide' || event.kind === 'destroy') current.shown = false;
    windows.set(event.hwnd, current);
    if (event.cls === 'ConsoleWindowClass') consoles++;
    const main = windows.get(doctor.hwnd);
    const chat = [...windows.values()].find(window => window.cls === 'ZigShellChatTranscript' && window.pid === doctor.pid && window.root === doctor.hwnd && window.shown);
    const visible = main?.cls === 'ZigShell' && main.pid === doctor.pid && main.shown && chat;
    if (visible && open == null) open = event.tick;
    if (!visible && open != null) { chatIntervals.push({ start: open, end: event.tick }); open = null; }
    if (!visible) continue;
    for (const console of windows.values()) {
      if (console.cls !== 'ConsoleWindowClass' || !console.shown || !overlaps(console, chat)) continue;
      const attached = console.root === doctor.hwnd || console.parent === doctor.hwnd;
      const triggered = event.hwnd === console.hwnd && ['show', 'foreground', 'reorder', 'location', 'parent'].includes(event.kind);
      if (!attached && !triggered) continue;
      if (!attached && event.kind !== 'show' && event.foreground !== console.root && event.foreground !== console.hwnd) continue;
      if (flashes.some(flash => flash.console.hwnd === console.hwnd && flash.tick === event.tick)) continue;
      flashes.push({ tick: event.tick, received: event.received, event: event.kind, historicalShow: event.kind === 'show' && !event.visible, console: { ...console }, chat: { ...chat }, phase: phases.find(phase => event.tick >= phase.start && event.tick <= phase.end)?.name ?? 'between-actions' });
    }
  }
  if (open != null) chatIntervals.push({ start: open, end: trace.stop });
  if (!chatIntervals.some(interval => interval.end > interval.start)) throw new Error('No owned visible Chat View interval observed');
  if (!consoles) throw new Error('No native consoles observed; observer coverage unproven');
  return { status: flashes.length ? 'failed' : 'passed', eventCount: trace.events.length, chatIntervals, flashes };
}

if (require.main === module && process.argv.length === 3) {
  const evidence = process.argv[2];
  const output = path.join(evidence, 'native-console.json');
  try {
    const read = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
    const root = fs.existsSync(path.join(evidence, 'position-phases.json')) ? evidence : path.join(evidence, 'steady-live');
    const result = inspect(parse(fs.readFileSync(path.join(evidence, 'windows/windows.tsv'), 'utf8')), read(path.join(root, 'doctor.json')), read(path.join(root, 'position-phases.json')));
    fs.writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
    console.log(JSON.stringify({ status: result.status, events: result.eventCount, consoleFlashes: result.flashes.length }));
    if (result.status !== 'passed') process.exitCode = 1;
  } catch (error) {
    fs.writeFileSync(output, JSON.stringify({ status: 'incomplete', error: error.message }) + '\n');
    process.exitCode = 1;
  }
} else {
const { test } = require('node:test');
const assert = require('node:assert/strict');
test('the desktop journey starts native window observation before app launch and checks it after cleanup', () => {
  const driver = fs.readFileSync(path.join(__dirname, '../../.claude/skills/verify-multiprompt/drive.ps1'), 'utf8');
  const hook = driver.indexOf('$windows = [NativeConsoleRecorder]::new(');
  const launch = driver.indexOf('& powershell -NoProfile -File "$PSScriptRoot/control.ps1"');
  const stop = driver.indexOf('$windows.Dispose()');
  const oracle = driver.indexOf('tools/verify-chat-delivery/native-console.test.cjs');
  assert.ok(hook >= 0 && hook < launch, 'The desktop journey must observe native windows before launching the app');
  assert.ok(stop > launch && oracle > stop, 'The desktop journey must inspect native window evidence after owned cleanup');
  assert.match(driver, /\$observed\.nativeConsole\.status -eq 'incomplete'.*failureKind 'infrastructure'/);
  assert.match(driver, /Native console appeared over visible Chat View/);
});

const doctor = { pid: 42, hwnd: 10 };
const phases = [{ name: 'idle-long-reading', start: 110, end: 5000 }];
const window = (kind, tick, hwnd, cls, extra = {}) => ({ kind, tick, received: tick + 2, hwnd, cls, parent: 10, root: 10, pid: 42, left: 100, top: 100, right: 900, bottom: 800, visible: 1, style: 0x50000000, z: 0, foreground: 10, ...extra });
const main = window('show', 100, 10, 'ZigShell', { parent: 0, z: 1 });
const chat = window('show', 105, 11, 'ZigShellChatTranscript', { z: 2 });
const console = window('create', 108, 12, 'ConsoleWindowClass', { pid: 99, visible: 0 });
const trace = events => ({ start: 90, stop: 5100, events: [main, chat, console, ...events] });

test('hidden consoles do not fail a visible long-chat reader', () => {
  assert.equal(inspect(trace([]), doctor, phases).status, 'passed');
});

test('catches a brief child-console flash even if hidden before the callback and no chat paint occurs', () => {
  const show = window('show', 200, 12, 'ConsoleWindowClass', { pid: 99, visible: 0, received: 260 });
  const hide = { ...show, kind: 'hide', tick: 215, received: 261 };
  const result = inspect(trace([show, hide]), doctor, phases);
  assert.equal(result.status, 'failed');
  assert.equal(result.flashes.length, 1);
  assert.equal(result.flashes[0].historicalShow, true);
  assert.equal(result.flashes[0].console.root, main.hwnd);
  assert.equal(result.flashes[0].phase, 'idle-long-reading');
});

test('catches a top-level console overlay without mistaking it for an app child', () => {
  const result = inspect(trace([window('show', 200, 12, 'ConsoleWindowClass', { parent: 0, root: 12, pid: 99 })]), doctor, phases);
  assert.equal(result.status, 'failed');
});

test('retains visibility intervals instead of using visibility at callback time', () => {
  const hidden = { ...chat, kind: 'hide', tick: 190, received: 300, visible: 0 };
  const shown = window('show', 200, 12, 'ConsoleWindowClass', { visible: 0, received: 301 });
  assert.equal(inspect(trace([hidden, shown]), doctor, phases).status, 'passed');
});

test('ignores console windows outside the chat and while the app is hidden', () => {
  const outside = window('show', 200, 12, 'ConsoleWindowClass', { left: 1000, right: 1100 });
  assert.equal(inspect(trace([outside]), doctor, phases).status, 'passed');
  assert.equal(inspect(trace([{ ...main, kind: 'hide', tick: 190 }, window('show', 200, 12, 'ConsoleWindowClass')]), doctor, phases).status, 'passed');
});

test('detects an already-shown child moved or reparented above a visible chat', () => {
  const shown = window('show', 200, 12, 'ConsoleWindowClass', { left: 1000, right: 1100 });
  const moved = window('location', 210, 12, 'ConsoleWindowClass');
  assert.equal(inspect(trace([shown, moved]), doctor, phases).status, 'failed');
});

test('missing chat, native windows, or observation coverage cannot pass', () => {
  assert.throws(() => inspect(trace([]), { ...doctor, pid: 7 }, phases), /No owned visible/);
  assert.throws(() => inspect({ ...trace([]), events: [main, chat] }, doctor, phases), /No native consoles/);
  assert.throws(() => inspect({ ...trace([]), stop: 1000 }, doctor, phases), /complete journey/);
});

test('reads original event times and rejects missing hooks, truncated rows, and recording errors', () => {
  const row = event => ['window', ...['kind', 'tick', 'received', 'hwnd', 'cls', 'parent', 'root', 'pid', 'left', 'top', 'right', 'bottom', 'visible', 'style', 'z', 'foreground'].map(key => event[key])].join('\t');
  const text = `start\t90\n${[main, chat, console].map(row).join('\n')}\nstop\t5100\n`;
  assert.equal(inspect(parse(text), doctor, phases).status, 'passed');
  assert.throws(() => parse(text.replace('start\t90\n', '')), /hook start/);
  assert.throws(() => parse(text.replace('stop\t5100\n', '')), /hook start/);
  assert.throws(() => parse(text + 'window\tshow\n'), /Incomplete/);
  assert.throws(() => parse(text + 'error\tIOException\n'), /Incomplete/);
});
}
