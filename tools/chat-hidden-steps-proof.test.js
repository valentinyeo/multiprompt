const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const test = require('node:test');

async function oracle() {
  const file = path.join(__dirname, 'chat-hidden-steps-proof.mjs');
  assert.ok(fs.existsSync(file), 'hidden-step screenshot oracle exists');
  return import(pathToFileURL(file).href);
}

function image() {
  const value = { width: 320, height: 240, pixels: Buffer.alloc(320 * 240 * 4) };
  for (let at = 0; at < value.pixels.length; at += 4) value.pixels.writeUInt32LE(0xff101010, at);
  return value;
}

function frame(open = false) {
  return { transcript: { left: 0, top: 0, width: 320, height: 240 }, groups: [
    { count: 2, open, left: 8, top: 30, right: 280, bottom: 58 },
    { count: 1, open: false, left: 8, top: open ? 170 : 90, right: 280, bottom: open ? 198 : 118 },
  ] };
}

function ink(value, rect, color = 0xff808080) {
  for (let y = rect.top + 8; y < rect.top + 12; y++) for (let x = rect.left + 8; x < rect.left + 35; x++) value.pixels.writeUInt32LE(color, (y * value.width + x) * 4);
}

function sample() {
  const closed = image();
  const opened = image();
  const before = frame();
  const after = frame(true);
  for (const row of before.groups) ink(closed, row);
  for (const row of after.groups) ink(opened, row);
  ink(opened, { left: 22, top: 65 });
  ink(opened, { left: 22, top: 90 });
  return { closed, opened, folded: { ...closed, pixels: Buffer.from(closed.pixels) }, before, after, restored: frame() };
}

function inspect(api, value) {
  return api.inspectPair(value.closed, value.opened, value.folded, value.before, value.after, value.restored);
}

test('step driver reads the dictionary count field without PowerShell Count shadowing', () => {
  const file = path.join(__dirname, 'verify-chat-delivery/hidden-steps.ps1');
  assert.ok(fs.existsSync(file), 'hidden-step native driver exists');
  const source = fs.readFileSync(file, 'utf8');
  assert.ok(source.includes("$rows[0]['count'] -eq 2"));
  assert.ok(source.includes("Sort-Object { $_['first'] }"));
  assert.doesNotMatch(source, /\$rows\[\d\]\.count/);
});

test('step screenshot oracle accepts a visible grey line and real open-close pixels', async () => {
  const api = await oracle();
  assert.ok(inspect(api, sample()).changed > 100);
});

test('step screenshot oracle accepts bottom-anchored expansion without absolute row movement', async () => {
  const api = await oracle();
  const value = sample();
  value.before.groups = [
    { count: 2, open: false, left: 8, top: 90, right: 280, bottom: 118 },
    { count: 1, open: false, left: 8, top: 190, right: 280, bottom: 218 },
  ];
  value.after.groups[1] = { count: 1, open: false, left: 8, top: 190, right: 280, bottom: 218 };
  value.restored = structuredClone(value.before);
  value.closed = image();
  value.opened = image();
  for (const row of value.before.groups) ink(value.closed, row);
  for (const row of value.after.groups) ink(value.opened, row);
  ink(value.opened, { left: 22, top: 65 });
  value.folded = { ...value.closed, pixels: Buffer.from(value.closed.pixels) };
  assert.ok(inspect(api, value).changed > 100);
});

test('step screenshot oracle rejects an invisible summary and incorrect group count', async () => {
  const api = await oracle();
  const blank = sample();
  blank.closed = image();
  assert.throws(() => inspect(api, blank), /actually paint/);
  const grouped = sample();
  grouped.before.groups[0].count = 1;
  assert.throws(() => inspect(api, grouped), /one row per/);
});

test('step screenshot oracle rejects false expansion and non-restoring collapse', async () => {
  const api = await oracle();
  const hidden = sample();
  hidden.after.groups[1].top = hidden.before.groups[1].top;
  assert.throws(() => inspect(api, hidden), /opening exposes/);
  const changed = sample();
  ink(changed.folded, { left: 200, top: 210 });
  assert.throws(() => inspect(api, changed), /restores the closed/);
});
