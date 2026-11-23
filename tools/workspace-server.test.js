const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('SOFT-3051 move and new-tab-on-server palette rows are wired', () => {
  const state = read('src/app_state.zig');
  assert.match(state, /SEARCH_MOVE_WORKSPACE_SERVER_OFFSET: usize = 6966;/);
  assert.match(state, /SEARCH_NEW_TAB_ON_SERVER_OFFSET: usize = 6967;/);
  assert.match(state, /SEARCH_WORKSPACE_SERVER_ROW_OFFSET: usize = 6970;/);
  assert.match(state, /SEARCH_TABCTX_NEW_TAB_ON_SERVER: usize = 7174;/);
  const palette = read('src/command_palette.zig');
  assert.match(palette, /pub fn workspaceSpawnFolder\(/);
  assert.match(palette, /pub fn workspaceServerChoose\(/);
  assert.match(palette, /pub fn saveWorkspaceFolder\(/);
  assert.match(palette, /pub fn workspaceMissingFolderNotice\(/);
  const main = read('src/main.zig');
  assert.match(main, /if \(target == SEARCH_MOVE_WORKSPACE_SERVER_OFFSET or target == SEARCH_NEW_TAB_ON_SERVER_OFFSET/);
  assert.match(main, /workspaceServerChoose\(target\)/);
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /is_workspace_server_row/);
  const vps = read('src/vps.zig');
  assert.match(vps, /pub fn remoteWorkspaceFolderExists\(/);
  assert.match(vps, /pub fn remoteGitOriginUrl\(/);
});

test('SOFT-3051 unit tests cover host override persistence and missing-folder text', () => {
  const palette = read('src/command_palette.zig');
  assert.match(palette, /test "SOFT-3051 folder_host overrides primary repo host"/);
  assert.match(palette, /test "SOFT-3051 saved folder entry persists folder_host"/);
  assert.match(palette, /test "SOFT-3051 missing folder notice names server path and clone"/);
});