const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = fs.readFileSync(path.join(__dirname, "../src/archive.zig"), "utf8");

function body(name, next) {
  const start = source.indexOf(`pub fn ${name}(`);
  assert.notStrictEqual(start, -1, name);
  const end = source.indexOf(`\npub fn ${next}(`, start);
  assert.notStrictEqual(end, -1, next);
  return source.slice(start, end);
}

function states(text) {
  const found = {};
  for (const match of text.matchAll(/((?:\.\w+\s*,\s*)*\.\w+)\s*=>\s*\.(running|no_window|archived)/g)) {
    for (const kind of match[1].match(/\.(\w+)/g)) found[kind.slice(1)] = match[2];
  }
  return found;
}

function counts(rows, host, map) {
  const totals = { all: 0, running: 0, no_window: 0, archived: 0 };
  for (const row of rows) {
    if (host !== 0xff && row.host !== host) continue;
    totals.all += 1;
    totals[map[row.kind]] += 1;
  }
  return totals;
}

test("session view states count running, no window, and archived per server", () => {
  const map = states(body("sessionViewState", "sessionViewStateLabel"));
  assert.deepEqual(map, {
    open: "running",
    hidden: "running",
    vps_only: "no_window",
    reminder: "no_window",
    archived: "archived",
  });
  const rows = [
    { kind: "open", host: 0 },
    { kind: "open", host: 0 },
    { kind: "hidden", host: 1 },
    { kind: "vps_only", host: 0 },
    { kind: "reminder", host: 1 },
    { kind: "vps_only", host: 1 },
    { kind: "archived", host: 0 },
    { kind: "archived", host: 1 },
    { kind: "archived", host: 1 },
  ];
  const all = counts(rows, 0xff, map);
  const host0 = counts(rows, 0, map);
  assert.deepEqual(all, { all: 9, running: 3, no_window: 3, archived: 3 });
  assert.deepEqual(host0, { all: 4, running: 2, no_window: 1, archived: 1 });
  assert.notEqual(host0.running, all.running);
  assert.match(source, /sessionViewCounts\(rows, app_state\.g_all_sessions_host_filter\)/);
});
