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
  assert.match(build, /const bridge_help_tests = b\.addSystemCommand\(&\.\{ "node", "--test", "tools\/zsb-help\.test\.js" \}\)/);
  assert.match(build, /bridge_help_tests\.step\.dependOn\(&bridge_install\.step\)/);
  assert.match(build, /bridge_help_tests\.setEnvironmentVariable\("BRIDGE_EXE", b\.getInstallPath/);
  assert.match(build, /test_step\.dependOn\(&bridge_help_tests\.step\)/);
  assert.doesNotMatch(read('.github/workflows/test.yml'), /run: node --test tools\/zsb-help\.test\.js/);
});
