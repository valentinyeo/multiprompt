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

const TICKET_TARGETS = [
  'SEARCH_NEW_OFFSET + 0',
  'SEARCH_NEW_OFFSET + 5',
  'SEARCH_NEW_OFFSET + 6',
  'SEARCH_NEW_OFFSET + 7',
  'SEARCH_OPENFOLDER_OFFSET',
  'SEARCH_RECOVER_REPO_OFFSET',
  'SEARCH_UNARCHIVE_HIDDEN_OFFSET',
  'SEARCH_UNARCHIVE_UNATTACHED_OFFSET',
  'SEARCH_CLOSETAB_OFFSET',
  'SEARCH_TABCTX_HIDE',
  'SEARCH_RENAME_SYNC_OFFSET',
  'SEARCH_SYNC_NAME_OFFSET',
  'SEARCH_CHAT_VIEW_MODE_EVERYWHERE_OFFSET',
  'SEARCH_CHAT_VIEW_MODE_NOWHERE_OFFSET',
  'SEARCH_WSMOVE_NEW_OFFSET',
  'SEARCH_TABCTX_MOVE_NEW_WS',
  'SEARCH_TABCTX_GROUP_NEW',
  'SEARCH_TABCTX_GROUP_REMOVE',
  'SEARCH_TABCTX_GROUP_ADD_OFFSET',
  'SEARCH_SNIPPET_MANAGE_OFFSET',
  'SEARCH_CHAT_RETRY_UNSENT_OFFSET',
  'SEARCH_CHAT_PUSH_QUEUED_OFFSET',
  'SEARCH_CHAT_QUEUE_CLEAR_OFFSET',
  'SEARCH_CHAT_MODEL_OPUS_OFFSET',
  'SEARCH_CHAT_MODEL_SONNET_OFFSET',
  'SEARCH_CHAT_MODEL_HAIKU_OFFSET',
  'SEARCH_CHAT_MODEL_FABLE_OFFSET',
  'SEARCH_CHAT_EFFORT_LOW_OFFSET',
  'SEARCH_CHAT_EFFORT_MEDIUM_OFFSET',
  'SEARCH_CHAT_EFFORT_HIGH_OFFSET',
  'SEARCH_CHAT_MODE_PLAN_OFFSET',
  'SEARCH_CHAT_MODE_MANUAL_OFFSET',
  'SEARCH_CHAT_MODE_EDITS_OFFSET',
  'SEARCH_CHAT_MODE_BYPASS_OFFSET',
  'SEARCH_CREATEWS_OFFSET',
  'SEARCH_SHOW_FREQUENT_OFFSET',
  'SEARCH_FREQUENT_FIRST_OFFSET',
  'SEARCH_SHOW_FAVORITES_OFFSET',
  'SEARCH_SHOW_ALL_OFFSET',
  'SEARCH_INBOX_FREQUENT_OFFSET',
  'SEARCH_SIDEBAR_COLLAPSE_OFFSET',
  'SEARCH_SIDEBAR_HIDE_OFFSET',
  'SEARCH_TABSORT_MANUAL_OFFSET',
  'SEARCH_KEEPAWAKE_OFFSET',
  'SEARCH_TABCTX_KEEPAWAKE',
  'SEARCH_COMPUTER_WIDTH_OFFSET',
  'SEARCH_POWER_ALWAYS_OFFSET',
  'SEARCH_POWER_OFF_OFFSET',
  'SEARCH_FONT_BIGGER_OFFSET',
  'SEARCH_FONT_SMALLER_OFFSET',
  'SEARCH_FONT_RESET_OFFSET',
  'SEARCH_LADDER_CLAUDE_OFFSET',
  'SEARCH_LADDER_CODEX_OFFSET',
  'SEARCH_VOICE_SPEED_125_OFFSET',
  'SEARCH_VOICE_SPEED_140_OFFSET',
  'SEARCH_VOICE_SPEED_150_OFFSET',
  'SEARCH_VOICE_PREVIOUS_OFFSET',
  'SEARCH_VOICE_NEXT_OFFSET',
  'SEARCH_ETA_PROGRESS_OFFSET',
  'SEARCH_CUSTOMCMD_RELOAD_OFFSET',
  'SEARCH_APPROVE_DEVICES_OFFSET',
  'SEARCH_USAGE_LOGIN_INNE_OFFSET',
];

function constValue(name) {
  const found = new RegExp(`pub const ${name}: usize = (\\d+);`).exec(state);
  assert.ok(found, `${name} is declared`);
  return Number(found[1]);
}

function foldedValues() {
  const values = new Set();
  for (const name of folded) values.add(constValue(name));
  for (const [, name, offset] of foldTable().matchAll(/\b(SEARCH_\w+)\s*\+\s*(\d+)/g)) values.add(constValue(name) + Number(offset));
  const first = constValue('SEARCH_CHAT_MODE_PLAN_OFFSET');
  const last = constValue('SEARCH_CHAT_MODEL_ASTRA_OFFSET');
  const plus = constValue('SEARCH_CHAT_PLUS_MENU_OFFSET');
  for (let value = first; value <= last; value++) if (value !== plus) values.add(value);
  const groupFirst = constValue('SEARCH_TABCTX_GROUP_ADD_OFFSET');
  for (let index = 0; index < constValue('MAX_GROUPS'); index++) values.add(groupFirst + index);
  values.add(constValue('SEARCH_KEEPAWAKE_OFFSET'));
  return values;
}

test('SOFT-1969 every command on the ticket list is folded', () => {
  const values = foldedValues();
  assert.equal(TICKET_TARGETS.length, 62);
  for (const target of TICKET_TARGETS) {
    const [name, offset] = target.split(' + ');
    const value = constValue(name) + (offset ? Number(offset) : 0);
    assert.ok(values.has(value), `${target} is folded`);
  }
});

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
