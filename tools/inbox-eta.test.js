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
  assert.match(paint, /eta_valid and \(g_eta_numbers_on or g_eta_progress_on\) and width >= uiScaled\(320\)/);
  assert.match(paint, /const eta_valid = row\.act == 1 and row\.eta_total_ms > 0 and row\.eta_deadline_tick != 0;/);
  assert.match(paint, /etaFillFraction\(etaElapsedMs\(row\.eta_total_ms, remaining_ms\), row\.eta_total_ms\)/);
  assert.match(paint, /fillRoundRect\(hdc, \.\{ \.left = bar_left, \.top = track\.top, \.right = bar_left \+ fill, \.bottom = track\.bottom \}/);
});

test("Inbox ETA uses a fixed DPI-scaled bar and text column without moving previews", () => {
  assert.match(paint, /const bar_right = layout\.right - uiScaled\(14\);/);
  assert.match(paint, /const bar_left = bar_right - uiScaled\(60\);/);
  assert.match(paint, /const preview_right = if \(show_eta\) layout\.right - uiScaled\(146\) else layout\.right - uiScaled\(14\);/);
  assert.match(paint, /\.right = @max\(text_left, preview_right\), \.bottom = y \+ uiScaled\(48\)/);
  assert.match(paint, /const track = RECT\{ \.left = bar_left, \.top = y \+ uiScaled\(36\), \.right = bar_right, \.bottom = y \+ uiScaled\(40\) \};/);
  assert.match(paint, /\.left = layout\.right - uiScaled\(146\), \.top = y \+ uiScaled\(29\)/);
  assert.doesNotMatch(paint, /\.top = y \+ row_h - 3/);
});
