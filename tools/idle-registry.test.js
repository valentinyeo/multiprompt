const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const srcDir = path.join(root, 'src');
const registryPath = path.join(__dirname, 'idle-registry.json');

let tools;
async function load() {
  if (!tools) {
    tools = {
      registry: await import('./idle-registry.mjs'),
      budget: await import('./idle-budget.mjs'),
    };
  }
  return tools;
}

function readRegistry() {
  return JSON.parse(fs.readFileSync(registryPath, 'utf8'));
}

const KINDS = new Set(['periodic', 'event']);
const TRIGGERS = new Set(['user', 'open', 'send', 'poll', 'warm', 'refresh', 'wrapper']);

test('every SetTimer call site in src is in the registry with its file', async () => {
  const { registry: scan } = await load();
  const table = readRegistry().timers;
  const missing = [];
  for (const site of scan.scanTimerSites(srcDir)) {
    const entry = table[site.timer];
    if (!entry) missing.push(`${site.file}:${site.line} arms ${site.timer}, which is not in tools/idle-registry.json`);
    else if (!entry.files.includes(site.file)) missing.push(`${site.file}:${site.line} arms ${site.timer}, but ${site.file} is not listed in its files`);
  }
  assert.deepEqual(missing, [], `Add each timer to tools/idle-registry.json with an owner, a reason and an idle cap:\n${missing.join('\n')}`);
});

test('no registry timer entry is stale', async () => {
  const { registry: scan } = await load();
  const table = readRegistry().timers;
  const seen = new Set(scan.scanTimerSites(srcDir).map(site => `${site.timer}@${site.file}`));
  const stale = [];
  for (const [name, entry] of Object.entries(table)) {
    for (const file of entry.files) {
      if (!seen.has(`${name}@${file}`)) stale.push(`${name} lists ${file}, which no longer arms it`);
    }
  }
  assert.deepEqual(stale, []);
});

test('every transcript fetch caller in src is in the registry', async () => {
  const { registry: scan } = await load();
  const table = readRegistry().fetches;
  const found = new Map();
  for (const site of scan.scanFetchSites(srcDir)) found.set(site.key, site);
  const missing = [...found.keys()].filter(key => !table[key]).map(key => `${key} (${found.get(key).file}:${found.get(key).line}) fetches a transcript and is not in tools/idle-registry.json`);
  assert.deepEqual(missing, []);
  const stale = Object.keys(table).filter(key => !found.has(key)).map(key => `${key} no longer fetches`);
  assert.deepEqual(stale, []);
});

test('every fetch entry names an owner, a trigger and a reason', () => {
  for (const [key, entry] of Object.entries(readRegistry().fetches)) {
    assert.ok(entry.owner && entry.owner.length > 0, `${key} owner`);
    assert.ok(TRIGGERS.has(entry.trigger), `${key} trigger ${entry.trigger}`);
    assert.ok(entry.reason && entry.reason.length >= 20, `${key} reason`);
  }
});

test('every timer entry follows the field rules', async () => {
  const { registry: scan } = await load();
  const constants = scan.timerConstants(srcDir);
  for (const [name, entry] of Object.entries(readRegistry().timers)) {
    assert.ok(entry.owner && entry.owner.length > 0, `${name} owner`);
    assert.ok(entry.reason && entry.reason.length >= 20, `${name} reason`);
    assert.ok(KINDS.has(entry.kind), `${name} kind`);
    assert.ok(Array.isArray(entry.files) && entry.files.length > 0, `${name} files`);
    assert.ok(Number.isInteger(entry.idle_max_per_min) && entry.idle_max_per_min >= 0, `${name} idle_max_per_min`);
    if (entry.kind === 'event') assert.equal(entry.idle_max_per_min, 0, `${name} is an event timer, so it gets no idle wakes`);
    else assert.ok(entry.idle_max_per_min >= 1, `${name} is periodic, so it needs at least one wake a minute`);
    if (entry.idle_max_per_min > 1) assert.ok(typeof entry.exception === 'string' && entry.exception.length >= 20, `${name} runs above one wake a minute and needs an exception reason`);
    else assert.equal(entry.exception, undefined, `${name} has an exception it does not need`);
    if (constants.has(name)) assert.equal(entry.id, constants.get(name), `${name} id does not match its constant`);
  }
});

test('timers that share a counter slot are listed so the budget takes the larger cap', async () => {
  const { budget } = await load();
  const caps = budget.timerCaps(readRegistry());
  const shared = caps.get(36);
  assert.deepEqual(shared.names.sort(), ['TIMER_CHAT_SEL_SCROLL', 'TIMER_SSH_RECONNECT']);
});

test('the avatar paint logs go through the once-only logger', () => {
  const offenders = [];
  let once = 0;
  for (const name of fs.readdirSync(srcDir).filter(n => n.endsWith('.zig') && n !== 'idle_budget.zig')) {
    const lines = fs.readFileSync(path.join(srcDir, name), 'utf8').split('\n');
    lines.forEach((line, index) => {
      if (!/\[(photo-proof|sidebar-avatar|bots)\]/.test(line)) return;
      if (line.includes('debugLogOnce(')) once += 1;
      else offenders.push(`${name}:${index + 1}`);
    });
  }
  assert.deepEqual(offenders, [], 'per-paint avatar logs must use debugLogOnce');
  assert.equal(once, 7);
});

test('the counter table sizes and message ids match the app', async () => {
  const { budget } = await load();
  const zig = fs.readFileSync(path.join(srcDir, 'idle_budget.zig'), 'utf8');
  const slots = Number(zig.match(/pub const TIMER_SLOTS: usize = (\d+);/)[1]);
  assert.equal(slots - 1, budget.OVERFLOW_SLOT);
  assert.equal(zig.match(/pub const WM_TIMER: u32 = (0x[0-9A-Fa-f]+);/)[1], '0x0113');
  assert.equal(zig.match(/pub const WM_PAINT: u32 = (0x[0-9A-Fa-f]+);/)[1], '0x000F');
});
