const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CHAT_REGRESSION_SOURCE_ROOT || process.cwd();
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const palette = read('src/command_palette.zig');
const main = read('src/main.zig');

function section(source, start, end) {
  const begin = source.indexOf(start);
  if (begin < 0) return '';
  const finish = source.indexOf(end, begin + start.length);
  return finish < 0 ? source.slice(begin) : source.slice(begin, finish);
}

test('group action captures the selected identity before clearing context', () => {
  const action = section(main, 'if (target == SEARCH_TABCTX_GROUP_NEW_TAB_IN) {', 'if (target == SEARCH_TABCTX_CHAT_VIEW) {');
  assert.match(action, /const group_target = @import\("command_palette\.zig"\)\.groupLaunchTarget\(app_state\.g_tabctx_sid\);[\s\S]*g_pending_new_tab_group = if \(group_target\) \|t\| t\.group else 0;[\s\S]*g_tabctx_sid = 0;[\s\S]*spawnGroupTmuxSession\(&group_target\.\?\)[\s\S]*applyPendingGroup\(\)/);
  assert.doesNotMatch(action, /spawnWorkspaceTmuxSession\(/);
  assert.match(action, /else \{\s*app_state\.g_pending_new_tab_group = 0;/);
});

test('group launch keeps target host and project with workspace program', () => {
  const target = section(palette, 'pub fn groupLaunchTarget(', '\ntest "group launch uses');
  assert.match(target, /findShellById\(sid\) orelse return null/);
  assert.match(target, /findGroupIdx\(group\) == null\) return null/);
  assert.match(target, /remoteHostForShell\(shell\) orelse return null/);
  assert.match(target, /const cwd = if \(live\)[\s\S]*shell\.cached_cwd_len > 0[\s\S]*shell\.claude_cwd_len > 0[\s\S]*else return null\)[\s\S]*else\s*@import\("vps\.zig"\)\.shellKnownRemotePath\(shell, host\)/);
  assert.match(target, /cwd\.len > target\.cwd\.len[\s\S]*cwd\[0\] != '\/'[\s\S]*!remotePathSafeForShell\(cwd\)/);
  assert.match(target, /std\.mem\.eql\(u8, part, "\.\."\)\) return null/);
  assert.match(target, /@memcpy\(target\.cwd\[0\.\.cwd\.len\], cwd\)/);
  const launch = section(palette, 'pub fn spawnGroupTmuxSession(', '\npub fn spawnWorkspacePlainClaudeSession(');
  assert.match(launch, /workspaceConfiguredTerminalFolder\(activeWorkspaceSlot\(\),[\s\S]*spawnWorkspaceSessionAt\(target\.host, target\.cwd\[0\.\.target\.cwd_len\], program\[0\.\.program_len\], true, false\)/);
});

test('native regressions cover live carrier and unsafe or missing targets', () => {
  const native = section(palette, 'test "group launch uses the targeted shell identity"', '\npub fn spawnGroupTmuxSession(');
  assert.match(native, /test "group launch ignores hosted carrier cwd but follows terminal cwd"/);
  assert.match(native, /const project = "\/home\/owner\/projects\/sample";[\s\S]*const carrier = "\/home\/login";/);
  assert.match(native, /entry\.host = 0;[\s\S]*expectEqualStrings\(project, other_host\.cwd/);
  assert.match(native, /shell\.cached_cwd_len = 0;\s*try std\.testing\.expect\(groupLaunchTarget\(42\) == null\)/);
  assert.match(native, /app_state\.group_count = 0;\s*try std\.testing\.expect\(groupLaunchTarget\(2\) == null\)/);
  assert.match(native, /app_state\.shells\[1\]\.kind = \.cmd;\s*try std\.testing\.expect\(groupLaunchTarget\(2\) == null\)/);
  assert.match(native, /\[_\]u32\{ 221, 256, 257, 300 \}/);
});
