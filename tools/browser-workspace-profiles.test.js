const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = process.env.IGSH_224_SOURCE_ROOT || path.resolve(__dirname, '..');
const read = name => fs.readFileSync(path.join(root, name), 'utf8');

test('IGSH-224 launches resolve the stable workspace identity before selecting a profile', () => {
  const pane = read('src/browser_pane.zig');
  assert.match(pane, /browser_workspace_profile/);
  assert.match(pane, /g_ws_ids\[ws\]/);
  assert.match(pane, /g_ws_id_len\[ws\]/);
  assert.match(pane, /workspaceProfileForShell/);
  assert.match(pane, /ensureWorkspaceProfile/);
});

test('IGSH-224 native hosts discover the actual Chromium profile before binding a pipe', () => {
  const bridge = read('src/bridge.zig');
  assert.match(bridge, /nativeParentToken/);
  assert.match(bridge, /ProfileAlreadyRegistered/);
});

test('IGSH-224 remote commands cannot override the bound profile or window with CLI flags', () => {
  const bridge = read('src/browser_bridge.zig');
  assert.match(bridge, /if \(argv\.len == 0 or argv\[0\]\.len == 0 or argv\[0\]\[0\] == '-'\) return null/);
  assert.match(bridge, /zsb_profile_token = app_state\.g_zsb_bind_info\.profile/);
  assert.match(bridge, /" --profile \{s\}"/);
});

test('IGSH-224 moving a browser tab cannot retain or route through the previous workspace profile', () => {
  const pane = read('src/browser_pane.zig');
  const bridge = read('src/browser_bridge.zig');
  assert.match(pane, /return error\.WorkspaceProfileChanged/);
  assert.match(pane, /reconcileBrowserWorkspace\(app_state\.active_shell\)/);
  assert.match(pane, /workspaceProfileIdentityForShell\(idx, &app_state\.shells\[idx\]\.browser_profile_token\)/);
  assert.match(bridge, /reconcileBrowserWorkspace\(ti\)/);
});

test('IGSH-224 local CLI reads one atomic window and profile binding instead of falling back to the shared pipe', () => {
  const bridge = read('src/bridge.zig');
  const pane = read('src/browser_pane.zig');
  assert.match(bridge, /g_window_binding_profile/);
  assert.match(bridge, /g_window_binding_required/);
  assert.match(pane, /writeFileAtomicW\(path, s\)/);
  assert.match(pane, /"\{d\}\\n\{s\}\\n"/);
});

test('IGSH-224 finishing a seed copy cannot retain foreground authority after the user switches away', () => {
  const pane = read('src/browser_pane.zig');
  const start = pane.indexOf('pub fn handleWorkspaceProfileReady(');
  assert.notEqual(start, -1);
  const ready = pane.slice(start, pane.indexOf('\nfn launchBrowserForShellEx(', start));
  assert.match(ready, /job\.user_initiated and idx == app_state\.active_shell and foregroundIsOurs\(\) and !browserChromeHiddenForOverlay\(\)/);
});

test('IGSH-224 profile completion has its own native message ID', () => {
  const declarations = [...(read('src/win32.zig') + '\n' + read('src/app_state.zig')).matchAll(/pub const (WM_APP_\w+): u32 = WM_APP \+ (\d+);/g)];
  const profile = declarations.find(value => value[1] === 'WM_APP_BROWSER_PROFILE_READY');
  assert.ok(profile);
  assert.deepEqual(declarations.filter(value => value[2] === profile[2]).map(value => value[1]), ['WM_APP_BROWSER_PROFILE_READY']);
});

