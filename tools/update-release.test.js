const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const root = process.env.UPDATE_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('release updater is default on and checks before session restoration', () => {
  const main = read('src/main.zig');
  assert.match(main, /if \(update_release\.startup\(args\)\) return;/);
  const updater = read('src/update_release.zig');
  assert.match(updater, /pub const IGSH_246 = true;/);
  assert.ok(main.indexOf('update_release.startup(args)') < main.indexOf('const restored = restoreSession()'));
  assert.match(main, /update_release\.ready\(\)/);
  assert.match(read('src/update_card.zig'), /update_release\.poll\(\)/);
  assert.match(main, /_ = startUpdateCardWatch\(\);\s*_ = SetTimer\(hwnd, TIMER_UPDATE_CHECK/);
});

test('periodic update never invokes restart and explicit restart uses the verified helper', () => {
  const updater = read('src/update_release.zig');
  const poll = updater.slice(updater.indexOf('pub fn poll()'), updater.indexOf('pub fn restart('));
  assert.doesNotMatch(poll, /restart\(|"Apply"|quitAll/);
  assert.match(updater, /3 \* 60 \* 60 \* 1000/);
  assert.match(read('src/update_card.zig'), /update_release\.restart\(/);
  assert.match(read('src/sidebar.zig'), /Restart to update/);
  assert.match(read('src/update_card.zig'), /Update ready: restart to get v/);
});

test('Windows behavioral update tests are required by CI', () => {
  assert.match(read('.github/workflows/test.yml'), /powershell -NoProfile -File tools\/update-release\.test\.ps1/);
  const suite = read('tools/update-release.test.ps1');
  for (const name of ['checksum mismatch refused', 'rollback after failed start', 'no automatic restart while running', 'version comparison']) assert.ok(suite.includes(name), name);
});

const repeatedProcessPathFilters = source => {
  const lines = [];
  for (const match of source.matchAll(/\bWhere-Object\s*\{/gi)) {
    let depth = 1;
    let end = match.index + match[0].length;
    while (end < source.length && depth > 0) {
      if (source[end] === '{') depth++;
      if (source[end] === '}') depth--;
      end++;
    }
    const block = source.slice(match.index, end);
    if ((block.match(/\$_\.Path\b/gi) || []).length > 1) lines.push(source.slice(0, match.index).split('\n').length);
  }
  return lines;
};

test('process path guard detects repeated reads in single-line and nested filters', () => {
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $_.Path -and $_.Path.StartsWith($Root) }'), [1]);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object {\n if ($_.Path) { $_.Path -eq $target }\n}'), [1]);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $p = $_.Path; $p -and $p.StartsWith($Root) }'), []);
  assert.deepEqual(repeatedProcessPathFilters('Get-Process | Where-Object { $_.Path -eq $target }\nGet-Process | Where-Object { $_.Path -eq $other }'), []);
});

test('PowerShell test helpers read each process path once per filter', () => {
  const violations = [];
  for (const directory of ['tools', '.claude/skills/verify-multiprompt']) {
    for (const name of fs.readdirSync(path.join(root, directory), { recursive: true }).filter(name => /\.ps1$/i.test(name))) {
      const file = path.join(directory, name);
      for (const line of repeatedProcessPathFilters(read(file))) violations.push(`${file}:${line}`);
    }
  }
  assert.deepEqual(violations, [], 'Snapshot $_.Path once before checking or invoking methods on it');
});

test('the update command cannot be interpreted as a snippet', () => {
  const state = read('src/app_state.zig');
  const value = name => Number(new RegExp(`pub const ${name}: usize = (\\d+);`).exec(state)[1]);
  const update = value('SEARCH_UPDATE_OFFSET');
  const snippets = value('SEARCH_SNIPPET_OFFSET');
  assert.ok(update < snippets || update >= snippets + value('MAX_SNIPPETS'), 'Update command overlaps snippet IDs');
  const duplicates = [...state.matchAll(/pub const (SEARCH_\w+): usize = (\d+);/g)].filter(([, name, number]) => name !== 'SEARCH_UPDATE_OFFSET' && Number(number) === update);
  assert.deepEqual(duplicates, []);
});
