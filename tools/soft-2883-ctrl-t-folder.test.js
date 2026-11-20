const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');

const palette = readFileSync('src/command_palette.zig', 'utf8');

function functionBody(name, nextName) {
  const start = palette.indexOf(`fn ${name}(`);
  const end = palette.indexOf(`\nfn ${nextName}(`, start);
  assert.notStrictEqual(start, -1, `${name} is missing`);
  assert.notStrictEqual(end, -1, `could not isolate ${name}`);
  return palette.slice(start, end);
}

test('SOFT-2883 pick repo captures the highlighted folder before the list is rebuilt', () => {
  const updateStart = palette.indexOf('pub fn updateSearchResults(');
  assert.notStrictEqual(updateStart, -1, 'updateSearchResults is missing');
  const branchStart = palette.indexOf('if (app_state.g_search_pick_repo_mode) {', updateStart);
  assert.notStrictEqual(branchStart, -1, 'pick repo result builder is missing');
  const branchEnd = palette.indexOf('\n    if (app_state.g_search_remind_input_mode) {', branchStart);
  assert.notStrictEqual(branchEnd, -1, 'could not isolate pick repo result builder');
  const branch = palette.slice(branchStart, branchEnd);

  const captureCall = palette.indexOf('const pick_repo_query_changed = beginPickRepoRefresh();', updateStart);
  assert.notStrictEqual(captureCall, -1, 'the highlight must be captured through beginPickRepoRefresh');
  const reset = palette.indexOf('app_state.g_search_result_count = 0;', updateStart);
  const rebuild = palette.indexOf('g_presented_repo_count = pickRepoFilteredRows(', branchStart);
  assert.notStrictEqual(reset, -1, 'updateSearchResults must reset the result count');
  assert.notStrictEqual(rebuild, -1, 'the pick repo list rebuild is missing');
  assert.ok(captureCall < reset,
    'the highlight must be captured before g_search_result_count is reset');
  assert.ok(captureCall < rebuild,
    'the highlight must be captured before the folder rows are refiltered');

  const refresh = functionBody('beginPickRepoRefresh', 'pickRepoResultIndexForRow');
  assert.match(refresh, /app_state\.g_search_len != g_pick_repo_last_query_len/,
    'a refresh without a query change must keep the current highlight');
  assert.match(refresh, /if \(!query_changed\) capturePickRepoAnchorFromSelection\(\);/,
    'the unchanged-query refresh must capture the highlight');
  assert.match(refresh, /return query_changed;/,
    'the result builder must know whether the query changed');

  assert.match(branch, /finishPickRepoSelectionAfterRebuild\(pick_repo_query_changed\)/,
    'the pick repo branch must restore from the captured refresh state');
  assert.doesNotMatch(branch, /const query_changed = app_state\.g_search_len != g_pick_repo_last_query_len;/,
    'the highlight must not be captured after the list has been reset');
});

test('SOFT-2883 pick repo restores the highlight by host and path', () => {
  const capture = functionBody('capturePickRepoAnchorFromSelection', 'beginPickRepoRefresh');
  assert.match(capture, /g_pick_repo_anchor_host = row\.host;/,
    'the captured highlight must record the row host');
  assert.match(capture, /@memcpy\(g_pick_repo_anchor_path\[0\.\.row\.path_len\]/,
    'the captured highlight must record the row path');

  const apply = functionBody('applyPickRepoAnchorToSelection', 'finishPickRepoSelectionAfterRebuild');
  assert.match(apply, /repoRowSameIdentity\(&row, g_pick_repo_anchor_host, path\)/,
    'the selection must be restored by row identity, not by list position');
  assert.match(apply, /pickRepoResultIndexForRow\(@intCast\(i\)\)/,
    'the restored row must be mapped back to its new result index');

  const identity = functionBody('repoRowSameIdentity', 'clearPickRepoAnchor');
  assert.match(identity, /row\.host == host/);
  assert.match(identity, /std\.mem\.eql\(u8, row\.path\[0\.\.row\.path_len\], path\)/,
    'two folders with the same path but another host are different folders');
});

test('SOFT-2883 pick repo keeps the highlight across reordered and shrinking lists', () => {
  const start = palette.indexOf('test "SOFT-2883 pick repo keeps the highlighted folder when the list refreshes"');
  assert.notStrictEqual(start, -1, 'the regression test must stay in place');
  const end = palette.indexOf('\nfn seedWorkspaceFolder(', start);
  assert.notStrictEqual(end, -1, 'could not isolate the regression test');
  const body = palette.slice(start, end);
  assert.match(body, /pickRepoSelectPath\(multiprompt\)/);
  assert.match(body, /vps\.replaceRepoRowsForTest\(0, &\.\{ ios, android, multiprompt \}\)/,
    'the test must republish the folders in a new order');
  assert.match(body, /vps\.replaceRepoRowsForTest\(0, &\.\{ android, ios \}\)/,
    'the test must cover the chosen folder disappearing');
  assert.match(body, /try std\.testing\.expect\(app_state\.g_search_sel < app_state\.g_search_result_count\)/,
    'a vanished folder must still leave a valid selection');
});
