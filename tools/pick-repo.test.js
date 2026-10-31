const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const read = (file) => fs.readFileSync(file, 'utf8');

test('IGSH-1266 a workspace folder is declared once and the last entry wins', () => {
  const palette = read('src/command_palette.zig');
  assert.match(palette, /fn folderEntryIndexFor\(ws_name: \[\]const u8\) \?usize \{/,
    'the workspace folder lookup must pick one declared entry');
  assert.match(palette, /found = i;/, 'the lookup must remember the last matching entry, not return the first');
  assert.match(palette, /pub fn workspaceFolderCurrent\(ws: u8, out: \*\[256\]u8, out_len: \*u32\) bool \{/,
    'the palette row must be able to show the declared folder');
  assert.match(palette, /pub fn buildFolderEntry\(out: \[\]u8, host: u8, workspace: \[\]const u8, path: \[\]const u8\) \?\[\]const u8 \{/,
    'setting the folder must build a commands.json entry');
  assert.match(palette, /pub fn insertCommandEntry\(text: \[\]const u8, entry: \[\]const u8, out: \[\]u8\) \?\[\]const u8 \{/,
    'the entry must be appended to the existing commands array');
  assert.match(palette, /fn saveWorkspaceFolder\(host: u8, path: \[\]const u8\) bool \{/);
});

test('IGSH-1266 no declared folder opens Pick repo instead of guessing', () => {
  const palette = read('src/command_palette.zig');
  const start = palette.indexOf('fn spawnWorkspaceSession(with_agent: bool) bool {');
  assert.ok(start >= 0, 'the new-session path must exist');
  const body = palette.slice(start, palette.indexOf('\nfn ', start + 10));
  assert.ok(!body.includes('workspacePrimaryRepo'), 'a workspace with no folder must not guess a repo');
  assert.match(body, /pickRepoOpen\(with_agent, false, workspaceHostForNewTab\(workspace\)\);/,
    'it must open the Pick repo list for this session kind');
  assert.match(body, /return spawnWorkspaceSessionAt\(host, cwd_buf\[0\.\.cwd_len\], program_buf\[0\.\.program_len\], with_agent\);/,
    'a declared folder still starts the session there');
  assert.match(palette, /pub fn pickRepoFilteredRows\(out: \[\]RepoRow\) u32 \{/);
  assert.match(palette, /pub fn pickRepoChoose\(target: usize\) bool \{/);
  assert.match(palette, /pub const PICK_REPO_LABEL = /);
  assert.match(palette, /pub const SET_FOLDER_LABEL = /);
});

test('IGSH-1266 the repo list is cached and never blocks the palette', () => {
  const vps = read('src/vps.zig');
  assert.match(vps, /pub fn repoRowsForHost\(host: u8, out: \[\]RepoRow\) u32 \{/);
  assert.match(vps, /pub fn parseRepoListing\(host: u8, text: \[\]const u8, out: \[\]RepoRow\) u32 \{/);
  assert.match(vps, /pub fn requestRepoRefresh\(host: u8\) void \{/, 'the fetch must run in the background');
  assert.match(vps, /std\.Thread\.spawn\(/, 'the listing must not run on the UI thread');
  assert.match(vps, /WM_APP_TMUX_LIST_READY/, 'the palette repaints from the existing ready message');
});

test('IGSH-1266 Pick repo and Set workspace folder are painted, confirmed and documented', () => {
  const state = read('src/app_state.zig');
  assert.match(state, /pub const SEARCH_PICK_REPO_OFFSET: usize = \d+;/);
  assert.match(state, /pub const SEARCH_SET_FOLDER_OFFSET: usize = \d+;/);
  assert.match(state, /pub const SEARCH_PICK_REPO_ROW_OFFSET: usize = \d+;/);
  const main = read('src/main.zig');
  assert.match(main, /if \(target == SEARCH_PICK_REPO_OFFSET or target == SEARCH_SET_FOLDER_OFFSET\) \{/,
    'the palette confirm must handle both rows');
  assert.match(main, /const picked = pickRepoChoose\(target\);/);
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /is_pick_repo_row/, 'the repo rows must be painted');
  assert.match(sidebar, /Pick a repo/);
  assert.match(read('src/shortcuts.zig'), /Ctrl\+K -> Set workspace folder/);
  assert.match(read('openwiki/architecture/session-start.md'), /Pick repo/);
  assert.match(read('changelog.d/IGSH-1266-pick-repo.md'), /[A-Za-z]/);
});

test('IGSH-1266 saving the workspace folder tells the user', () => {
  const main = read('src/main.zig');
  assert.match(main, /const saving_folder = app_state\.g_search_pick_repo_folder_mode;/,
    'the confirm must remember whether this pick saves the folder');
  assert.match(main, /if \(saving_folder and picked\) showHeaderNoticeAscii\("Workspace folder saved; new tabs start there"/,
    'saving the folder must confirm it on screen, not only in the file');
});
