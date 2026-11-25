const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const palette = read('src/command_palette.zig');
const state = read('src/app_state.zig');
const drive = read('tools/verify-chat-delivery/drive.ps1');
const journey = read('tools/verify-chat-delivery/antigravity-chats.ps1');

const ROW = 'SEARCH_NEW_ANTIGRAVITY_CHAT_OFFSET';

function offsetOf(name) {
  const match = state.match(new RegExp(`pub const ${name}: usize = (\\d+);`));
  assert.ok(match, `${name} must be declared in src/app_state.zig`);
  return Number(match[1]);
}

function keywordsMatchAll(keywords, query) {
  if (query.length === 0) return true;
  const haystack = keywords.toLowerCase();
  for (const word of query.toLowerCase().split(' ')) {
    if (word.length === 0) continue;
    if (!haystack.includes(word)) return false;
  }
  return true;
}

function newChatRows(query, { folder }) {
  const rows = [];
  const calls = /keywordsMatchAll\("([^"]+)",\s*app_state\.g_search_buf\[0\.\.app_state\.g_search_len\]\)/g;
  for (const match of palette.matchAll(calls)) {
    const assigned = palette.slice(match.index).match(/= (SEARCH_\w+_OFFSET);/);
    if (!assigned) continue;
    const guard = palette.slice(palette.lastIndexOf('if (', match.index), match.index);
    if (/\bremote_folder\b/.test(guard) && !folder) continue;
    if (keywordsMatchAll(match[1], query)) rows.push(assigned[1]);
  }
  return rows;
}

test('SOFT-3050 typing a new Antigravity session lists its palette row', () => {
  const withFolder = newChatRows('new antigravity', { folder: true });
  assert.ok(withFolder.includes(ROW), `query "new antigravity" must produce ${ROW}, got ${withFolder.join(', ')}`);
  const allNewChats = newChatRows('new', { folder: true });
  for (const name of ['SEARCH_NEW_PI_CHAT_OFFSET', 'SEARCH_NEW_CURSOR_CHAT_OFFSET', ROW]) {
    assert.ok(allNewChats.includes(name), `query "new" must offer ${name} alongside the other agent chats`);
  }
  assert.ok(!newChatRows('new antigravity', { folder: false }).includes(ROW), 'the row is offered only when the chat can start in a workspace folder');
});

test('SOFT-3050 the label and the search words serve singular and plural', () => {
  const label = palette.match(/if \(target == SEARCH_NEW_ANTIGRAVITY_CHAT_OFFSET\) return "([^"]+)";/);
  assert.ok(label, 'the Antigravity row needs a palette label');
  assert.equal(label[1], 'New Antigravity Sessions');
  for (const query of ['new antigravity', 'new antigravity session', 'new antigravity sessions']) {
    assert.ok(newChatRows(query, { folder: true }).includes(ROW), `query "${query}" must reach ${ROW}`);
  }
  assert.ok(journey.toLowerCase().includes(label[1].toLowerCase()), 'the journey types the row label');
});

test('SOFT-3050 the journey hands the app the workspace folder the row needs', () => {
  assert.match(drive, /if \(\$isAntigravity\) \{ \$savedSession\.tabs\[0\]\.ccwd = '\/verify\/work' \}/, 'the Antigravity journey must seed the chat folder the palette and the launch use');
  assert.match(journey, new RegExp(`Palette-Choose 'new antigravity sessions' ${offsetOf(ROW)}\\b`), 'the journey picks the Antigravity row by its offset');
});
