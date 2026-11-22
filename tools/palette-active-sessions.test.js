const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');

function fnBody(source, signature) {
  const start = source.indexOf(signature);
  assert.ok(start >= 0, signature);
  const nextFn = source.indexOf('\nfn ', start + signature.length);
  const nextPub = source.indexOf('\npub fn ', start + signature.length);
  const ends = [nextFn, nextPub].filter(index => index >= 0);
  assert.ok(ends.length > 0, signature);
  return source.slice(start, Math.min(...ends));
}

test('SOFT-2444 Ctrl+K lists active sessions and leaves archived ones in the archive view', () => {
  const palette = read('src/command_palette.zig');
  const workspaces = read('src/workspaces.zig');
  const main = read('src/main.zig');
  const archive = read('src/archive.zig');
  const listed = fnBody(palette, 'fn paletteShellIsActive(');
  assert.match(listed, /shell\.inbox_archived and !shell\.needs_attention/);
  assert.match(listed, /workspaceSlotArchived\(shell\.workspace\)/);
  const rows = fnBody(palette, 'fn appendPaletteShellRows(');
  assert.match(rows, /if \(!paletteShellIsActive\(i\)\) continue;/);
  const searchStart = palette.indexOf('pub fn updateSearchResults()');
  const searchEnd = palette.indexOf('\nfn appendExtendedChatActions(', searchStart);
  assert.ok(searchStart >= 0 && searchEnd > searchStart);
  const search = palette.slice(searchStart, searchEnd);
  assert.match(search, /appendPaletteShellRows\(\);/);
  assert.doesNotMatch(search, /SEARCH_ARCHIVED_OFFSET/);
  assert.match(search, /SEARCH_GOINBOX_OFFSET/);
  const slot = fnBody(workspaces, 'pub fn workspaceSlotArchived(');
  assert.match(slot, /findWorkspace\(/);
  assert.match(slot, /\.archived/);
  assert.match(main, /target == SEARCH_ARCHIVED_VIEW_OFFSET[\s\S]*g_all_sessions_tab = AS_TAB_ARCHIVED/);
  assert.match(archive, /sessionOverviewAdd\(\.archived/);
});
