const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const palette = read('src/command_palette.zig');

function updateSearchResultsBody() {
  const start = palette.indexOf('pub fn updateSearchResults()');
  assert.ok(start >= 0, 'updateSearchResults not found');
  const next = palette.indexOf('\npub fn ', start + 10);
  return palette.slice(start, next < 0 ? palette.length : next);
}

function driverFiles() {
  const dir = path.join(root, 'tools', 'verify-chat-delivery');
  const files = fs.readdirSync(dir)
    .filter(name => name.endsWith('.ps1'))
    .map(name => `tools/verify-chat-delivery/${name}`);
  files.push('tools/verify-session-actions/drive.ps1');
  return files;
}

function typedQueries(text) {
  const queries = new Set();
  for (const [, query] of text.matchAll(/\$query = '([^']+)'/g)) queries.add(query);
  for (const [, query] of text.matchAll(/\b(?:Model-|Hax-|Switch-)?Palette '([^']+)'/g)) queries.add(query);
  return queries;
}

function labelEntries() {
  return [...palette.matchAll(/^\s+(SEARCH_\w+_OFFSET) => "([^"]+)",$/gm)]
    .map(([, name, label]) => ({ name, label }));
}

test('every chat view command a Windows driver types still has a producer in the palette', () => {
  const body = updateSearchResultsBody();
  const labels = labelEntries();
  const checked = [];
  const missing = [];
  for (const file of driverFiles()) {
    for (const query of typedQueries(read(file))) {
      if (!/^chat view /i.test(query)) continue;
      const lower = query.toLowerCase();
      const entry = labels.find(item => item.label.toLowerCase().startsWith(lower));
      if (!entry) {
        missing.push(`${file}: no palette label starts with "${query}"`);
        continue;
      }
      checked.push(query);
      const produced = new RegExp(`g_search_results\\[[^\\]]+\\]\\s*=\\s*${entry.name}\\b`).test(body);
      if (!produced) {
        missing.push(`${file}: "${query}" types ${entry.name} but updateSearchResults never produces it`);
      }
    }
  }
  assert.ok(checked.includes('chat view select all'), 'no driver types the select all command');
  assert.deepEqual(missing, []);
});
