const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const source = require('./app-source').readAppSource();
const writer = source.slice(source.indexOf("fn publishInboxStateNow("), source.indexOf("fn deleteInboxStateFile("));
const reader = source.slice(source.indexOf("fn loadInboxFile("), source.indexOf("fn inboxRowLess("));
const paint = source.slice(source.indexOf("fn paintInbox("), source.indexOf("fn openInbox("));

test("Inbox ETA deadline and total survive the published JSON row", () => {
  const fields = [
    ["ed", "eta_deadline_tick"],
    ["et", "eta_total_ms"],
  ];
  const shell = { eta_deadline_tick: 9007199254740995n, eta_total_ms: 120000n };
  const published = [];
  for (const [key, member] of fields) {
    assert.match(writer, new RegExp(`const o\\w+ = ",\\\\"${key}\\\\":";[\\s\\S]*?writeUintTo\\(json\\[pos\\.\\.\\], shells\\[i\\]\\.${member}\\)`));
    assert.match(reader, new RegExp(`const (\\w+) = json_reader\\.uint\\(o, "${key}"\\);[\\s\\S]*?g_inbox_rows\\[ri\\]\\.${member} = \\1;`));
    published.push(`"${key}":${shell[member]}`);
  }
  const json = `{"shells":[{${published.join(",")}}]}`;
  assert.equal(JSON.parse(json).shells.length, 1);
  for (const [key, member] of fields) {
    const number = json.match(new RegExp(`"${key}":([0-9]+)`));
    assert.equal(BigInt(number[1]), shell[member]);
  }
  assert.match(paint, /g_eta_numbers_on and row\.eta_deadline_tick != 0/);
  assert.match(paint, /g_eta_progress_on and row\.eta_total_ms > 0 and row\.eta_deadline_tick != 0/);
  assert.match(paint, /etaFillFraction\(etaElapsedMs\(row\.eta_total_ms, remaining_ms\), row\.eta_total_ms\)/);
  assert.match(paint, /FillRect\(hdc, &fill_rc, fill_br\)/);
});

test("Inbox ETA uses a fixed DPI-scaled bar and text column without moving previews", () => {
  assert.match(paint, /const eta_col_left = eta_col_right - uiScaled\(132\)/);
  assert.match(paint, /const eta_bar_w = uiScaled\(60\)/);
  assert.match(paint, /const preview_right = eta_col_left - uiScaled\(8\)/);
  assert.match(paint, /\.right = preview_right, \.bottom = y \+ row_h/);
  assert.match(paint, /\.left = eta_col_left, \.top = bar_top/);
  assert.match(paint, /\.left = eta_col_left \+ eta_bar_w \+ uiScaled\(8\)/);
  assert.doesNotMatch(paint, /\.top = y \+ row_h - 3/);
});
