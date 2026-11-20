const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');

test('SOFT-2883 pick repo selection follows folder identity across list refresh', () => {
  const palette = readFileSync('src/command_palette.zig', 'utf8');
  assert.match(palette, /fn capturePickRepoAnchorFromSelection\(\) void \{/);
  assert.match(palette, /fn applyPickRepoAnchorToSelection\(\) void \{/);
  assert.match(palette, /finishPickRepoSelectionAfterRebuild\(query_changed\)/);
  assert.match(palette, /if \(!query_changed\) capturePickRepoAnchorFromSelection\(\);/);
  assert.match(palette, /sortFilteredResultsAfterBack\(\);\s+finishPickRepoSelectionAfterRebuild\(query_changed\);/);
  assert.match(palette, /SOFT-2883 pick repo keeps the highlighted folder when the list refreshes/);
});