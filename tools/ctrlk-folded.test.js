import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const palette = readFileSync(new URL('../src/command_palette.zig', import.meta.url), 'utf8');
const state = readFileSync(new URL('../src/app_state.zig', import.meta.url), 'utf8');

function foldTable() {
  const start = palette.indexOf('pub const folded_palette_rows');
  assert.notEqual(start, -1, 'folded_palette_rows table');
  return palette.slice(start, palette.indexOf('};', start));
}

const folded = [...foldTable().matchAll(/\bSEARCH_\w+/g)].map(([name]) => name);

test('SOFT-1969 every folded Ctrl+K duplicate stays folded', () => {
  assert.ok(folded.length >= 45, `folded rows: ${folded.length}`);
  for (const offset of [0, 5, 6, 7]) assert.ok(foldTable().includes(`SEARCH_NEW_OFFSET + ${offset}`), `shell row ${offset} folded`);
  for (const name of folded) {
    assert.match(state, new RegExp(`pub const ${name}: usize = \\d+;`), `${name} is declared`);
  }
  for (const name of [
    'SEARCH_CREATEWS_OFFSET', 'SEARCH_SIDEBAR_COLLAPSE_OFFSET', 'SEARCH_POWER_ALWAYS_OFFSET',
    'SEARCH_VOICE_SPEED_150_OFFSET', 'SEARCH_APPROVE_DEVICES_OFFSET', 'SEARCH_FONT_RESET_OFFSET',
  ]) {
    assert.ok(folded.includes(name), `${name} is folded`);
  }
  assert.match(palette, /target >= SEARCH_CHAT_MODE_PLAN_OFFSET and target <= SEARCH_CHAT_MODEL_ASTRA_OFFSET/);
  assert.match(palette, /SEARCH_TABCTX_GROUP_ADD_OFFSET \+ MAX_GROUPS/);
});

test('SOFT-1969 the fold runs on every palette exit', () => {
  const start = palette.indexOf('pub fn updateSearchResults() void {');
  const body = palette.slice(start, palette.indexOf('\n}\n', start));
  const defer = body.indexOf('defer {');
  assert.notEqual(defer, -1, 'updateSearchResults defer');
  assert.match(body.slice(defer, defer + 200), /foldPaletteRows\(\);/);
  assert.match(palette, /if \(paletteRowFolded\(row\)\) continue;/);
});

test('SOFT-1969 the kept commands stay visible', () => {
  const kept = [
    'SEARCH_NEW_TERMINAL_OFFSET',
    'SEARCH_ARCHIVE_OFFSET',
    'SEARCH_RENAME_SYNC_OFFSET',
    'SEARCH_WS_BRINGBACK_OFFSET',
    'SEARCH_CHAT_PLUS_MENU_OFFSET',
    'SEARCH_CHAT_QUEUE_SEND_OFFSET',
    'SEARCH_CHAT_DISCARD_UNSENT_OFFSET',
    'SEARCH_NEWWIN_OFFSET',
    'SEARCH_SETTINGS_OFFSET',
    'SEARCH_FULLWIDTH_OFFSET',
    'SEARCH_BROWSER_AUTOSUSPEND_OFFSET',
    'SEARCH_UI_BIGGER_OFFSET',
    'SEARCH_UI_SMALLER_OFFSET',
    'SEARCH_UI_RESET_OFFSET',
    'SEARCH_POWER_AUTO_OFFSET',
    'SEARCH_LADDER_AUTO_OFFSET',
    'SEARCH_VOICE_SPEED_100_OFFSET',
    'SEARCH_VOICE_REPLAY_OFFSET',
    'SEARCH_ETA_NUMBERS_OFFSET',
    'SEARCH_CUSTOMCMD_EDIT_OFFSET',
    'SEARCH_SYNC_STATUS_OFFSET',
    'SEARCH_USAGE_LOGIN_PRIMARY_OFFSET',
    'SEARCH_HIDESIDEBAR_OFFSET',
    'SEARCH_TABSORT_INBOX_OFFSET',
  ];
  for (const name of kept) assert.ok(!folded.includes(name), `${name} must stay in Ctrl+K`);
});

test('SOFT-1969 folded rows are gone from the shortcut overview', () => {
  const shortcuts = readFileSync(new URL('../src/shortcuts.zig', import.meta.url), 'utf8');
  for (const gone of [
    'Hide from sidebar', 'Show Frequent split', 'Show Favorites split', 'Show All split',
    'Frequent as first tab', 'Inbox: Frequent', 'Manage Snippets', 'Account: Approve devices',
    'Chat View: On Everywhere', 'Chat View: Model Opus', 'Chat View: Model Sol',
    'Chat View: Effort Low', 'Chat View: Clear Offline Queue', 'Chat View: Retry Unsent Messages',
    "Chat View: Send Claude's Queued Message Now",
  ]) {
    assert.ok(!shortcuts.includes(gone), `${gone} shortcut row removed`);
  }
  for (const kept of ['Power Saver', 'Token plan', 'Voice speed', 'ETA Countdown Numbers']) {
    assert.ok(shortcuts.includes(kept), `${kept} shortcut row kept`);
  }
});
