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

module.exports = { parse, inspect };

if (require.main === module) {
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
}
