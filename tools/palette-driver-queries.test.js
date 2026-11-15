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

test('SOFT-2385 local shells stay searchable and the empty-palette fixture matches live rows', () => {
  const rows = palette.slice(palette.indexOf('const SHELL_ROWS'), palette.indexOf('pub const PICK_REPO_LABEL'));
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 0, \.keywords = "command prompt cmd shell new cmd shell"/);
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 5, \.keywords = "powershell pwsh shell new powershell"/);
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 6, \.keywords = "bash shell new bash shell"/);
  assert.match(rows, /SEARCH_NEW_OFFSET \+ 7, \.keywords = "git bash mintty shell new git bash shell"/);
  const body = updateSearchResultsBody();
  assert.match(body, /if \(app_state\.g_search_len > 0\) \{[\s\S]*for \(SHELL_ROWS\)/);
  const fixture = read('tools/fixtures/IGSH-1743/palette-usage.tsv').trim().split(/\r?\n/).map(line => line.split('\t')[0]);
  for (const dead of ['2000', '6001', '6248', '5100', '5102']) assert.equal(fixture.includes(dead), false, dead);
  assert.deepEqual(fixture.slice(0, 10), ['6295', '3000', '4000', '6291', '6200', '6204', '6247', '7000', '8000', '6227']);
  const journey = read('.claude/skills/verify-multiprompt/control-feature-palette-order.ps1');
  assert.doesNotMatch(journey, /6248|use agent or terminal session name/);
  const speed = read('.claude/skills/verify-multiprompt/control-feature-command-palette.ps1');
  assert.match(speed, /open_ms = 460/);
  assert.match(speed, /Palette 'powershell' '2005'/);
  assert.match(updateSearchResultsBody(), /labelsMatchQuery\(&\[_\]\[\]const u8\{"manage snippets"\}[\s\S]*SEARCH_SNIPPET_MANAGE_OFFSET/);
  assert.match(speed, /scroll_ms = 100/);
  assert.match(speed, /close_ms = 100/);
  assert.match(speed, /after_ms = 100/);
  assert.match(speed, /Ctrl\+N: leave Other so the saved folder can start a tab[\s\S]*\$repoTabsBefore[\s\S]*Ctrl\+T: new tab in the harness folder/);
  assert.match(speed, /Palette 'close tab' '7110'/);
  const setup = read('.claude/skills/verify-multiprompt/control.ps1');
  const paletteSetup = setup.indexOf("if ($Feature -eq 'command-palette') {");
  const launch = setup.indexOf('$process = $job.Start(');
  assert.ok(paletteSetup > 0 && paletteSetup < launch);
  assert.match(setup.slice(paletteSetup, launch), /MP_VERIFY_REPOS = '\/tmp\/multiprompt-harness-folder'/);
});
