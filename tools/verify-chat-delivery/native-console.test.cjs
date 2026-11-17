const { test } = require('node:test');
const assert = require('node:assert/strict');
const { parse, inspect } = require('./native-console.cjs');
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
