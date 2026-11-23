const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'src', 'command_palette.zig'), 'utf8');

function body(signature) {
  const start = source.indexOf(signature);
  assert.notEqual(start, -1, `${signature} exists`);
  let depth = 0;
  for (let i = source.indexOf('{', start); i < source.length; i++) {
    if (source[i] === '{') depth++;
    if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error(`${signature} is unbalanced`);
}

test('IGSH-1908: an open session matches Ctrl+K by its folder name', () => {
  const rows = body('fn appendPaletteShellRows() void {');
  assert.match(rows, /sessionFolderMatchesQuery\(&app_state\.shells\[i\], q\)/, 'open session rows test the folder name');
  const update = body('pub fn updateSearchResults() void {');
  const call = update.indexOf('appendPaletteShellRows()');
  assert.ok(call >= 0 && update.indexOf('appendTmuxCacheRows', call) > call, 'session rows stay ahead of unattached tmux rows');
  assert.match(body('fn sessionFolderLeaf('), /claude_cwd_len > 0[\s\S]*cached_cwd/, 'folder comes from the chat folder, else the shell folder');
});

test('IGSH-1908: a folder hit ranks the open chat ahead of an archived row with that name', () => {
  const rank = body('fn paletteQueryRank(target: usize) u8 {');
  const shellBranch = rank.slice(rank.indexOf('if (target < app_state.shell_count) {'), rank.indexOf('const group_index'));
  assert.match(shellBranch, /paletteTextMatchRank\(sessionFolderLeaf\(&app_state\.shells\[target\]\), query\)/, 'folder hit counts toward the match rank');
  const outranks = body('fn paletteResultOutranks(');
  assert.match(outranks, /if \(key_open != prev_open\) return key_open;/, 'open session wins a match-quality tie with a non-session row');
});
