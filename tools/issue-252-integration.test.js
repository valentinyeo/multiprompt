const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { readChangelogEntry } = require('./changelog-entry');
const read = file => fs.readFileSync(path.join(__dirname, '..', file), 'utf8');

test('ISSUE-252 records default off without disabling existing account synchronization', () => {
  const state = read('src/app_state.zig'), source = read('src/account_desktop.zig');
  assert.match(state, /g_account_sync_enabled = false;/);
  assert.match(source, /if \(app_state.g_account_sync_enabled\) \{\s*accountSyncRecords/);
  assert.match(source, /account-sync.json/);
  assert.match(source, /account-records.json/);
  assert.match(source, /if \(std.mem.eql\(u8, parsed.value.account, &scope\)\) state = parsed.value/);
  assert.match(source, /account_records.roundTrip/);
  assert.match(source, /records_checked = null/);
  const record = source.slice(source.indexOf('fn accountSyncRecords('), source.indexOf('pub fn accountToggleSync('));
  assert.doesNotMatch(record, /accountApplyHosts|materialize|SetTimer/);
  assert.equal((record.match(/writeFileAtomicW\(path,/g) || []).length, 1);
  assert.match(read('src/main.zig'), /wp == TIMER_ACCOUNT\) \{\s*pullSessionLayout\(\)/);
});

test('ISSUE-252 palette F1 documentation and changelog expose the supplemental opt-in action', () => {
  for (const file of ['src/command_palette.zig', 'src/sidebar.zig', 'src/shortcuts.zig', 'openwiki/operations/keyboard-shortcuts.md']) assert.ok(read(file).includes('Sync between laptops'), file);
  assert.match(read('src/main.zig'), /target == app_state.SEARCH_LAPTOP_SYNC_OFFSET[\s\S]*?accountToggleSync\(\)/);
  assert.match(read('src/sidebar.zig'), /L\("Sync between laptops: ON"\).*L\("Sync between laptops: OFF"\)/);
  assert.ok(readChangelogEntry('IGSH-252').length > 0);
  assert.match(read('src/account_records.zig'), /pub const poll_ms = 180000;/);
  assert.match(read('service/worker.js'), /ON CONFLICT\(account,kind,id\) DO UPDATE/);
  assert.match(read('service/schema.sql'), /PRIMARY KEY \(account,kind,id\)/);
});
