const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../src/inbox.zig'), 'utf8');
const paint = source.slice(source.indexOf('fn paintInbox('), source.indexOf('fn openInbox('));

test('Inbox reserves the second line for semantic preview only', () => {
  assert.match(paint, /const preview_right = layout\.right - uiScaled\(14\);/);
  assert.match(paint, /\.right = @max\(text_left, preview_right\), \.bottom = y \+ uiScaled\(48\)/);
  assert.doesNotMatch(paint, /show_eta|etaRemainingMs|etaFillFraction|formatEtaRemaining|g_eta_progress_on|g_eta_numbers_on/);
});

test('Inbox preserves ETA fields in published state', () => {
  assert.match(source, /writeUintTo\(json\[pos\.\.\], app_state\.shells\[i\]\.eta_deadline_tick\)/);
  assert.match(source, /writeUintTo\(json\[pos\.\.\], app_state\.shells\[i\]\.eta_total_ms\)/);
  assert.match(source, /g_inbox_rows\[ri\]\.eta_deadline_tick = sed;/);
  assert.match(source, /g_inbox_rows\[ri\]\.eta_total_ms = set;/);
});
