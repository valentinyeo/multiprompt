import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
export const OVERFLOW_SLOT = 255;

export function loadBudget(file = path.join(here, 'idle-budget.json')) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function loadRegistry(file = path.join(here, 'idle-registry.json')) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

export function timerCaps(registry) {
  const caps = new Map();
  for (const [name, entry] of Object.entries(registry.timers)) {
    if (entry.counted === false) continue;
    const slot = entry.id === null || entry.id >= OVERFLOW_SLOT ? OVERFLOW_SLOT : entry.id;
    const known = caps.get(slot) || { names: [], perMinute: 0 };
    known.names.push(name);
    known.perMinute = Math.max(known.perMinute, entry.idle_max_per_min);
    caps.set(slot, known);
  }
  return caps;
}

function validateDump(dump, name, sources) {
  if (!dump || typeof dump !== 'object' || Array.isArray(dump)) return `${name} dump must be an object`;
  for (const key of ['tick_ms', 'idle_ms', 'timer_fire', ...sources]) {
    if (!Number.isSafeInteger(dump[key]) || dump[key] < 0) return `${name}.${key} must be a nonnegative integer`;
  }
  if (dump.deep_idle !== 0 && dump.deep_idle !== 1) return `${name}.deep_idle must be 0 or 1`;
  if (!dump.timers || typeof dump.timers !== 'object' || Array.isArray(dump.timers)) return `${name}.timers must be an object`;
  for (const [slot, count] of Object.entries(dump.timers)) {
    if (!/^(0|[1-9]\d*)$/.test(slot) || Number(slot) > OVERFLOW_SLOT) return `${name} has invalid timer slot ${slot}`;
    if (!Number.isSafeInteger(count) || count < 0) return `${name}.timers.${slot} must be a nonnegative integer`;
  }
  return null;
}

function powerMode(before, after) {
  const at = dump => (dump.deep_idle === undefined ? 'unknown' : dump.deep_idle ? 'deep idle' : 'normal');
  const first = at(before);
  const last = at(after);
  return first === last ? first : `${first} to ${last}`;
}

export function evaluate({ budget, registry, before, after }) {
  const failures = [];
  const rows = [];
  const sources = Object.keys(budget.sources);
  for (const [name, dump] of [['before', before], ['after', after]]) {
    const error = validateDump(dump, name, sources);
    if (error) failures.push({ source: 'dump', message: error });
  }
  if (failures.length) return { ok: false, windowMs: 0, powerMode: 'unknown', failures, rows };
  const windowMs = after.tick_ms - before.tick_ms;
  if (!(windowMs > 0)) {
    failures.push({ source: 'window', observed: windowMs, allowed: 0, message: `idle window is ${windowMs} ms; the two counter dumps must be taken in order` });
    return { ok: false, windowMs, powerMode: 'unknown', failures, rows };
  }
  if (windowMs < budget.min_window_seconds * 1000) {
    failures.push({ source: 'window', observed: windowMs, allowed: budget.min_window_seconds * 1000, message: `idle window is ${Math.round(windowMs / 1000)} s; at least ${budget.min_window_seconds} s is required` });
  }
  if (before.idle_ms < 60_000 || after.idle_ms < before.idle_ms + windowMs) {
    failures.push({ source: 'input', message: 'counter dumps do not cover an uninterrupted idle window after one quiet minute' });
  }
  if (after.timer_fire < before.timer_fire) failures.push({ source: 'timer_fire', message: 'timer_fire decreased; counter reset or wrap cannot prove an idle budget' });
  const minutes = windowMs / 60_000;
  for (const [source, allowed] of Object.entries(budget.sources)) {
    const observed = after[source] - before[source];
    if (observed < 0) failures.push({ source, message: `${source} decreased; counter reset or wrap cannot prove an idle budget` });
    rows.push({ source, observed, allowed, perMinute: observed / minutes });
    if (allowed !== null && observed > allowed) {
      failures.push({ source, observed, allowed, message: `${source} is over budget: ${observed} in ${Math.round(windowMs / 1000)} s (${(observed / minutes).toFixed(1)} per minute), budget ${allowed}` });
    }
  }
  const caps = timerCaps(registry);
  const slack = budget.timer_slack_wakes;
  const slots = new Set([...Object.keys(before.timers || {}), ...Object.keys(after.timers || {})].map(Number));
  for (const slot of [...slots].sort((a, b) => a - b)) {
    const observed = (after.timers[slot] ?? 0) - (before.timers[slot] ?? 0);
    if (observed < 0) failures.push({ source: `timer ${slot}`, message: `timer ${slot} decreased; counter reset or wrap cannot prove an idle budget` });
    const cap = caps.get(slot);
    const names = cap ? cap.names.join(' or ') : 'unregistered';
    const perMinute = cap ? cap.perMinute : 0;
    const allowed = perMinute === 0 ? 0 : Math.ceil(perMinute * minutes) + slack;
    rows.push({ source: `timer ${slot} (${names})`, observed, allowed, perMinute: observed / minutes });
    if (observed > allowed) {
      failures.push({ source: `timer ${slot}`, observed, allowed, message: `timer ${slot} (${names}) is over budget: ${observed} wakes in ${Math.round(windowMs / 1000)} s, budget ${allowed}` });
    }
  }
  return { ok: failures.length === 0, windowMs, powerMode: powerMode(before, after), failures, rows };
}

export function render(result) {
  const lines = [`idle window ${Math.round(result.windowMs / 1000)} s, power mode ${result.powerMode}`];
  for (const row of result.rows) {
    lines.push(`${row.source}: ${row.observed} (${row.perMinute.toFixed(1)} per min), budget ${row.allowed === null ? 'report only' : row.allowed}`);
  }
  if (result.ok) lines.push('IDLE BUDGET PASSED');
  else {
    lines.push('IDLE BUDGET FAILED');
    for (const failure of result.failures) lines.push(`  ${failure.message}`);
  }
  return lines.join('\n');
}

function main(argv) {
  const [beforeFile, afterFile, outFile] = argv;
  if (!beforeFile || !afterFile) {
    console.error('usage: node tools/idle-budget.mjs <before.json> <after.json> [report.txt]');
    return 2;
  }
  const result = evaluate({
    budget: loadBudget(),
    registry: loadRegistry(),
    before: JSON.parse(fs.readFileSync(beforeFile, 'utf8').replace(/^\uFEFF/, '')),
    after: JSON.parse(fs.readFileSync(afterFile, 'utf8').replace(/^\uFEFF/, '')),
  });
  const text = render(result);
  console.log(text);
  if (outFile) fs.writeFileSync(outFile, text + '\n');
  return result.ok ? 0 : 1;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) process.exit(main(process.argv.slice(2)));
