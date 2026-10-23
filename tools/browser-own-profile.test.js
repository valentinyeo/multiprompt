const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const own = read('src/browser_own_profile.zig');
const pane = read('src/browser_pane.zig');
const bridge = read('src/bridge.zig');
const zsb = read('src/browser_bridge.zig');
const control = read('.claude/skills/verify-multiprompt/control.ps1');

function body(source, name) {
  const start = source.indexOf(`fn ${name}(`);
  assert.ok(start >= 0, `${name} must exist`);
  const end = source.indexOf('\n}\n', start);
  assert.ok(end > start, `${name} must end`);
  return source.slice(start, end + 3);
}

function tokenFor(id) {
  return 'own-' + crypto.createHash('sha256').update(id, 'utf8').digest('hex').slice(0, 24);
}

test('IGSH-672 the opt-in file is a read-only list of workspace ids next to the other browser settings', () => {
  assert.match(own, /pub const FILE_NAME = "browser-own-profile\.txt";/);
  assert.match(body(pane, 'ownProfileConfigPath'), /"\\\\ZigShell\\\\" \+\+ browser_own_profile\.FILE_NAME/);
  const launchToken = body(pane, 'ownProfileTokenForLaunch');
  assert.match(launchToken, /win32OpenRead\(config_path\) orelse return null/);
  assert.doesNotMatch(launchToken, /win32OpenWrite|DeleteFile|MoveFile/);
  assert.doesNotMatch(pane, /win32OpenWrite\([^)]*ownProfileConfigPath|ownProfileConfigPath[^\n]*win32OpenWrite/);
  assert.match(body(own, 'listed'), /std\.mem\.trim\(u8, line, " \\t\\r"\), workspace_id/);
});

test('IGSH-672 token and folder derivation match SHA-256 in Zig and in the verify journey', () => {
  const expected = tokenFor('ws-inne-test');
  assert.equal(expected, 'own-9fcaf773c928d505d4457afd');
  assert.ok(own.includes(`"${expected}"`), 'Zig test vector must match SHA-256');
  assert.ok(own.includes(`BrowserWorkspaces\\\\chrome\\\\${expected}`), 'Zig folder vector must match SHA-256');
  assert.ok(control.includes(expected), 'journey must cross-check the same vector');
  assert.match(own, /pub const TOKEN_LEN = 28;/);
  assert.match(own, /const token_prefix = "own-";/);
  assert.match(body(own, 'path'), /\{s\}\\\\ZigShell\\\\BrowserWorkspaces\\\\\{s\}\\\\\{s\}/);
  assert.ok(expected.length <= 32 && /^[a-z0-9-]+$/.test(expected) && !expected.startsWith('-'), 'token must be a valid pipe token');
  assert.ok(!/^[0-9a-f]{30}$/.test(expected), 'must not look like a leftover IGSH-224 hash folder');
});

test('IGSH-672 a workspace that is not opted in launches and routes exactly like before', () => {
  const launch = body(pane, 'shellExecuteEdgeUrl');
  assert.match(launch, /const user_data_dir = browserUserDataDir\(\);/);
  assert.match(launch, /const launch_dir = if \(own_token\.len > 0\) ownBrowserUserDataDir\(&own_dir_buf, own_token\) else user_data_dir;/);
  const cli = body(pane, 'spawnBrowserCliForShell');
  assert.match(cli, /if \(own_token\.len == 0\) \{\s+spawnBrowserCliHidden\(cmd\);\s+return;\s+\}/);
  assert.match(body(own, 'command'), /if \(value\.len == 0\) return std\.fmt\.bufPrint\(buf, "\{s\}", \.\{original\}\);/);
  const file = body(pane, 'writeBrowserWindowIdFile');
  assert.match(file, /if \(own_token\.len > 0\) std\.fmt\.bufPrint\(&numbuf, "\{d\}\\n\{s\}\\n", \.\{ wid, own_token \}\) else std\.fmt\.bufPrint\(&numbuf, "\{d\}\\n", \.\{wid\}\)/);
  assert.match(body(pane, 'assignBrowserProfileForLaunch'), /browser_profile_token = std\.mem\.zeroes\(\[32\]u8\);/);
  const native = bridge.slice(bridge.indexOf('g_profile_token = if (is_legacy_host)'), bridge.indexOf('var pipe_name_buf: [128]u8 = undefined;'));
  assert.match(native, /if \(own_profile\.nativeParentToken\(allocator, &g_native_own_profile\) catch null\) \|own\| g_profile_token = own;/);
  assert.match(body(own, 'tokenFromPath'), /return null;/);
});