test('IGSH-224 full browser checks build the native executable before sweeping real CLI help', () => {
  const build = read('build.zig');
  assert.match(build, /const zsb_help_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help\.test\.js" \}\)/);
  assert.match(build, /zsb_help_tests\.step\.dependOn\(&bridge_install\.step\)/);
  assert.match(build, /zsb_help_tests\.setEnvironmentVariable\("BRIDGE_EXE", b\.getInstallPath/);
  assert.match(build, /test_step\.dependOn\(&zsb_help_tests\.step\)/);
  const workflow = read('.github/workflows/test.yml');
  const sweep = /run: zig build test --summary all -Dtest-group=\$\{\{ matrix.group \}\} -Dcpu=x86_64_v3\s+- name: Sweep real zsb.exe command help\s+if: steps.rule.outputs.kind != 'STAMP' && matrix.group == 3\s+run: node --test tools\/zsb-help\.test\.js/;
  assert.match(workflow, sweep);
  assert.doesNotMatch(workflow.replace('run: zig build test --summary all', 'run: echo skipped'), sweep);
});

test('IGSH-224 conversions retain durable workspace IDs independently of window transport IDs', () => {
  const pane = read('src/browser_pane.zig');
  const session = read('src/session.zig');
  const workspaces = read('src/workspaces.zig');
  const identity = pane.slice(pane.indexOf('fn workspaceProfileIdentityForShell('), pane.indexOf('pub fn workspaceProfileForShell('));
  assert.match(identity, /if \(ws < app_state\.g_lws_count and app_state\.g_ws_id_len\[ws\] > 0\)/);
  assert.match(session, /\\"workspace_id\\":\\"/);
  assert.match(session, /if \(!json_reader\.boolTrue\(json, "single_window"\)\) \{[\s\S]*?copyString\(json, "workspace_id", &id_buf\)/);
  assert.match(session, /@memcpy\(app_state\.g_ws_ids\[0\]\[0\.\.id_len\], id_buf\[0\.\.id_len\]\)/);
  const leave = workspaces.slice(workspaces.indexOf('fn leaveSingleWindowMode('), workspaces.indexOf('pub fn newWorkspace('));
  assert.match(leave, /app_state\.g_ws_ids\[0\] = original_ids\[active_slot\]/);
  assert.match(leave, /app_state\.g_ws_id_len\[0\] = original_id_lengths\[active_slot\]/);
  assert.doesNotMatch(leave, /app_state\.g_ws_id_len\[ws\] = 0/);
  assert.match(workspaces, /const workspace_id = if \(src_wid_len\[src_ws\] > 0\)/);
});

test('IGSH-224 live browser journey proves every lifecycle stage and background host isolation', () => {
  const control = read('.claude/skills/verify-multiprompt/control.ps1');
  const journey = control.slice(control.indexOf("        'browser-workspaces' {"), control.indexOf("        'inbox' {"));
  for (const stage of ['renamed', 'reordered', 'multi-window', 'single-window', 'reopened', 'after']) {
    assert.ok(journey.includes(`Assert-WorkspaceProfile '${stage}' $targetId $targetRoot $bookmark`));
  }
  for (const action of ['rename workspace', 'sort workspaces', 'window mode', 'close workspace', 'IGSH224 Journey']) {
    assert.ok(journey.includes(`Palette '${action}'`));
  }
  assert.match(journey, /Ctrl\+D: bookmark this page in Edge/);
  assert.match(journey, /\$parked\.result\.url -cne \$bookmark -or \$foreign\.result\.url -ceq \$bookmark/);
  assert.match(journey, /\(Read-Session\)\.active_workspace -ne 0/);
  const observe = control.slice(control.indexOf('function Assert-WorkspaceProfile('), control.indexOf('function Select-Theme('));
  assert.match(observe, /workspace_id -cne \$Id/);
  assert.match(observe, /\$Bookmark -notin \$urls/);
  assert.match(observe, /\$live\.Count -ne 1/);
  assert.doesNotMatch(journey, /Set-Content|WriteAllText|WriteAllBytes|PostMessage/);
});

test('IGSH-224 workspace rename stays in the palette and captures its stable target instead of requesting native focus', () => {
  const main = read('src/main.zig');
  const begin = main.slice(main.indexOf('if (target == SEARCH_RENAMEWIN_OFFSET)'), main.indexOf('if (target >= SEARCH_WORKSPACE_OFFSET)', main.indexOf('if (target == SEARCH_RENAMEWIN_OFFSET)')));
  assert.ok(begin.length > 0);
  assert.match(begin, /g_search_rename_input_mode = true/);
  assert.match(begin, /g_search_rename_workspace_len/);
  assert.match(begin, /g_ws_ids\[ws\]/);
  assert.doesNotMatch(begin, /startWindowRename|showActiveShellAfterOverlay|SetFocus|SetForegroundWindow/);
  assert.match(main, /findMyWorkspaceSlot\(app_state\.g_search_rename_workspace_id\[0\.\.app_state\.g_search_rename_workspace_len\]\)/);
  assert.match(read('src/shortcuts.zig'), /if \(\(kb\.flags & 0x10\) == 0\)/);
});

test('IGSH-224 workspace reopening cannot select a frame transport alias instead of the durable workspace', () => {
  const palette = read('src/command_palette.zig');
  const lookup = palette.slice(palette.indexOf('fn workspaceMatchesSearch('), palette.indexOf('pub fn tmuxHostMatchesQuery('));
  assert.match(lookup, /app_state\.g_single_window/);
  assert.match(lookup, /getInstanceName\(\)/);
  assert.match(lookup, /findMyWorkspaceSlot\(e\.id\[0\.\.e\.id_len\]\) == null\) return false/);
  assert.ok(lookup.indexOf('return false') < lookup.indexOf('if (query.len == 0) return true'));
  assert.doesNotMatch(palette, /app_state\.g_search_len == 0 or workspaceMatchesSearch/);
});

test('IGSH-224 collapse preserves default-named sibling sessions until absorption', () => {
  const workspaces = read('src/workspaces.zig');
  const collapse = workspaces.slice(workspaces.indexOf('fn collapseOtherWindowsIntoThis('));
  assert.match(collapse, /PostMessageW\(target, @import\("win32.zig"\).WM_APP_QUIT_ALL, 0, 0\)/);
  assert.match(read('src/main.zig'), /WM_APP_QUIT_ALL => \{\s+app_state.g_quit_all_in_progress = true;\s+rememberOpenWorkspaceForQuit\(\);/);
  assert.match(read('src/main.zig'), /g_current_workspace_restore = app_state.g_quit_all_in_progress/);
  assert.match(workspaces, /pub fn gcDefaultNamedWindowOnClose\(\) void \{[\s\S]*?if \(app_state.g_current_workspace_restore\) return;/);
});
