const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const { readChangelogEntry } = require('./changelog-entry');

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
  const start = palette.indexOf('fn spawnWorkspaceSession(with_agent: bool, plain_claude: bool) bool {');
  assert.ok(start >= 0, 'the new-session path must exist');
  const body = palette.slice(start, palette.indexOf('\nfn ', start + 10));
  assert.ok(!body.includes('workspacePrimaryRepo'), 'a workspace with no folder must not guess a repo');
  assert.match(body, /pickRepoOpen\(with_agent, false, workspaceHostForNewTab\(workspace\), plain_claude\);/,
    'it must open the Pick repo list for this session kind');
  assert.match(body, /return spawnWorkspaceSessionAt\(host, cwd_buf\[0\.\.cwd_len\], program_buf\[0\.\.program_len\], with_agent, plain_claude\);/,
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
  assert.match(readChangelogEntry('IGSH-1266'), /[A-Za-z]/);
});

test('IGSH-1266 saving the workspace folder tells the user', () => {
  const main = read('src/main.zig');
  assert.match(main, /const saving_folder = app_state\.g_search_pick_repo_folder_mode;/,
    'the confirm must remember whether this pick saves the folder');
  assert.match(main, /if \(saving_folder and picked\) showHeaderNoticeAscii\("Workspace folder saved; new tabs start there"/,
    'saving the folder must confirm it on screen, not only in the file');
});

test('IGSH-1266 the pick rows paint their ellipsis on the wide text path', () => {
  const sidebar = read('src/sidebar.zig');
  assert.match(sidebar, /_ = DrawTextW\(hdc, if \(result_idx == SEARCH_PICK_REPO_OFFSET\) L\("Pick repo\.\.\."\) else L\("Set workspace folder\.\.\."\)/,
    'the row labels are wide text drawn directly, because the palette label normaliser strips trailing dots');
  assert.match(read('src/palette_text.zig'), /out\[len - 1\] == '\.' or out\[len - 1\] == 0x2026/,
    'the palette label normaliser strips trailing dots, which is why these two rows draw wide text directly');
  assert.match(read('src/command_palette.zig'), /pub const PICK_REPO_LABEL = "Pick repo\.\.\.";/);
  assert.doesNotMatch(sidebar, /drawAscii\(hdc, pickRepoLabel/,
    'a UTF-8 ellipsis drawn as ASCII paints as mojibake');
});

test('IGSH-1266 the launch buffers hold every path the launch accepts', () => {
  const palette = read('src/command_palette.zig');
  const host = read('src/agent_host.zig');
  const state = read('src/app_state.zig');

  const number = (source, pattern, what) => {
    const found = source.match(pattern);
    assert.ok(found, what);
    return Number(found[1]);
  };
  const pathCap = number(palette, /fn remotePathSafeForShell\(path: \[\]const u8\) bool \{\s*if \(path\.len == 0 or path\.len > (\d+)\) return false;/, 'the shell path cap must exist');
  const hostPathCap = number(host, /fn safePath\(value: \[\]const u8\) bool \{\s*if \(value\.len == 0 or value\.len > (\d+)\) return false;/, 'the host path cap must exist');
  const nameCap = number(host, /fn safeName\(value: \[\]const u8\) bool \{\s*if \(value\.len == 0 or value\.len > (\d+)\) return false;/, 'the session name cap must exist');
  const hostMax = number(palette, /pub const WORKSPACE_HOST_LAUNCH_MAX: usize = (\d+);/, 'the host buffer size must be named');
  const pendingMax = number(state, /pub var g_pending_tmux_cmd: \[(\d+)\]u8 = std\.mem\.zeroes/, 'the pending command buffer must exist');
  const reader = host.match(/pub const READER = "([^"]+)";/);
  assert.ok(reader, 'the runtime path must be named once');
  const mode = host.match(/const mode = if \(provider == \.claude\) "([^"]*)" else "";/);
  assert.ok(mode, 'the permission mode must be named once');

  const launch = host.slice(host.indexOf('pub fn launchCommandFor('));
  const format = launch.match(/std\.fmt\.bufPrint\(out, "([^"]*)"/);
  assert.ok(format, 'the host launch format must be readable');
  const args = launch.match(/\.\{ ([^}]*?) \}\) catch null;/);
  assert.ok(args, 'the host launch arguments must be readable');
  const caps = {
    session: nameCap,
    cwd: Math.min(pathCap, hostPathCap),
    READER: reader[1].length,
    sid: 36,
    mode: mode[1].length,
    name: 'codex'.length,
  };
  const parts = format[1].split('{s}');
  const ordered = args[1].split(',').map((value) => value.trim());
  assert.equal(parts.length - 1, ordered.length, 'every format hole must have one argument');
  let worst = parts[0].length;
  ordered.forEach((arg, index) => {
    assert.ok(caps[arg] !== undefined, `unknown launch argument ${arg}`);
    worst += caps[arg] + parts[index + 1].length;
  });

  assert.ok(hostMax >= worst, `the host buffer ${hostMax} must hold ${worst} bytes of launch command`);
  assert.ok(pendingMax >= worst, `the pending command buffer ${pendingMax} must hold ${worst} bytes`);
  assert.match(palette, /fn buildWorkspaceTmuxLaunchCmd\(out: \[\]u8,/,
    'the plain terminal command must take its size from the caller, not a fixed 512 bytes');
});

test('IGSH-1266 a pick that starts nothing says which step refused it', () => {
  const palette = read('src/command_palette.zig');
  const main = read('src/main.zig');
  assert.doesNotMatch(main, /Pick repo: nothing chosen/, 'the catch-all message hid the real reason');
  assert.match(main, /if \(!picked\) showPickRepoFailure\(saving_folder\);/, 'every refusal must go through the reason helper');
  assert.match(main, /\.capacity => \{\},/, 'a capacity refusal already shows its own notice and must not be overwritten');
  assert.match(main, /Pick repo: that row is gone; open the list again/);
  assert.match(main, /Pick repo: that folder path cannot start a session/);
  assert.match(main, /Pick repo: the new tab did not start/);
  assert.match(main, /Set workspace folder: could not save/);

  const chosen = palette.slice(palette.indexOf('pub fn pickRepoChoose(target: usize) bool {'), palette.indexOf('fn customCmdMatchesQuery('));
  assert.match(chosen, /g_pick_row_gone = true;/, 'a row that is gone must be named');
  assert.match(chosen, /debugLog\("\[pick\] chosen row is no longer in the repo list"\)/);
  const spawnAt = palette.slice(palette.indexOf('fn spawnWorkspaceSessionAt('), palette.indexOf('fn workspaceFolderForNewChat('));
  assert.match(spawnAt, /g_start_fail = \.capacity;/);
  assert.match(spawnAt, /g_start_fail = \.launch_command;/);
  assert.match(spawnAt, /g_start_fail = \.spawn_shell;/);
  assert.match(spawnAt, /debugLog\("\[pick\] new workspace session refused: launch command does not fit"\)/);
  assert.match(spawnAt, /debugLog\("\[pick\] new workspace session refused: shell spawn"\)/);
  assert.doesNotMatch(spawnAt, /orelse return false;/, 'no step may fail without naming itself');
});