test('IGSH-672 an opted-in pane keeps its own browser for launch, reuse, commands and restore', () => {
  const launch = body(pane, 'launchBrowserForShellEx');
  assert.ok(launch.indexOf('assignBrowserProfileForLaunch(idx);') >= 0);
  assert.ok(launch.indexOf('assignBrowserProfileForLaunch(idx);') < launch.indexOf('isolatedBrowserHasLivePane(idx)'));
  assert.match(body(pane, 'isolatedBrowserHasLivePane'), /if \(!std\.mem\.eql\(u8, &app_state\.shells\[i\]\.browser_profile_token, &app_state\.shells\[skip_idx\]\.browser_profile_token\)\) continue;/);
  for (const name of ['requestInactivePaneWindow', 'bindBrowserWindowIdForShell', 'navigateBrowserPaneWithActivation']) {
    assert.match(body(pane, name), /spawnBrowserCliForShell\(idx, /, name);
    assert.doesNotMatch(body(pane, name), /spawnBrowserCliHidden\(/, name);
  }
  assert.match(body(pane, 'browserWindowResolveWorker'), /browser_command_profile = job\.profile;/);
  assert.match(body(pane, 'resolveBrowserWindowIdFromCommand'), /browser_own_profile\.command\(&qualified_buf, raw_cmd, std\.mem\.sliceTo\(&browser_command_profile, 0\)\)/);
  assert.match(body(pane, 'startBrowserWindowResolve'), /\.profile = app_state\.shells\[idx\]\.browser_profile_token/);
  assert.match(body(pane, 'sendBrowserLifecycle'), /job\.profile = app_state\.shells\[idx\]\.browser_profile_token;/);
  assert.match(body(zsb, 'zsbBuildBridgeCmd'), /if \(zsb_profile_token\[0\] != 0\)/);
  assert.match(zsb, /if \(found\) zsb_profile_token = app_state\.g_zsb_bind_info\.profile;/);
  assert.match(read('src/console.zig'), /\.browser_profile_token = saved_browser_profile_token,/);
  assert.match(body(bridge, 'resolveWindowFromEnv'), /if \(own_profile\.isToken\(own\)\)/);
});

test('IGSH-672 never clones, migrates, claims or names private data and adds no new UI', () => {
  for (const forbidden of ['workspace-owner', 'browser_profile_clone', 'adoptLegacyProfile', 'ensureWorkspaceProfile', 'requireSourceClosed', 'CopyFile', 'DeleteFile', 'MoveFile', 'RemoveDirectory']) {
    assert.ok(!own.includes(forbidden), forbidden);
  }
  for (const name of ['ownProfileConfigPath', 'ownProfileTokenForLaunch', 'assignBrowserProfileForLaunch', 'ownBrowserUserDataDir', 'spawnBrowserCliForShell']) {
    assert.doesNotMatch(body(pane, name), /CopyFile|DeleteFile|MoveFile|RemoveDirectory|win32OpenWrite|\.workspace-owner/, name);
  }
  for (const file of ['src/command_palette.zig', 'src/shortcuts.zig', 'src/sidebar.zig', 'openwiki/operations/keyboard-shortcuts.md']) {
    assert.ok(!read(file).includes('browser-own-profile') && !read(file).toLowerCase().includes('own browser profile'), file);
  }
  assert.doesNotMatch(own + pane, /ws-\d{6,}-\d/);
});
