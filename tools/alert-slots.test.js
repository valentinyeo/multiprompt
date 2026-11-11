const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const hosts = 3;
const slotsPerHost = 32;

function emptySlot() {
  return { id: 0, generation: 0, done: false, payload: null };
}

function createTable() {
  const live = new Set();
  const table = {
    slots: Array.from({ length: hosts }, () => Array.from({ length: slotsPerHost }, emptySlot)),
    generation: Array(hosts).fill(0),
    own(text) {
      const box = { text };
      live.add(box);
      return box;
    },
    free(box) {
      if (box) live.delete(box);
    },
    bump(host) {
      table.generation[host] = (table.generation[host] + 1) >>> 0;
      if (table.generation[host] === 0) table.generation[host] = 1;
      return table.generation[host];
    },
    drop(host, generation) {
      for (const slot of table.slots[host]) {
        if (generation != null && slot.generation !== generation) continue;
        table.free(slot.payload);
        Object.assign(slot, emptySlot());
      }
    },
    begin(host) {
      if (host >= hosts) return 0;
      table.drop(host, null);
      return table.bump(host);
    },
    end(host, generation) {
      if (host >= hosts || generation === 0 || table.generation[host] !== generation) return;
      table.drop(host, generation);
      table.bump(host);
    },
    claim(host, generation, id) {
      if (host >= hosts || id === 0 || generation === 0 || table.generation[host] !== generation) return false;
      if (table.slots[host].some(slot => slot.id === id && slot.generation === generation)) return false;
      const slot = table.slots[host].find(item => item.id === 0);
      if (!slot) return false;
      slot.id = id;
      slot.generation = generation;
      slot.done = false;
      slot.payload = null;
      return true;
    },
    finish(host, generation, id, payload) {
      if (host < hosts && id !== 0 && generation !== 0 && table.generation[host] === generation) {
        const slot = table.slots[host].find(item => item.id === id && item.generation === generation && !item.done);
        if (slot) {
          slot.payload = payload;
          slot.done = true;
          return;
        }
      }
      table.free(payload);
    },
    takeReady(host, generation) {
      if (host >= hosts || generation === 0 || table.generation[host] !== generation) return null;
      const slot = table.slots[host].find(item => item.id !== 0 && item.generation === generation && item.done);
      if (!slot) return null;
      const ready = { id: slot.id, payload: slot.payload };
      Object.assign(slot, emptySlot());
      return ready;
    },
    deinit() {
      for (let host = 0; host < hosts; host += 1) table.drop(host, null);
    },
  };
  table.live = live;
  return table;
}

function expectReady(table, host, generation, id, text) {
  const ready = table.takeReady(host, generation);
  assert.ok(ready, 'missing reply');
  assert.equal(ready.id, id);
  if (text == null) {
    assert.equal(ready.payload, null);
  } else {
    assert.equal(ready.payload.text, text);
    table.free(ready.payload);
  }
}

test('two servers keep the same call id apart', () => {
  const table = createTable();
  const left = table.begin(0);
  const right = table.begin(1);
  assert.equal(table.claim(0, left, 1), true);
  assert.equal(table.claim(1, right, 1), true);
  table.finish(0, left, 1, table.own('left'));
  table.finish(1, right, 1, table.own('right'));
  expectReady(table, 0, left, 1, 'left');
  expectReady(table, 1, right, 1, 'right');
  assert.equal(table.takeReady(0, left), null);
  assert.equal(table.takeReady(1, right), null);
  table.deinit();
  assert.equal(table.live.size, 0);
});

test('a reply is not flushed to the other server when ids differ', () => {
  const table = createTable();
  const left = table.begin(0);
  const right = table.begin(1);
  assert.equal(table.claim(0, left, 7), true);
  assert.equal(table.claim(1, right, 8), true);
  table.finish(1, right, 8, table.own('right-eight'));
  assert.equal(table.takeReady(0, left), null);
  expectReady(table, 1, right, 8, 'right-eight');
  table.finish(0, left, 7, table.own('left-seven'));
  expectReady(table, 0, left, 7, 'left-seven');
  assert.equal(table.takeReady(1, right), null);
  table.deinit();
  assert.equal(table.live.size, 0);
});

test('replies leave in completion order on the server that owns them', () => {
  const table = createTable();
  const left = table.begin(0);
  const right = table.begin(1);
  assert.equal(table.claim(0, left, 1), true);
  assert.equal(table.claim(0, left, 2), true);
  assert.equal(table.claim(1, right, 1), true);
  table.finish(0, left, 2, table.own('second'));
  table.finish(1, right, 1, table.own('other'));
  expectReady(table, 0, left, 2, 'second');
  expectReady(table, 1, right, 1, 'other');
  assert.equal(table.takeReady(0, left), null);
  table.finish(0, left, 1, table.own('first'));
  expectReady(table, 0, left, 1, 'first');
  table.deinit();
  assert.equal(table.live.size, 0);
});

test('a dropped connection forgets in-flight replies before the next one', () => {
  const table = createTable();
  const first = table.begin(0);
  assert.equal(table.claim(0, first, 1), true);
  table.finish(0, first, 1, table.own('stale'));
  table.end(0, first);
  assert.equal(table.claim(0, first, 1), false);
  table.finish(0, first, 1, table.own('late'));
  const second = table.begin(0);
  assert.notEqual(second, first);
  assert.equal(table.claim(0, first, 1), false);
  assert.equal(table.claim(0, second, 1), true);
  assert.equal(table.takeReady(0, second), null);
  table.finish(0, second, 1, table.own('fresh'));
  expectReady(table, 0, second, 1, 'fresh');
  table.deinit();
  assert.equal(table.live.size, 0);
});

test('each server keeps a 32 call waiting limit', () => {
  const table = createTable();
  const left = table.begin(0);
  const right = table.begin(1);
  for (let id = 1; id <= slotsPerHost; id += 1) assert.equal(table.claim(0, left, id), true);
  assert.equal(table.claim(0, left, slotsPerHost + 1), false);
  assert.equal(table.claim(1, right, 1), true);
  assert.equal(table.claim(0, left, 1), false);
  table.deinit();
  assert.equal(table.live.size, 0);
});

test('the app owns each reply by its server connection', () => {
  const zig = fs.readFileSync(path.join(root, 'src/alert_slots.zig'), 'utf8');
  const alerts = fs.readFileSync(path.join(root, 'src/shared_alerts.zig'), 'utf8');
  const build = fs.readFileSync(path.join(root, 'build.zig'), 'utf8');
  assert.match(zig, /pub const slots_per_host = 32;/);
  assert.match(zig, /self\.generation\[host\] != generation/);
  assert.match(zig, /fn bump\(self: \*Table, host: u8\) u32/);
  assert.doesNotMatch(alerts, /var g_slots:/);
  assert.match(alerts, /defer endChannel\(host, generation\)/);
  assert.match(alerts, /return g_table\.takeReady\(host, generation\)/);
  assert.match(alerts, /fn flushSlots\(channel: \*transport\.Channel, host: u8, generation: u32\) void/);
  assert.match(build, /src\/alert_slots\.zig/);
  assert.match(build, /vps_test_step\.dependOn\(&run_alert_slot_tests\.step\)/);
  assert.match(build, /test_step\.dependOn\(&run_alert_slot_tests\.step\)/);
});
